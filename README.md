# Sydney Airbnb x Census: an ELT pipeline with Airflow, dbt and Postgres

A monthly ELT pipeline that loads twelve months of Sydney Airbnb listings (May 2020 to April 2021) and 2016 Census data into
PostgreSQL, models them as a **bronze / silver / gold** warehouse with **slowly changing dimensions (SCD2)**, and answers
business questions about short-term rental revenue by neighbourhood, host and demographics.

| | |
|---|---|
| Data | 412,122 raw listing rows, 407,364 listing-months after de-duplication, 31,001 hosts, 45,613 listings, 29 LGAs with listings |
| Orchestration | Apache Airflow (Cloud Composer): idempotent, parameterised monthly load |
| Transform | dbt: 16 models, 2 SCD2 snapshots, 3 data marts, 26 tests |
| Warehouse | PostgreSQL |

## Architecture

```mermaid
flowchart LR
    subgraph GCS[Cloud Storage]
        A1[airbnb/MM_YYYY.csv]
        R1[census/*.csv<br/>LGA code, suburb map,<br/>Census G01/G02]
    end
    A1 -->|DAG load_airbnb_month<br/>replace one month| B
    R1 -->|DAG load_reference_data<br/>truncate + load| B
    subgraph PG[PostgreSQL]
        B[(bronze<br/>raw text)] --> S[(silver<br/>typed, de-duplicated)]
        S --> SN[SCD2 snapshots<br/>listing, host]
        SN --> G[(gold<br/>dimensions, fact)]
        S --> G
        G --> M[data marts<br/>views]
    end
    M --> Q[analysis/*.sql]
```

| Layer | Objects |
|---|---|
| **bronze** | `airbnb_raw` (adds `load_month`, `loaded_at`), `nsw_lga_code_raw_csv`, `nsw_lga_suburb_raw_csv`, `census_g01_raw_csv`, `census_g02_raw_csv` |
| **silver** | `silver_listings` (one row per listing per month), Census G01/G02, LGA code, suburb mapping; snapshots `snap_dim_listing`, `snap_dim_host` |
| **gold: dimensions** | `dim_listing` and `dim_host` (SCD2), `dim_lga`, `dim_place` (place name to LGA), `dim_census_g01`, `dim_census_g02` |
| **gold: fact** | `fact_listing_monthly`: one row per listing per month, keys and measures only |
| **gold: marts** | `dm_listing_neighbourhood`, `dm_property_type`, `dm_host_neighbourhood` (views), built on `int_listing_month` |

Marts join the fact table to the dimension version that was **valid in that month** (`valid_from <= month < valid_to`), so history
is reported as it was, not as it is now.

## Design decisions

- **The month comes from `scraped_date`, not the file name.** `07_2020.csv` holds 4,780 rows scraped in September, and 4,758 of them also
  appear in `09_2020.csv`. Silver keeps one row per (listing, month), latest scrape first, so nothing is counted twice.
- **Snapshots read only the newest loaded month**, so each run appends one SCD2 version and history builds correctly. The consequence: load
  a month, run dbt, then the next month, in order. The test `assert_snapshots_cover_all_months` fails if a month is skipped.
- **"Newest loaded month" means newest by file (`load_month`), not by data.** Using the newest scraped date would have skipped July, because
  the July file contains September rows. Gold only publishes months up to the newest loaded month.
- **One place-to-LGA mapping (`dim_place`)** serves both the listing neighbourhood and the host neighbourhood. An LGA name beats a suburb of the
  same name: Airbnb's neighbourhood field *is* an LGA, so "Fairfield" must not resolve to the suburb Fairfield, which the mapping file places in Cumberland.
- **Bronze loads are idempotent and atomic.** Reloading a month deletes and re-inserts only that month in one transaction, and an empty
  file is refused rather than wiping a month.
- **Download and load happen in one Airflow task.** A file written to `/tmp` by one task is not visible to another task on a different worker.
- **The bucket name is read from an Airflow Variable at run time**, not at DAG-parse time.
- **dbt writes to exactly `silver` and `gold`** (`macros/generate_schema_name.sql`), so analysis SQL has stable names.
- **Marts share one temporal join** (`int_listing_month`) and one metric definition (`macros/listing_metrics.sql`) instead of repeating them.

## Data quality checks

Every `dbt build` runs 26 tests alongside the 18 models and snapshots (44 nodes). The ones that guard this pipeline's specific failure modes:

- Unique grain on the fact table, both snapshots, and every mart.
- `assert_scd2_no_overlap`: no two versions of a listing or host are valid at once, which would double-count in a temporal join.
- `assert_mart_join_preserves_fact_rows`: the SCD2 join returns exactly one row per fact row, with no fan-out and no drops.
- `assert_snapshots_cover_all_months`: no loaded month was skipped.
- Referential checks from the fact table to `dim_host`, `dim_lga` and `dim_place`.

## Results

Estimated revenue for a listing-month is `price x (30 - availability_30)`: nights *not* available in the next 30 days, a proxy for bookings.
It is not observed revenue. All figures below are produced by [`analysis/`](analysis) and stored in [`analysis/results/`](analysis/results).

