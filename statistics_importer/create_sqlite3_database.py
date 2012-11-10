#!/usr/bin/env python3.3

from binascii import b2a_hex as _b2a_hex
import json
import sys
import zlib

import psycopg2
import psycopg2.extensions
psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)

import master_db

source_dsn = 'dbname=opencensus_dev user=opencensus_dev password=opencensus_dev host=localhost'
SLICE_SIZE = 1000

class DbRegionWithStatistics:
    Schema = {
        '2011': {
            'p': ('2011', 'population', 'total'),
            'g': ('2011', 'population', 'growth'),
            'a': {
                'm': ('2011', 'population', 'by-age', 'male'),
                'f': ('2011', 'population', 'by-age', 'female'),
                't': ('2011', 'population', 'by-age', 'total')
            },
            'dw': ('2011', 'dwellings', 'total'),
            's': ('2011', 'population-15-and-over', 'by-status'),
            'f': ('2011', 'families', 'total'),
            'pf': ('2011', 'families', 'people-per-family'),
            'cf': ('2011', 'families', 'children-at-home-per-family'),
            'fp': ('2011', 'families', 'by-parents')
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
        else: # type(schema) == dict
            return dict(
                filter(
                    lambda kv: kv[1] is not None,
                    ((k, self._fill_schema(v)) for k, v in schema.items())
                )
            )

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

        if d['a'] > 0:
            # Derive density
            d['2011']['d'] = d['2011']['p'] / d['a']

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

    db = psycopg2.connect(source_dsn)
    stats_collection = master_db.get_collection()

    print('Creating output database...', file=sys.stderr)
    print('PRAGMA synchronous = OFF;')
    print('CREATE TABLE region_statistics (region_id INTEGER PRIMARY KEY, statistics BLOB);')

    store = DbRegionStore(db)

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
