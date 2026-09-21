from datetime import date

import pytest
from airbnb_elt import loaders

HEADER = ",".join(c.upper() for c in loaders.AIRBNB_COLUMNS)


def airbnb_csv(*ids):
    rows = [HEADER]
    for i in ids:
        # 22 columns; values with commas and quotes must survive the round trip
        rows.append(f'{i},20200000000000,2020-05-11,9,"Smith, Jo",23/9/2009,f,Potts Point,Sydney,Apartment,Private room,2,64,t,28,10,90,10,9,10,10,10')
    return "\n".join(rows) + "\n"


def count(conn, sql="select count(*) from bronze.airbnb_raw", *args):
    with conn.cursor() as cur:
        cur.execute(sql, args)
        return cur.fetchone()[0]


def test_parse_month_label():
    assert loaders.parse_month_label("05_2020") == date(2020, 5, 1)
    assert loaders.parse_month_label("12_2021") == date(2021, 12, 1)
    for bad in ["5_2020", "13_2020", "2020_05", "05-2020", "", "05_20"]:
        with pytest.raises(ValueError):
            loaders.parse_month_label(bad)


def test_load_month_is_idempotent(conn):
    loaders.load_airbnb_month(conn, airbnb_csv(1, 2, 3), date(2020, 5, 1))
    loaders.load_airbnb_month(conn, airbnb_csv(1, 2, 3), date(2020, 5, 1))
    assert count(conn) == 3


def test_reload_replaces_only_that_month(conn):
    loaders.load_airbnb_month(conn, airbnb_csv(1, 2), date(2020, 5, 1))
    loaders.load_airbnb_month(conn, airbnb_csv(7, 8, 9), date(2020, 6, 1))
    loaders.load_airbnb_month(conn, airbnb_csv(1), date(2020, 5, 1))
    assert count(conn, "select count(*) from bronze.airbnb_raw where load_month = %s", date(2020, 5, 1)) == 1
    assert count(conn, "select count(*) from bronze.airbnb_raw where load_month = %s", date(2020, 6, 1)) == 3


def test_quoted_commas_survive_and_load_month_is_set(conn):
    loaders.load_airbnb_month(conn, airbnb_csv(1), date(2020, 5, 1))
    with conn.cursor() as cur:
        cur.execute("select host_name, load_month, loaded_at is not null from bronze.airbnb_raw")
        assert cur.fetchone() == ("Smith, Jo", date(2020, 5, 1), True)


def test_empty_file_does_not_wipe_existing_month(conn):
    loaders.load_airbnb_month(conn, airbnb_csv(1, 2), date(2020, 5, 1))
    with pytest.raises(ValueError):
        loaders.load_airbnb_month(conn, HEADER + "\n", date(2020, 5, 1))
    assert count(conn) == 2


def test_failed_load_rolls_back_and_keeps_old_data(conn):
    loaders.load_airbnb_month(conn, airbnb_csv(1, 2), date(2020, 5, 1))
    broken = HEADER + "\n" + "1,2,3\n"  # too few columns -> COPY fails
    with pytest.raises(Exception):
        loaders.load_airbnb_month(conn, broken, date(2020, 5, 1))
    conn.rollback()
    assert count(conn) == 2


def test_non_first_of_month_rejected(conn):
    with pytest.raises(ValueError):
        loaders.load_airbnb_month(conn, airbnb_csv(1), date(2020, 5, 15))


def test_suburb_reference_drops_trailing_blank_columns_and_bom(conn):
    text = "﻿LGA_NAME,SUBURB_NAME" + ",,," * 3 + "\nMOSMAN,MOSMAN" + ",,," * 3 + "\n"
    text = text.lstrip("﻿")  # read_csv_text strips the BOM at file-read time
    n = loaders.load_reference_table(conn, text, "bronze.nsw_lga_suburb_raw_csv")
    assert n == 1
    with conn.cursor() as cur:
        cur.execute("select lga_name, suburb_name from bronze.nsw_lga_suburb_raw_csv")
        assert cur.fetchone() == ("MOSMAN", "MOSMAN")


def test_reference_reload_replaces_not_appends(conn):
    csv_text = "LGA_CODE,LGA_NAME\n10050,Albury\n10130,Armidale Regional\n"
    loaders.load_reference_table(conn, csv_text, "bronze.nsw_lga_code_raw_csv")
    loaders.load_reference_table(conn, csv_text, "bronze.nsw_lga_code_raw_csv")
    assert count(conn, "select count(*) from bronze.nsw_lga_code_raw_csv") == 2


def test_read_csv_text_strips_bom(tmp_path):
    p = tmp_path / "x.csv"
    p.write_bytes("﻿A,B\n1,2\n".encode("utf-8"))
    assert loaders.read_csv_text(str(p)).startswith("A,B")


def test_unknown_reference_table_rejected(conn):
    with pytest.raises(ValueError):
        loaders.load_reference_table(conn, "a\n1\n", "bronze.airbnb_raw")
