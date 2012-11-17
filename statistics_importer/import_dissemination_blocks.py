#!/usr/bin/env python3.3
#
# Parses the "Geographic Attribute File" from StatsCan 2011.
#
# Runs in ~3 minutes

import io
from zipfile import ZipFile as _ZipFile

import stats_db

class BlockRegion:
    def __init__(self, region2011, region2006s):
        self.region2011 = region2011
        self.region2006s = region2006s

    def save_to_collection(self, collection):
        cr = collection.get_region('DisseminationBlock-' + self.region2011.uid)

        cr.set('2011.population.total', self.region2011.population)
        cr.set('2011.dwellings.total', self.region2011.dwellings)

        if self.region2011.note is not None:
            cr.set('notes.2011.population.total', self.region2011.note)
            cr.set('notes.2011.dwellings.total', self.region2011.note)

        if self.region2006s is not None:
            pop = sum(r.population for r in self.region2006s)

            note = None
            for region2006 in self.region2006s:
                if region2006.note is not None:
                    note = region2006.note
                    break

            cr.set('2006.population.total', pop)
            if note is not None:
                cr.set('notes.2006.population.total', note)

            if pop > 0:
                growth = (self.region2011.population / pop - 1) * 100
                cr.set('2011.population.growth', growth)
                if note is not None:
                    cr.set('notes.2011.population.growth', note)

        cr.save()

class Region2011:
    def __init__(self, uid, population, dwellings, note):
        self.uid = uid
        self.population = population
        self.dwellings = dwellings
        self.note = note

class Region2006:
    def __init__(self, uid, population, note):
        self.uid = uid
        self.population = population
        self.note = note

class BlockRegionStore:
    def __init__(self, uid2011_to_uids2006, regions2011, regions2006):
        self.regions2011 = dict((r.uid, r) for r in regions2011)
        self.regions2006 = dict((r.uid, r) for r in regions2006)
        self.uid2011_to_uids2006 = uid2011_to_uids2006

    def __iter__(self):
        for uid2011 in self.regions2011.keys():
            yield self.find(uid2011)

    def find(self, uid):
        region2011 = self.regions2011[uid]

        uids2006 = self.uid2011_to_uids2006.get(uid, None)
        if uids2006 != None:
            regions2006 = (self.regions2006[u] for u in uids2006)
        else:
            regions2006 = None

        return BlockRegion(region2011, regions2006)

def zipfile_to_txtlines(filename):
    with _ZipFile(filename) as zipfile:
        for zipinfo in zipfile.infolist():
            if zipinfo.filename.lower().endswith('.txt'):
                with zipfile.open(zipinfo) as binfile:
                    with io.TextIOWrapper(binfile, 'iso-8859-1') as txtfile:
                        for line in txtfile:
                            yield line

def int_even_if_dot(s):
    if s[-1] in ('.', ' '):
        return 0
    else:
        return int(s)

def iterate_regions_2011(filename):
    #RegionTypeToUidRangeInTextLine = {
    #    'DisseminationBlock': (0, 10), # 1, 10
    #    'DisseminationArea': (48, 56), # 49, 8
    #    'Province': (110, 112), # 111, 2
    #    'ElectoralDistrict': (247, 252), # 248, 5
    #    'EconomicRegion': (337, 341), # 338, 4
    #    'Division': (426, 430), # 427, 4
    #    'Subdivision': (473, 480), # 474, 7
    #    'ConsolidatedSubdivision': (542, 549), # 543, 7
    #    'MetropolitanArea': (703, 706), # 704, 3
    #    'Tract': (807, 817), # 808, 10.2
    #    'Country': (1, 0) # empty-string UID
    #}

    for line in zipfile_to_txtlines(filename):
        uid = line[0:10]
        population = int_even_if_dot(line[10:18])
        dwellings = int_even_if_dot(line[18:26])
        note = line[47]

        if note == ' ': note = None

        yield Region2011(uid, population, dwellings, note)

def iterate_regions_2006(filename):
    #RegionTypeToUidRangeInTextLine = {
    #    'DisseminationBlock': (0, 10),
    #    'DisseminationArea': (48, 56),
    #    'Country': (1, 0)
    #}

    for line in zipfile_to_txtlines(filename):
        uid = line[0:10]
        population = int_even_if_dot(line[10:18])
        note = line[47]

        if note == ' ': note = None

        yield Region2006(uid, population, note)

def load_uid2011_to_uids2006(filename):
    data = {}

    for line in zipfile_to_txtlines(filename):
        uid2011 = line[0:10]
        uid2006 = line[11:21]
        flag = line[22]

        if flag in ('1', '2'):
            if uid2011 not in data:
                data[uid2011] = []
            data[uid2011].append(uid2006)

    return data

if __name__ == '__main__':
    import os
    import sys

    collection = stats_db.get_collection()

    print('Loading correspondence file...', file=sys.stderr)
    uid2011_to_uids2006 = load_uid2011_to_uids2006(
        os.path.join(os.path.dirname(__file__),
            '..', 'db', 'statistics', 'dissemination-blocks', '2011_92-156_DB_ID_txt.zip'))

    print('Opening 2006 file...', file=sys.stderr)
    regions2006 = iterate_regions_2006(
        os.path.join(os.path.dirname(__file__),
            '..', 'db', 'statistics', 'dissemination-blocks', '2006_92-151_XBB_txt.zip'))

    print('Opening 2011 file...', file=sys.stderr)
    regions2011 = iterate_regions_2011(
        os.path.join(os.path.dirname(__file__),
            '..', 'db', 'statistics', 'dissemination-blocks', '2011_92-151_XBB_txt.zip'))

    print('Reading...', file=sys.stderr)
    block_region_store = BlockRegionStore(
            uid2011_to_uids2006,
            regions2011,
            regions2006)

    print('Total regions: %d' % (len(block_region_store.regions2011),), file=sys.stderr)

    print('Writing: "." means 10,000 records: ', file=sys.stderr, end='', flush=True)
    i = 0
    for region in block_region_store:
        region.save_to_collection(collection)
        i += 1
        if i == 10000:
            i = 0
            print('.', end='', flush=True)

    print('', file=sys.stderr)
