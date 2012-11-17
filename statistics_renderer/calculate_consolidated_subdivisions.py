#!/usr/bin/env python3.3
#
# TODO: remove Consolidated Subdivisions altogether? (means re-rendering tiles)
#
# StatsCan does not provide Census Consolidated Subdivision profiles, so we need
# to generate the data ourselves. (If we don't, then mouse hovers behavior will
# get weird, since the UTFGrid points to the CCS: if a Census Division comprises
# two CCSs and only one has its children rendered, then hovering over those
# children will behave as expected, and hovering over the other CCS (which has
# no stats) will highlight the entire CD.
#
# This script adds up all counts in all Census Subdivisions in each CCS.
#
# Runs in ~10 seconds

from array import array as _array
import sys

import db
import stats_db

# Adds counts deeply from rhs into lhs
def extend_dict(lhs, rhs):
    for key, value in rhs.items():
        if key == 'growth':
            pass # We'll derive it later
        elif key == 'notes':
            pass # HACK
        elif key == 'people-per-family':
            pass # HACK
        elif key == 'median-age':
            pass # FIXME
        elif key == 'bounding-box':
            # Handle bounding-box, which is special
            if key not in lhs:
                lhs[key] = list(value)
            else:
                bbox = lhs[key]
                if value[0] < bbox[0]:
                    bbox[0] = value[0]
                if value[1] < bbox[1]:
                    bbox[1] = value[1]
                if value[2] > bbox[2]:
                    bbox[2] = value[2]
                if value[3] > bbox[3]:
                    bbox[3] = value[3]
        elif type(value) == dict:
            # We merge dicts recursively
            if key not in lhs:
                lhs[key] = {}
            extend_dict(lhs[key], value)
        elif type(value) == list:
            # Lists have fixed lenghts. We add them an element at a time.
            if key not in lhs:
                lhs[key] = list(value)
            else:
                lhs[key] = list(map(sum, zip(lhs[key], value)))
        else:
            # We add counts
            if key not in lhs:
                lhs[key] = value
            else:
                lhs[key] += value

class Statistics:
    def __init__(self, data):
        self.data = data

    def add(self, rhs):
        extend_dict(self.data, rhs.data)

class CensusSubdivision:
    def __init__(self, mongodb_object):
        self.region_id = mongodb_object['_id']
        data = dict(item for item in mongodb_object.items() if item[0] != '_id')
        self.statistics = Statistics(data)

class CensusConsolidatedSubdivision:
    def __init__(self, uid, child_uids):
        self.region_id = "ConsolidatedSubdivision-" + uid
        self.child_region_ids = ("Subdivision-" + child_uid for child_uid in child_uids)
        self.statistics = Statistics({})

    def postprocess(self):
        self._add_median_age()

    def _add_median_age(self):
        d = self.statistics.data
        if '2011' not in d: return
        d = d['2011']
        if 'population' not in d: return
        d = d['population']
        if 'by-age' not in d or 'total' not in d['by-age']: return

        # Simple, brute-force median algorithm
        median_array = _array('f')
        for i, bucket_count in enumerate(d['by-age']['total']):
            if bucket_count <= 0: continue
            # We'll spread points out evenly, like this:
            # given: 0 [-----------------------------] 4 (i.e., <5)
            # and a count of three:
            # 1. Divide into three
            #        0 [---------|---------|---------] 5
            # 2. Put the counts halfway
            #        0 [----x----|----x----|----x----] 5
            # Ages: 5/6, 15/6, 25/6
            gap = 5.0 / bucket_count
            bottom = i * 5.0
            nextval = bottom + gap / 2
    
            for i in range(0, bucket_count):
                median_array.append(nextval)
                nextval += gap

        if len(median_array) == 0:
            d['median-age'] = 0 # This is what StatsCan does
        else:
            d['median-age'] = median_array[int(len(median_array)/2)]

    def write(self, collection):
        collection.collection.update(
            { '_id': self.region_id },
            { '$set': self.statistics.data },
            True # upsert
        )

def all_css_by_region_id(collection):
    print('Loading Census Subdivisions from stats DB...', file=sys.stderr)

    regions = collection.find({ '_id': { '$regex': '^Subdivision-' } })
    return dict(
        (region['_id'], CensusSubdivision(region)) for region in regions
    )

def each_ccs(db):
    print('Loading Census Consolidated Subdivisions from DB...', file=sys.stderr)

    c = db.cursor()
    c.execute("""
        SELECT p.uid, ARRAY_AGG(c.uid)
        FROM regions p
        INNER JOIN region_parents rp
                ON p.id = rp.parent_region_id
        INNER JOIN regions c
                ON c.id = rp.region_id
        WHERE p.type = 'ConsolidatedSubdivision'
          AND c.type = 'Subdivision'
        GROUP BY p.uid
        """)
    return (CensusConsolidatedSubdivision(*row) for row in c)

def main():
    connection = db.connect()
    collection = stats_db.get_collection()

    css = all_css_by_region_id(collection)
    ccss = each_ccs(connection)

    print('Consolidating...', file=sys.stderr)
    for ccs in ccss:
        for cs_id in ccs.child_region_ids:
            cs = css[cs_id]
            ccs.statistics.add(cs.statistics)
        ccs.postprocess()
        ccs.write(collection)

if __name__ == '__main__':
    main()
