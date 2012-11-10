#!/bin/sh

cd "`dirname $0`/../db/mongodb"

mongod --config ./mongodb.conf
