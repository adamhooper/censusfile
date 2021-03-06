#!/usr/bin/env python3.3

import psycopg2
import psycopg2.extensions
psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)

from psycopg2.extras import RealDictCursor

source_dsn = 'dbname=opencensus_dev user=opencensus_dev password=opencensus_dev host=localhost'

def connect():
    return psycopg2.connect(source_dsn)
