#!/usr/bin/env python3.3
#
# Usage: create_sqlite3_database.py | sqlite3 out.sql
#
# This script runs in ~1:30 minutes, whether it's piped to sqlite3 or /dev/null.
# (It's CPU-bound in both Python and SQLite3, so your mileage may vary greatly.)

from binascii import b2a_hex as _b2a_hex
import json
import sys
import zlib

import db
import stats_db

source_dsn = 'dbname=opencensus_dev user=opencensus_dev password=opencensus_dev host=localhost'
SLICE_SIZE = 1000

class DbRegionWithStatistics:
    Schema = {
        'a': ('area',),
        'b': ('bounding-box',),
        '2011': {
            'p': ('2011', 'population', 'total'),
            'g': ('2011', 'population', 'growth'),
            'a': {
                'm': ('2011', 'population', 'by-age', 'male'),
                'f': ('2011', 'population', 'by-age', 'female'),
                't': ('2011', 'population', 'by-age', 'total')
            },
            'ma': ('2011', 'population', 'median-age'),
            'dw': ('2011', 'dwellings', 'total'),
            's': [
                ('2011', 'population-15-and-over', 'by-marital-status', 'single'),
                ('2011', 'population-15-and-over', 'by-marital-status', 'common-law'),
                ('2011', 'population-15-and-over', 'by-marital-status', 'married'),
                ('2011', 'population-15-and-over', 'by-marital-status', 'separated'),
                ('2011', 'population-15-and-over', 'by-marital-status', 'divorced'),
                ('2011', 'population-15-and-over', 'by-marital-status', 'widowed'),
            ],
            'f': ('2011', 'families', 'total'),
            'pf': ('2011', 'families', 'people-per-family'),
            'cf': ('2011', 'families', 'children-at-home-per-family'),
            'fp': [
                ('2011', 'families', 'by-parents', 'married'),
                ('2011', 'families', 'by-parents', 'common-law'),
                ('2011', 'families', 'by-parents', 'male'),
                ('2011', 'families', 'by-parents', 'female')
            ]
        },
        '2006': {
            'p': ('2006', 'population', 'total')
        }
    }

    def __init__(self, db_region, statistics):
        self.db_region = db_region
        self.statistics = statistics

    def _fill_schema(self, schema):
        if type(schema) == tuple:
            return self._lookup_value(schema)
        elif type(schema) == list:
            r = tuple(map(
                lambda v: 0 if v is None else v,
                (self._fill_schema(v) for v in schema)))
            if sum(r) == 0:
                return None
            else:
                return r
        else: # type(schema) == dict
            d = dict(
                filter(
                    lambda kv: kv[1] is not None,
                    ((k, self._fill_schema(v)) for k, v in schema.items())
                )
            )
            if len(d) == 0:
                return None
            else:
                return d

    def _lookup_value(self, keys):
        d = self.statistics
        for key in keys:
            if key in d:
                d = d[key]
            else:
                return None

        return d

    def get_notes_dict(self):
        flatten_dict(self.statistics['notes'])

    def to_dict(self):
        d = self._fill_schema(DbRegionWithStatistics.Schema)

        # Add zoom level
        if self.db_region.children_zoom_level is not None:
            d['z'] = self.db_region.children_zoom_level

        # Add area
        d['a'] = self.db_region.area

        if '2011' in d:
            if 'p' in d['2011']:
                if d['a'] > 0:
                    # Derive density
                    d['2011']['d'] = d['2011']['p'] / d['a'] * 1000000 # m^2 to km^2
                if 'g' not in d['2011'] and '2006' in d and 'p' in d['2006'] and d['2006']['p'] > 0:
                    # Derive growth
                    d['2011']['g'] = (d['2011']['p'] / d['2006']['p'] - 1.0) * 100

        return d

    def to_sql(self):
        data = self.to_dict()
        json_data = json.dumps(data, ensure_ascii=False, check_circular=False, separators=(',', ':'))
        json_data_z = zlib.compress(json_data.encode('ascii'))
        return "INSERT INTO region_statistics (region_id, statistics) VALUES (%d, X'%s');" % (self.db_region.db_id, _b2a_hex(json_data_z).decode('ascii'))

class DbRegion:
    def __init__(self, db_id, region_type, region_uid, area):
        self.db_id = db_id
        self.region_type = region_type
        self.region_uid = region_uid
        self.area = area

        if self.region_type == 'Country':
            self.key = 'Province-01' # This is what StatsCan calls it
        else:
            self.key = region_type + '-' + region_uid

        self.children_zoom_level = None

    def with_statistics(self, statistics):
        return DbRegionWithStatistics(self, statistics)

class DbRegionStore:
    def __init__(self, db):
        self.regions = self._load_regions(db)
        self._load_children_zoom_levels(db)

    def _load_regions(self, db):
        print('Loading list of regions from database...', file=sys.stderr)
        regions = []

        c = db.cursor()

        c.execute('''
            SELECT
                id, type, uid,
                CASE WHEN given_area_in_m > 1 THEN given_area_in_m ELSE polygon_area_in_m END
            FROM regions
            ''')
        for r in c:
            region = DbRegion(*r)
            regions.append(region)

        return regions

    def _load_children_zoom_levels(self, db):
        print('Loading zoom levels for region children...', file=sys.stderr)

        regions_by_id = dict((r.db_id, r) for r in self.regions)

        c = db.cursor()

        c.execute('''
            SELECT rp.parent_region_id, MIN(rmzl.min_zoom_level)
            FROM region_parents rp
            INNER JOIN region_min_zoom_levels rmzl ON rp.region_id = rmzl.region_id
            GROUP BY rp.parent_region_id
            ''')
        for r in c:
            regions_by_id[r[0]] = r[1]

    def regions_in_slices(self, slice_size):
        for i in range(0, len(self.regions), slice_size):
            yield self.regions[i:(i+slice_size)]

if __name__ == '__main__':
    import sys

    connection = db.connect()
    stats_collection = stats_db.get_collection()

    print('Creating output database...', file=sys.stderr)
    print('PRAGMA synchronous = OFF;')
    print('CREATE TABLE region_statistics (region_id INTEGER PRIMARY KEY, statistics BLOB);')

    store = DbRegionStore(connection)

    print('Loading statistics per region and writing to SQLite ("." = %d regions read and written): ' % (SLICE_SIZE,), file=sys.stderr, end='', flush=True)
    for region_slice in store.regions_in_slices(SLICE_SIZE):
        regions_by_key = dict((r.key, r) for r in region_slice)

        stats_with_keys = stats_collection.find({ '_id': { '$in': list(regions_by_key.keys()) } })
        for region_stats in stats_with_keys:
            key = region_stats['_id']
            region = regions_by_key[key]
            region_with_statistics = region.with_statistics(region_stats)

            print(region_with_statistics.to_sql())

        print('.', file=sys.stderr, end='', flush=True)

    print('', file=sys.stderr)
