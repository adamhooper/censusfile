#!/usr/bin/env python3.3

FILENAME_PATTERN = '98-316-XWE2011001-%s_CSV.zip'
CSV_ENCODING = 'iso-8859-1'

import csv
import io
import os.path
from zipfile import ZipFile as _ZipFile

import master_db

_age_groups = ['0 to 4 years', '5 to 9 years', '10 to 14 years', '15 to 19 years', '20 to 24 years', '25 to 29 years', '30 to 34 years', '35 to 39 years', '40 to 44 years', '45 to 49 years', '50 to 54 years', '55 to 59 years', '60 to 64 years', '65 to 69 years', '70 to 74 years', '75 to 79 years', '85 years and over']
_age_group_keys = [ '   %s' % age_group for age_group in _age_groups ]
_age_group_keyset = set(_age_group_keys)

_marital_statuses = [
    ('married', 'Married (and not separated)'),
    ('common-law', 'Living common-law'),
    ('single', 'Single (never legally married)'),
    ('separated', 'Separated'),
    ('divorced', 'Divorced'),
    ('widowed', 'Widowed')
]
_marital_status_key_to_real_key = dict(('      ' + s[1], s[0]) for s in _marital_statuses)
_marital_status_keyset = set(_marital_status_key_to_real_key.keys())

_parents = [
    ('married', 'Married couples'),
    ('common-law', 'Common-law couples'),
    ('female', 'Female parent'),
    ('male', 'Male parent')
]
_parents_key_to_real_key = dict(('      ' + p[1], p[0]) for p in _parents)
_parent_keyset = set(_parents_key_to_real_key.keys())

class Region:
    def __init__(self, region_id):
        self.region_id = region_id

        self.values = {}
        self.notes = {}
        self.by_age = { 'male': {}, 'female': {}, 'total': {} }
        self.by_marital_status = {}
        self.by_parents = {}

    def _by_age_arrays(self):
        return dict((
            (sex,
                [self.by_age[sex].get(k, 0) for k in _age_group_keys]
            ) for sex in ('total', 'male', 'female')
        ))

    def _by_marital_status(self):
        return dict((s[0], self.by_marital_status.get(s[0], 0)) for s in _marital_statuses)

    def _by_parents(self):
        return dict((p[0], self.by_parents.get(p[0], 0)) for p in _parents)

    def set_value(self, key, value, note):
        self.values[key] = value
        if note is not None:
            self.notes[key] = note

    def add_by_age(self, key, value, value_m, value_f, note):
        if key in _age_group_keyset:
            self.by_age['male'][key] = value_m
            self.by_age['female'][key] = value_f
            self.by_age['total'][key] = value

            if note is not None and key not in self.notes:
                self.notes['2011.population.by-age'] = note

    def add_by_marital_status(self, key, value, note):
        real_key = _marital_status_key_to_real_key[key]
        self.by_marital_status[real_key] = value

        if note is not None and key not in self.notes:
            self.notes['2011.population-15-and-over.by-marital-status'] = note

    def add_by_parents(self, key, value, note):
        real_key = _parents_key_to_real_key[key]
        self.by_parents[real_key] = value

        if note is not None and key not in self.notes:
            self.notes['2011.families.by-parents'] = note

    def write(self, collection):
        collection_region = collection.get_region(self.region_id)

        collection_region.set('2011.population.by-age.total', self._by_age_arrays())
        collection_region.set('2011.population-15-and-over.by-marital-status', self._by_marital_status())
        collection_region.set('2011.families.by-parents', self._by_parents())

        for k, v in self.values.items():
            collection_region.set(k, v)
            if k in self.notes:
                collection_region.set('notes.%s' % k, self.notes[k])

        collection_region.save()

