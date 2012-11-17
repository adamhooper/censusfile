#!/bin/sh
#
# Requires you start mongodb in another terminal. See run_mongodb.sh

DIR=`dirname $0`/..

. "$DIR"/venv/bin/activate

"$DIR"/statistics_renderer/import_region_profiles.py

"$DIR"/statistics_renderer/import_dissemination_blocks.py

"$DIR"/statistics_renderer/import_bounding_boxes.py

"$DIR"/statistics_renderer/create_sqlite3_database.py | sqlite3 "$1"
