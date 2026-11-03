import os
from functools import lru_cache

import mysql.connector
import pandas as pd
import streamlit as st
from mysql.connector import pooling


@st.cache_resource(show_spinner=False)
def _connection_pool():
    secrets = st.secrets
    config = dict(secrets["mysql"]) if "mysql" in secrets else {}

    settings = {
        "host": config.get("host", os.getenv("DB_HOST", "127.0.0.1")),
        "port": int(config.get("port", os.getenv("DB_PORT", "3306"))),
        "user": config.get("user", os.getenv("DB_USER", "root")),
        "password": config.get("password", os.getenv("DB_PASSWORD", "")),
        "database": config.get("database", os.getenv("DB_NAME", "vehicle_fleet_db")),
        "connection_timeout": 10,
        "autocommit": False,
    }
    return pooling.MySQLConnectionPool(
        pool_name="vehicle_fleet_pool",
        pool_size=5,
        pool_reset_session=True,
        **settings,
    )


def get_connection():
    return _connection_pool().get_connection()


def fetch_data(query, params=None):
    connection = get_connection()
    cursor = None
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute(query, params or ())
        return pd.DataFrame(cursor.fetchall())
    finally:
        if cursor is not None:
            cursor.close()
        connection.close()


def execute_query(query, params=None):
    connection = get_connection()
    cursor = None
    try:
        cursor = connection.cursor()
        cursor.execute(query, params or ())
        connection.commit()
        return cursor.lastrowid
    except Exception:
        connection.rollback()
        raise
    finally:
        if cursor is not None:
            cursor.close()
        connection.close()


def execute_transaction(operations):
    connection = get_connection()
    cursor = None
    results = []
    try:
        cursor = connection.cursor()
        for query, params in operations:
            cursor.execute(query, params or ())
            results.append(cursor.lastrowid)
        connection.commit()
        return results
    except Exception:
        connection.rollback()
        raise
    finally:
        if cursor is not None:
            cursor.close()
        connection.close()


def call_procedure(name, args):
    connection = get_connection()
    cursor = None
    try:
        cursor = connection.cursor()
        result = cursor.callproc(name, args)
        connection.commit()
        return result
    except Exception:
        connection.rollback()
        raise
    finally:
        if cursor is not None:
            cursor.close()
        connection.close()