**Q1. Revenue per active listing, last 12 months** (highest and lowest LGAs)

| LGA | $ per active listing-month | Median age |
|---|---|---|
| Mosman | 9,356 | 42 |
| Northern Beaches | 7,586 | 40 |
| Woollahra | 6,854 | 39 |
| Canterbury-Bankstown | 1,493 | 35 |
| Blacktown | 1,314 | 33 |
| Fairfield | 1,298 | 36 |

**Q2. Age and revenue.** Across 29 LGAs the correlation between median age and revenue per active listing is **0.66**. Affluent
harbour and beach LGAs skew older, so age is likely standing in for location and income.

**Q3. Best configuration.** In the five highest-earning neighbourhoods (Hunters Hill, Mosman, Northern Beaches, Waverley, Woollahra), entire
apartments for 2 or 4 guests account for the most stays. Entire 8-guest houses rank third in Mosman and Northern Beaches.

**Q4. Multi-listing hosts.** Of 31,001 hosts, **5,095 (16.4%)** run more than one listing. Of those, 1,185 (23.3%) have listings in more than one LGA.

**Q5. Can a single-listing host cover their mortgage?** Share of single-listing hosts whose 12-month estimated revenue reaches
12 x their LGA's median monthly mortgage repayment: Northern Beaches **56.3%** (2,370 of 4,212), Mosman 51.7%, Hunters Hill 50.0%,
down to Blacktown 12.3%.

## Limitations

- **Revenue is an estimate**, based on availability, not on bookings or on what guests paid.
- **Price outliers are not removed.** 385 listing-months have a nightly price above $5,000 (maximum $28,613 against a median of $120), which lifts averages.
  Medians in the marts are robust to this.
- **Census data is from 2016** and is compared with 2020-21 listings.
- **38% of listing-months belong to hosts whose home neighbourhood matches no NSW LGA or suburb** (interstate or overseas hosts, blanks).
  They appear in `dm_host_neighbourhood` under the bucket `UNMAPPED` instead of being dropped.
- **SCD2 versions are monthly.** The timestamp strategy creates a new version each month whether or not attributes changed, so history is a
  monthly series rather than a compact change log.
- **Months must be processed in order**, one at a time (see Design decisions).

## Run it

Data is not included. Place your copies under `data/` using the same layout as the bucket:

```
data/census/NSW_LGA_CODE.csv  NSW_LGA_SUBURB.csv  2016Census_G01_NSW_LGA.csv  2016Census_G02_NSW_LGA.csv
data/airbnb/05_2020.csv ... 04_2021.csv
```

Sources: Inside Airbnb (Sydney) <http://insideairbnb.com/get-the-data/> and the ABS 2016 Census DataPacks
<https://www.abs.gov.au/census/find-census-data/datapacks>. The Airbnb files used here were prepared for the course, so column layouts may differ from a fresh download.

**Locally, against any PostgreSQL 13+:**

```bash
pip install -r requirements.txt
export PGHOST=localhost PGUSER=postgres PGPASSWORD=... PGDATABASE=airbnb
cp dbt/profiles.yml.example dbt/profiles.yml
python scripts/backfill.py --data-dir data      # loads bronze + runs dbt build, month by month
python scripts/run_analysis.py                  # writes analysis/results/*.csv
```

**On GCP (Cloud Composer + Cloud SQL):** copy `orchestration/dags/` into the Composer DAGs folder, create the Airflow Variable `airbnb_bucket`
and the connections `google_cloud_default` and `airbnb_postgres`, then run `sql/bronze/001_create_bronze.sql` once. Trigger `load_reference_data`
once, then for each month `load_airbnb_month` with `{"month": "05_2020"}` followed by a dbt run (dbt Cloud job or `dbt build`).

## Tests

```bash
export TEST_DATABASE_URL=postgresql://user:pass@host/scratch_db   # a throwaway database: the tests drop its bronze schema
pytest
```

Loader tests (idempotent reloads, single-month replacement, rollback on a bad file, empty-file protection, quoting), task tests (GCS and
Postgres replaced) and DAG tests (import, manual-only schedule, parameter validation, an in-process run with the templated parameter;
these need Airflow installed and are skipped otherwise).

**What was verified, and how.** The full 12-month backfill was run against PostgreSQL 16.2 with dbt-core 1.10 / dbt-postgres 1.9: every monthly
`dbt build` passed all 44 nodes (models, snapshots and tests), and a repeat run on the same state changed nothing. The DAGs were parsed and run in-process on Airflow 2.10.5.
Reading from a real GCS bucket and running on Cloud Composer were **not** exercised: the GCS read is a single small function
(`airbnb_elt/tasks.py::_read_gcs_text`) that the tests replace.

## Repository layout

```
orchestration/dags/     Airflow DAGs and the airbnb_elt helper package (loaders, task bodies)
sql/bronze/             DDL for the bronze layer
dbt/                    models (silver, gold), snapshots, macros, tests, profiles example
analysis/               the five business queries and their results (CSV)
scripts/                backfill.py (local end-to-end run), run_analysis.py
tests/                  pytest suite
```
