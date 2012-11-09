#!/usr/bin/env python3.3

from pymongo import Connection

def get_collection():
    connection = Connection('localhost', 23678)
    database = connection.censusfile
    return MasterDbCollection(database.regions)

class MasterDbCollection:
    def __init__(self, collection):
        self.collection = collection

    def find(self, json):
        return self.collection.find(json)

    def get_region(self, region_id):
        return MasterDbRegion(self, region_id)

class MasterDbRegion:
    def __init__(self, collection, region_id):
        self.collection = collection.collection
        self.region_id = region_id
        self.sets = {}

    def set(self, key, value):
        self.sets[key] = value

    def save(self):
        self.collection.update(
            { '_id': self.region_id },
            { '$set': self.sets },
            True # upsert
        )
