"""Bronze-layer loaders: CSV -> Postgres, with no Airflow dependency so they can be tested on their own.

Design rules
- Bronze keeps data as delivered (all TEXT). No typing or cleaning here.
- Every load is idempotent: re-running a load leaves the table in the same state.
- Downloading and loading happen inside ONE task (see the DAGs). Files written to /tmp by one Airflow task are
  not visible to another task when workers run on different machines, as they do on Cloud Composer.
"""
from __future__ import annotations

import csv
import io
import re
from datetime import date
from typing import Iterable, Sequence

AIRBNB_TABLE = "bronze.airbnb_raw"

# CSV column order of the monthly Airbnb files (the header row is skipped, not matched by name).
AIRBNB_COLUMNS: tuple[str, ...] = (
    "listing_id", "scrape_id", "scraped_date", "host_id", "host_name", "host_since",
    "host_is_superhost", "host_neighbourhood", "listing_neighbourhood", "property_type",
    "room_type", "accommodates", "price", "has_availability", "availability_30",
    "number_of_reviews", "review_scores_rating", "review_scores_accuracy",
    "review_scores_cleanliness", "review_scores_checkin", "review_scores_communication",
    "review_scores_value",
)

# Reference files: table -> number of leading CSV columns to keep (None = all columns).
# The suburb mapping file carries 25 trailing empty columns that are dropped here.
REFERENCE_TABLES: dict[str, int | None] = {
    "bronze.nsw_lga_code_raw_csv": None,
    "bronze.nsw_lga_suburb_raw_csv": 2,
    "bronze.census_g01_raw_csv": None,
    "bronze.census_g02_raw_csv": None,
}

_MONTH_RE = re.compile(r"^(0[1-9]|1[0-2])_(\d{4})$")


def parse_month_label(label: str) -> date:
    """'05_2020' -> date(2020, 5, 1). Raises ValueError for anything else."""
    m = _MONTH_RE.match(label)
    if not m:
        raise ValueError(f"month must look like MM_YYYY (e.g. 05_2020), got {label!r}")
    return date(int(m.group(2)), int(m.group(1)), 1)


def _rows(csv_text: str, keep: int | None) -> Iterable[list[str]]:
    """Yield data rows (header skipped) from CSV text, optionally truncated to the first `keep` columns."""
    reader = csv.reader(io.StringIO(csv_text))
    next(reader, None)  # header
    for row in reader:
        if not any(cell.strip() for cell in row):
            continue  # fully blank line
        yield row[:keep] if keep is not None else row


def _to_csv_buffer(rows: Iterable[Sequence[str]]) -> tuple[io.StringIO, int]:
    buf, n = io.StringIO(), 0
    writer = csv.writer(buf)
    for row in rows:
        writer.writerow(row)
        n += 1
    buf.seek(0)
    return buf, n


def read_csv_text(path: str) -> str:
    # utf-8-sig strips the byte-order mark that the LGA suburb file starts with
    with open(path, "r", encoding="utf-8-sig", newline="") as fh:
        return fh.read()


def load_airbnb_month(conn, csv_text: str, month: date) -> int:
    """Replace the rows of one monthly file in bronze.airbnb_raw. Returns the number of rows loaded.

    Runs in a single transaction: either the month is fully replaced or nothing changes.
    """
    if month.day != 1:
        raise ValueError("month must be the first day of a month")
    buf, n = _to_csv_buffer(_rows(csv_text, len(AIRBNB_COLUMNS)))
    if n == 0:
        raise ValueError(f"no data rows found for {month:%Y-%m}; refusing to wipe the existing month")
    cols = ", ".join(AIRBNB_COLUMNS)
    with conn:  # commit on success, roll back on error
        with conn.cursor() as cur:
            cur.execute(
                f"CREATE TEMP TABLE stg_airbnb (LIKE {AIRBNB_TABLE} EXCLUDING ALL) ON COMMIT DROP"
            )
            cur.execute("ALTER TABLE stg_airbnb DROP COLUMN load_month, DROP COLUMN loaded_at")
            cur.copy_expert(f"COPY stg_airbnb ({cols}) FROM STDIN WITH (FORMAT csv)", buf)
            cur.execute(f"DELETE FROM {AIRBNB_TABLE} WHERE load_month = %s", (month,))
            cur.execute(
                f"INSERT INTO {AIRBNB_TABLE} ({cols}, load_month) SELECT {cols}, %s FROM stg_airbnb",
                (month,),
            )
    return n


def load_reference_table(conn, csv_text: str, table: str) -> int:
    """Replace the full contents of a reference table (truncate + load). Returns rows loaded."""
    if table not in REFERENCE_TABLES:
        raise ValueError(f"unknown reference table {table!r}; expected one of {sorted(REFERENCE_TABLES)}")
    buf, n = _to_csv_buffer(_rows(csv_text, REFERENCE_TABLES[table]))
    if n == 0:
        raise ValueError(f"no data rows for {table}; refusing to truncate")
    with conn:
        with conn.cursor() as cur:
            cur.execute(f"TRUNCATE {table}")
            cur.copy_expert(f"COPY {table} FROM STDIN WITH (FORMAT csv)", buf)
    return n
