import os
import streamlit as st
import mysql.connector
import pandas as pd

def get_connection():
    config = st.secrets.get("mysql", {}) if hasattr(st, "secrets") and "mysql" in st.secrets else {}
    return mysql.connector.connect(
        host=config.get("host", os.getenv("DB_HOST", "127.0.0.1")),
        port=int(config.get("port", os.getenv("DB_PORT", 3306))),
        user=config.get("user", os.getenv("DB_USER", "root")),
        password=config.get("password", os.getenv("DB_PASSWORD", "")),
        database=config.get("database", os.getenv("DB_NAME", "vehicle_fleet_db"))
    )

def fetch_data(query, params=None):
    conn = get_connection()
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute(query, params or ())
        data = cursor.fetchall()
        return pd.DataFrame(data)
    finally:
        cursor.close()
        conn.close()

def execute_query(query, params=None):
    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(query, params or ())
        conn.commit()
        return cursor.lastrowid
    except Exception:
        conn.rollback()
        raise
    finally:
        cursor.close()
        conn.close()
