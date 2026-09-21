import os
import pathlib
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "orchestration" / "dags"))


@pytest.fixture()
def conn():
    """A connection to a scratch Postgres with the bronze DDL applied. Skipped without TEST_DATABASE_URL."""
    url = os.environ.get("TEST_DATABASE_URL")
    if not url:
        pytest.skip("set TEST_DATABASE_URL to run the database tests")
    import psycopg2

    connection = psycopg2.connect(url)
    connection.autocommit = True
    with connection.cursor() as cur:
        cur.execute("DROP SCHEMA IF EXISTS bronze CASCADE")
    cur = connection.cursor()
    cur.execute((ROOT / "sql" / "bronze" / "001_create_bronze.sql").read_text())
    connection.autocommit = False
    yield connection
    connection.rollback()
    connection.close()