# Loads file-objects for every region type possible.
#
# Usage:
#
#     loader = FileLoader(dirname)
#     for (region_type, csv_file) in loader.region_types_and_csv_files():
#         ... # csv_file is an opened file-like object.
#
# Sometimes one region_type maps to several csv_files. The block in the loop
# will be executed once per csv_file.
class FileLoader:
    RegionTypeFilenames = (
        ('Province', '101'),
        ('Division', '701'),
        ('Subdivision', '301'),
        ('MetropolitanArea', '201'),
        ('Tract', '401'),
        ('ElectoralDistrict', '501'),
        ('EconomicRegion', '901'),
        ('DisseminationArea', '1501')
    )

    def __init__(self, dirname):
        self.dirname = dirname

    def _region_types_and_zipfiles(self):
        for region_type, key in FileLoader.RegionTypeFilenames:
            filename = FILENAME_PATTERN % key
            path = os.path.join(os.path.dirname(__file__), '..', 'db', 'statistics', 'region-profiles', filename)
            with _ZipFile(path) as zipfile:
                yield region_type, zipfile

    def region_types_and_csv_files(self):
        for region_type, zipfile in self._region_types_and_zipfiles():
            for zipinfo in zipfile.infolist():
                filename = zipinfo.filename.lower()

                if filename.endswith('.csv') and 'metadata' not in filename:
                    with zipfile.open(zipinfo) as csv_file:
                        with io.TextIOWrapper(csv_file, CSV_ENCODING) as text_csv_file:
                            yield region_type, text_csv_file

class RegionProfileCsvImporter:
    CharacteristicToKey = {
        'Population in 2011': '2011.population.total',
        'Population in 2006': '2006.population.total',
        '2006 to 2011 population change (%)': '2011.population.growth',
        'Total private dwellings': '2011.dwellings.total',
        'Median age of the population': '2011.population.median-age',
        'Total population 15 years and over by marital status': '2011.population-15-and-over.total',
        'Total number of census families in private households': '2011.families.total',
        'Total children in census families in private households': '2011.families.children-at-home',
        'Average number of children at home per census families': '2011.families.children-at-home-per-family',
        'Average number of persons per census family': '2011.families.people-per-family'
    }

    def __init__(self, collection, region_type, csv_file):
        self.collection = collection
        self.region_type = region_type
        self._region_prefix = self.region_type + '-'

        # There's not much point in DictReader because the headers are
        # different in different files. Instead, we figure out integer keys
        # now.
        self.csv = csv.reader(csv_file)

        fieldnames = next(self.csv)

        if not fieldnames[0].startswith('Geo'):
            # The first line isn't the headers; skip to the second
            fieldnames = next(self.csv)

        self.geo_code_index = 0

        if 'Characteristic' in fieldnames:
            self.characteristic_index = fieldnames.index('Characteristic')
        else:
            self.characteristic_index = fieldnames.index('Characteristics')

        self.note_index = fieldnames.index('Note')
        self.value_index = fieldnames.index('Total')
        self.male_index = fieldnames.index('Male')
        self.female_index = fieldnames.index('Female')

        self.last_region = None

    def _handle_csv_row(self, csv_row):
        region_id = self._region_prefix + csv_row[self.geo_code_index]

        if self.last_region is None:
            self.last_region = Region(region_id)
        elif self.last_region.region_id != region_id:
            self.last_region.write(self.collection)
            self.last_region = Region(region_id)
        region = self.last_region

        characteristic = csv_row[self.characteristic_index]

        value_string = csv_row[self.value_index]
        note_string = csv_row[self.note_index]

        if len(value_string) > 0:
            if '.' in value_string:
                value = float(value_string)
            else:
                value = int(value_string)
        else:
            value = 0

        if len(note_string) > 0:
            note = int(note_string)
        else:
            note = None

        if characteristic in RegionProfileCsvImporter.CharacteristicToKey:
            key = RegionProfileCsvImporter.CharacteristicToKey[characteristic]
            region.set_value(key, value, note)
        elif characteristic in _age_group_keyset:
            value_m_string = csv_row[self.male_index]
            value_f_string = csv_row[self.female_index]

            if len(value_m_string) > 0:
                value_m = int(value_m_string)
            else:
                value_m = 0

            if len(value_f_string) > 0:
                value_f = int(value_f_string)
            else:
                value_f = 0

            region.add_by_age(characteristic, value, value_m, value_f, note)
        elif characteristic in _marital_status_keyset:
            region.add_by_marital_status(characteristic, value, note)
        elif characteristic in _parent_keyset:
            region.add_by_parents(characteristic, value, note)

    def import_all(self):
        for row in self.csv:
            self._handle_csv_row(row)

        if self.last_region:
            self.last_region.write(self.collection)

def main():
    import master_db

    loader = FileLoader('db/statistics/region-profiles')
    collection = master_db.get_collection()

    for region_type, csv_file in loader.region_types_and_csv_files():
        print('Importing a CSV of %s...' % region_type)
        importer = RegionProfileCsvImporter(collection, region_type, csv_file)
        importer.import_all()

if __name__ == '__main__':
    main()
