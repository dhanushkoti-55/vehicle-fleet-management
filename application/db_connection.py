import streamlit as st
import mysql.connector
import pandas as pd

def get_connection():
    return mysql.connector.connect(
        host=st.secrets["mysql"]["host"],
        port=st.secrets["mysql"].get("port", 3306),
        user=st.secrets["mysql"]["user"],
        password=st.secrets["mysql"]["password"],
        database=st.secrets["mysql"]["database"]
    )

def fetch_data(query, params=None):
    connection = get_connection()
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute(query, params or ())
        data = cursor.fetchall()
        return pd.DataFrame(data)
    finally:
        cursor.close()
        connection.close()

def execute_query(query, params=None):
    connection = get_connection()
    try:
        cursor = connection.cursor()
        cursor.execute(query, params or ())
        connection.commit()
        return cursor.lastrowid
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()
        connection.close()
