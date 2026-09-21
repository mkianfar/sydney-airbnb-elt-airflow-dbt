#!/usr/bin/env python3
"""Local end-to-end run: load bronze and run dbt once per month, in month order.

This is the same sequence the Airflow DAGs perform on GCP (load a month, then transform), for running the whole
pipeline against any Postgres without Cloud Composer. Snapshots read only the newest month, so months must be
processed one at a time and in order.

    export PGHOST=localhost PGUSER=postgres PGPASSWORD=... PGDATABASE=airbnb
    python scripts/backfill.py --data-dir data

Expected layout of --data-dir (the same object layout as the GCS bucket):
    census/NSW_LGA_CODE.csv  census/NSW_LGA_SUBURB.csv  census/2016Census_G01_NSW_LGA.csv  census/2016Census_G02_NSW_LGA.csv
    airbnb/05_2020.csv ... airbnb/04_2021.csv
"""
from __future__ import annotations

import argparse
import os
import pathlib
import subprocess
import sys

import psycopg2

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "orchestration" / "dags"))
from airbnb_elt import loaders  # noqa: E402

REFERENCE_FILES = {
    "census/NSW_LGA_CODE.csv": "bronze.nsw_lga_code_raw_csv",
    "census/NSW_LGA_SUBURB.csv": "bronze.nsw_lga_suburb_raw_csv",
    "census/2016Census_G01_NSW_LGA.csv": "bronze.census_g01_raw_csv",
    "census/2016Census_G02_NSW_LGA.csv": "bronze.census_g02_raw_csv",
}


def connect():
    return psycopg2.connect(
        host=os.environ.get("PGHOST", "localhost"),
        port=os.environ.get("PGPORT", "5432"),
        user=os.environ["PGUSER"],
        password=os.environ.get("PGPASSWORD", ""),
        dbname=os.environ.get("PGDATABASE", "postgres"),
    )


def dbt(*args: str) -> None:
    cmd = ["dbt", *args, "--project-dir", str(ROOT / "dbt"), "--profiles-dir", os.environ.get("DBT_PROFILES_DIR", str(ROOT / "dbt"))]
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, check=True)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data-dir", required=True, type=pathlib.Path)
    ap.add_argument("--skip-dbt", action="store_true", help="only load bronze")
    args = ap.parse_args()

    conn = connect()
    with conn, conn.cursor() as cur:
        cur.execute((ROOT / "sql" / "bronze" / "001_create_bronze.sql").read_text())

    for rel, table in REFERENCE_FILES.items():
        n = loaders.load_reference_table(conn, loaders.read_csv_text(str(args.data_dir / rel)), table)
        print(f"loaded {n:>7} rows into {table}", flush=True)

    labels = [p.stem for p in (args.data_dir / "airbnb").glob("*.csv")]
    for label in sorted(labels, key=loaders.parse_month_label):
        month = loaders.parse_month_label(label)
        n = loaders.load_airbnb_month(conn, loaders.read_csv_text(str(args.data_dir / "airbnb" / f"{label}.csv")), month)
        print(f"loaded {n:>7} rows for {month:%Y-%m}", flush=True)
        if not args.skip_dbt:
            dbt("build")


if __name__ == "__main__":
    main()
