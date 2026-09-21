"""Load the static reference data (NSW LGA codes, suburb mapping, Census G01/G02) into the bronze schema.

Run once, manually. Re-running replaces the tables (truncate + load), so it is safe to repeat.
"""
from datetime import datetime

from airflow import DAG
from airflow.operators.python import PythonOperator

from airbnb_elt.tasks import REFERENCE_OBJECTS, load_reference_from_gcs

with DAG(
    dag_id="load_reference_data",
    description="GCS -> bronze: LGA code/suburb mappings and 2016 Census G01/G02.",
    start_date=datetime(2020, 5, 1),
    schedule=None,
    catchup=False,
    default_args={"owner": "data-eng", "retries": 1},
    tags=["airbnb", "bronze"],
) as dag:
    for gcs_object, table in REFERENCE_OBJECTS.items():
        PythonOperator(
            task_id="load_" + table.split(".")[1],
            python_callable=load_reference_from_gcs,
            op_kwargs={"gcs_object": gcs_object, "table": table},
        )
