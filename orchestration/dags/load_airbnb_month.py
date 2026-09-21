"""Load one monthly Airbnb file into bronze.airbnb_raw. Replaces the twelve near-identical per-month DAGs.

Trigger with the month to load:
    airflow dags trigger load_airbnb_month --conf '{"month": "05_2020"}'
or from the UI with "Trigger DAG w/ config". Loading the same month again replaces it (no duplicates).
Run dbt after each month, in month order (see README): the SCD2 snapshots read only the newest loaded month.
"""
from datetime import datetime

from airflow import DAG
from airflow.models.param import Param
from airflow.operators.python import PythonOperator

from airbnb_elt.tasks import load_airbnb_month_from_gcs

with DAG(
    dag_id="load_airbnb_month",
    description="GCS -> bronze: one monthly Airbnb listings file (idempotent).",
    start_date=datetime(2020, 5, 1),
    schedule=None,
    catchup=False,
    params={
        "month": Param(
            "05_2020",
            type="string",
            pattern=r"^(0[1-9]|1[0-2])_\d{4}$",
            description="File to load, as MM_YYYY (reads airbnb/<month>.csv in the bucket).",
        )
    },
    default_args={"owner": "data-eng", "retries": 1},
    tags=["airbnb", "bronze"],
) as dag:
    PythonOperator(
        task_id="load_month",
        python_callable=load_airbnb_month_from_gcs,
        op_kwargs={"month_label": "{{ params.month }}"},
    )
