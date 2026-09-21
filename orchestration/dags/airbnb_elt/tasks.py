"""Task bodies for the Airflow DAGs: fetch a CSV from GCS and load it into the bronze schema.

Airflow is imported lazily inside the two small helpers below, so this module can be imported and tested
without Airflow installed (tests replace the helpers). Download and load run in the SAME task on purpose:
a file saved to /tmp by one task is not visible to another task when the two run on different workers.
"""
from __future__ import annotations

from . import loaders

GCP_CONN_ID = "google_cloud_default"
POSTGRES_CONN_ID = "airbnb_postgres"  # Airflow connection to the Postgres instance
BUCKET_VARIABLE = "airbnb_bucket"  # Airflow Variable holding the bucket name

# object path in the bucket -> bronze table (reference data, loaded once)
REFERENCE_OBJECTS = {
    "census/NSW_LGA_CODE.csv": "bronze.nsw_lga_code_raw_csv",
    "census/NSW_LGA_SUBURB.csv": "bronze.nsw_lga_suburb_raw_csv",
    "census/2016Census_G01_NSW_LGA.csv": "bronze.census_g01_raw_csv",
    "census/2016Census_G02_NSW_LGA.csv": "bronze.census_g02_raw_csv",
}


def _read_gcs_text(gcs_object: str) -> str:
    from airflow.models import Variable
    from airflow.providers.google.cloud.hooks.gcs import GCSHook

    # read at run time, not DAG-parse time: Variable.get at module level hits the metadata DB on every parse
    bucket = Variable.get(BUCKET_VARIABLE)
    data = GCSHook(gcp_conn_id=GCP_CONN_ID).download(bucket_name=bucket, object_name=gcs_object)
    return data.decode("utf-8-sig")  # utf-8-sig drops the BOM the LGA suburb file starts with


def _pg_connection():
    from airflow.providers.postgres.hooks.postgres import PostgresHook

    return PostgresHook(postgres_conn_id=POSTGRES_CONN_ID).get_conn()


def load_reference_from_gcs(gcs_object: str, table: str) -> int:
    conn = _pg_connection()
    try:
        n = loaders.load_reference_table(conn, _read_gcs_text(gcs_object), table)
    finally:
        conn.close()
    print(f"loaded {n} rows from {gcs_object} into {table}")
    return n


def load_airbnb_month_from_gcs(month_label: str) -> int:
    """month_label like '05_2020'; reads airbnb/05_2020.csv and replaces that month in bronze.airbnb_raw."""
    month = loaders.parse_month_label(month_label)
    conn = _pg_connection()
    try:
        n = loaders.load_airbnb_month(conn, _read_gcs_text(f"airbnb/{month_label}.csv"), month)
    finally:
        conn.close()
    print(f"loaded {n} rows for {month:%Y-%m}")
    return n
