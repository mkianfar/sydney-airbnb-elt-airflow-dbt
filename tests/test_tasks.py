from datetime import date

import pytest
from airbnb_elt import tasks

from test_loaders import airbnb_csv, count


def fake_bucket(monkeypatch, conn, files):
    """Replace the two Airflow-facing helpers: GCS reads come from `files`, Postgres is the test connection."""
    seen = []

    def read(obj):
        seen.append(obj)
        return files[obj]

    monkeypatch.setattr(tasks, "_read_gcs_text", read)
    monkeypatch.setattr(tasks, "_pg_connection", lambda: NoClose(conn))
    return seen


class NoClose:
    """Wraps the shared test connection so a task can call conn.close() without ending the test's connection."""

    def __init__(self, conn):
        self._c = conn

    def __enter__(self):
        return self._c.__enter__()

    def __exit__(self, *exc):
        return self._c.__exit__(*exc)

    def cursor(self, *a, **kw):
        return self._c.cursor(*a, **kw)

    def close(self):
        pass


def test_month_task_reads_the_right_object_and_loads(monkeypatch, conn):
    seen = fake_bucket(monkeypatch, conn, {"airbnb/06_2020.csv": airbnb_csv(1, 2, 3)})
    assert tasks.load_airbnb_month_from_gcs("06_2020") == 3
    assert seen == ["airbnb/06_2020.csv"]
    assert count(conn, "select count(*) from bronze.airbnb_raw where load_month = %s", date(2020, 6, 1)) == 3


def test_month_task_rejects_bad_label_before_touching_anything(monkeypatch, conn):
    seen = fake_bucket(monkeypatch, conn, {})
    with pytest.raises(ValueError):
        tasks.load_airbnb_month_from_gcs("2020-06")
    assert seen == []


def test_reference_task(monkeypatch, conn):
    fake_bucket(monkeypatch, conn, {"census/NSW_LGA_CODE.csv": "LGA_CODE,LGA_NAME\n10050,Albury\n"})
    assert tasks.load_reference_from_gcs("census/NSW_LGA_CODE.csv", "bronze.nsw_lga_code_raw_csv") == 1


def test_every_reference_object_maps_to_a_known_table():
    from airbnb_elt import loaders

    assert set(tasks.REFERENCE_OBJECTS.values()) == set(loaders.REFERENCE_TABLES)
