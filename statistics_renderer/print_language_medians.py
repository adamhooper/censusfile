#!/usr/bin/env python3.3

import array
import math

import stats_db
from import_region_profiles import LANGUAGES

REVERSE_LANGUAGES = { v:k for k, v in LANGUAGES.items() }
REVERSE_LANGUAGES['?'] = 'Other'
REVERSE_LANGUAGES['T'] = 'Total'
REVERSE_LANGUAGES['en'] = 'English'
REVERSE_LANGUAGES['fr'] = 'French'
REVERSE_LANGUAGES['en+fr'] = 'English and French'
REVERSE_LANGUAGES['en+?'] = 'English and other'
REVERSE_LANGUAGES['fr+?'] = 'French and other'
REVERSE_LANGUAGES['en+fr+?'] = 'English, French and other'

def median(values):
    values = sorted(values)

    f = len(values) / 2
    i = int(f)

    median = values[i]
    if f == i and i > 0:
        # The array has an even number of elements.
        # values[i] is right-of-centre.
        median = (median + values[i-1]) / 2

    return median

class LanguageMatrixTotal:
    def __init__(self):
        self.data = {}

    def add_value(self, key, value):
        if key not in self.data:
            self.data[key] = array.array('d')

        self.data[key].append(value)

    def add_language_matrix(self, matrix):
        total = matrix['T']
        for key, value in matrix.items():
            if value > 0:
                self.add_value(key, value / total)

def main():
    import sys

    total_matrix = LanguageMatrixTotal()

    stats_collection = stats_db.get_collection()

    print('Loading mother tongues...', file=sys.stderr)
    for region_stats in stats_collection.find({ '2011.population.by-mother-tongue': { '$exists': True } }):
        language_matrix = region_stats['2011']['population']['by-mother-tongue']
        total_matrix.add_language_matrix(language_matrix)

    print('Loading languages spoken at home...', file=sys.stderr)
    for region_stats in stats_collection.find({ '2011.population.by-language-spoken-at-home': { '$exists': True } }):
        language_matrix = region_stats['2011']['population']['by-language-spoken-at-home']
        total_matrix.add_language_matrix(language_matrix)

    print('Finding medians...', file=sys.stderr)
    for key in sorted(total_matrix.data.keys()):
        values = total_matrix.data[key]

        mean = sum(values) / len(values)
        median1 = median(values)
        median_deviation = median(math.fabs(value - median1) for value in values)

        name = REVERSE_LANGUAGES[key]
        print("""'%s': { name: "%s", mean: %0.2f, median: %0.2f, mad: %0.2f },""" % (
            key, name, mean * 100, median1 * 100, median_deviation * 100))

if __name__ == '__main__':
    main()
