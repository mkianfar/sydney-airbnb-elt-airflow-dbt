#!/usr/bin/env python3
"""Run every query in analysis/*.sql against the warehouse and write each result set to analysis/results/*.csv.

A file may hold several statements; results are named <file>.csv, or <file>_2.csv, <file>_3.csv, ...
Uses the same PG* environment variables as scripts/backfill.py.
"""
import csv
import os
import pathlib
import re

import psycopg2

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "analysis" / "results"


def statements(sql: str):
    # drop line comments first so a ';' inside a comment cannot split a statement
    sql = re.sub(r"--[^\n]*", "", sql)
    return [s.strip() for s in sql.split(";") if s.strip()]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    conn = psycopg2.connect(
        host=os.environ.get("PGHOST", "localhost"), port=os.environ.get("PGPORT", "5432"),
        user=os.environ["PGUSER"], password=os.environ.get("PGPASSWORD", ""), dbname=os.environ.get("PGDATABASE", "postgres"),
    )
    with conn.cursor() as cur:
        for path in sorted((ROOT / "analysis").glob("*.sql")):
            for i, stmt in enumerate(statements(path.read_text()), start=1):
                cur.execute(stmt)
                name = path.stem if i == 1 else f"{path.stem}_{i}"
                with open(OUT / f"{name}.csv", "w", newline="") as fh:
                    w = csv.writer(fh)
                    w.writerow([d.name for d in cur.description])
                    w.writerows(cur.fetchall())
                print(f"{name}.csv  ({cur.rowcount} rows)")


if __name__ == "__main__":
    main()
