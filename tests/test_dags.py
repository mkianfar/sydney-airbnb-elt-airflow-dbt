"""DAG-level tests. Need Apache Airflow installed (skipped otherwise)."""
import pathlib

import pytest

pytest.importorskip("airflow")

from airflow.models import DagBag  # noqa: E402

DAGS = pathlib.Path(__file__).resolve().parent.parent / "orchestration" / "dags"


@pytest.fixture(scope="module")
def bag():
    return DagBag(dag_folder=str(DAGS), include_examples=False)


def test_dags_import_cleanly(bag):
    assert bag.import_errors == {}
    assert set(bag.dag_ids) == {"load_reference_data", "load_airbnb_month"}


def test_dags_are_manual_only(bag):
    for dag in bag.dags.values():
        assert dag.schedule_interval is None
        assert dag.catchup is False


def test_reference_dag_has_one_self_contained_task_per_file(bag):
    dag = bag.get_dag("load_reference_data")
    assert len(dag.tasks) == 4
    # no download -> load chains: each task fetches and loads on its own
    assert all(not t.upstream_task_ids and not t.downstream_task_ids for t in dag.tasks)


def test_month_param_is_validated(bag):
    from airflow.exceptions import ParamValidationError

    params = bag.get_dag("load_airbnb_month").params
    assert params["month"] == "05_2020"
    params["month"] = "12_2021"
    params.validate()
    for bad in ("13_2020", "2020_05", "5_2020"):
        with pytest.raises(ParamValidationError):
            params["month"] = bad
            params.validate()


def test_month_dag_end_to_end_with_templated_param(bag, monkeypatch):
    """Run the real DAG in-process; the month arrives through {{ params.month }} and reaches the loader."""
    from airbnb_elt import tasks

    calls = []
    monkeypatch.setattr(tasks, "load_airbnb_month_from_gcs", lambda month_label: calls.append(month_label) or 1)
    # the operator captured the function at import time, so patch the captured callable too
    dag = bag.get_dag("load_airbnb_month")
    dag.get_task("load_month").python_callable = lambda month_label: calls.append(month_label) or 1
    dag.test(run_conf={"month": "07_2020"})
    assert calls == ["07_2020"]
