#!/usr/bin/env python3.3
#
# Populates "bounding-box" entry in statistics database.
#
# Runs in ~3 minutes

import db
import stats_db

source_dsn = 'dbname=opencensus_dev user=opencensus_dev password=opencensus_dev host=localhost'

def main():
    import sys

    connection = db.connect()
    collection = stats_db.get_collection()

    c = connection.cursor()

    print('Querying for bounding boxes of all regions...', file=sys.stderr)
    c.execute("""
        SELECT
            json_id,
            ST_XMin(bbox) AS sw_longitude,
            ST_YMin(bbox) AS sw_latitude,
            ST_XMax(bbox) AS ne_longitude,
            ST_YMax(bbox) AS ne_latitude
        FROM (
            SELECT
                type || '-' || uid AS json_id,
                ST_Transform(ST_SetSRID(geometry, 4326), 4326) AS bbox
            FROM regions
        ) x
        """)

    print('Storing bounding boxes. "." = 10,000 regions: ', file=sys.stderr, end='', flush=True)
    i = 0
    for row in c:
        region_id = row[0]
        if region_id.startswith('Country'):
            region_id = 'Province-01'
        region = collection.get_region(region_id)
        region.set('bounding-box', row[1:5])
        region.save()
        i += 1
        if i == 10000:
            i = 0
            print('.', file=sys.stderr, end='', flush=True)

    print('', file=sys.stderr)

if __name__ == '__main__':
    main()
