## Tile format

Tiles are built using the GeoJSON specification.

They're built in two phases, though, because it takes a long time to generate GeoJSON data, even after optimization.

### Phase 1: GeoJSON data, UTFGrid

See GeoJSON 1.0: http://geojson.org/geojson-spec.html
See UTFGrid 1.2 spec (as of 2012-01-11): https://github.com/mapbox/utfgrid-spec/blob/master/1.2/utfgrid.md

A tile looks like this:

    {
      "type": "FeatureCollection", /* GeoJSON */
      "features": [ /* GeoJSON */
        {
          "type": "Feature",
          "geometry": ...GeoJSON geometry...
          "id": "DisseminationArea-12314",
          "properties": {
            "uid": "12314",
            "type": "DisseminationArea",
            "name": "Statistics Canada-supplied name",
            "statistics": { ... }
          }
        },
        ...more features...
      ],
      "utfgrids": [ /* Not banned by the GeoJSON spec */
        {
          "grid": ["...", "...", ... ], /* UTFGrid */
          "keys": [ "", "Province-11", "ElectoralDistrict-132", ... ] /* UTFGrid */
        }
      ]
    }

The GeoJSON contains all data necessary. UTFGrid data is entirely redundant.

We generate UTFGrid data by actually rendering the tiles onto in-memory SVGs
during creation. The benefit: the browser can quickly look up a GeoJSON
feature based on a pixel location.

Why is it a *list* of UTFGrids? Because there's no other way to transmit
partial hierarchies. For instance, if a Tract and Subdivision are in the
same spot, they're shown Tract-on-top-of-Subdivision on the map. But the
Subdivision isn't a parent of the Tract. The only way for the client to
see both (aside from actual hit-detection on vector data) is to transmit
two distinct hierarchies.

We mass-render into the "utfgrids" and "tile\_features" tables. Both are keyed
by (zoom\_level, tile\_row, tile\_column), which are standard across mapping
platforms. The latter table is also keyed by region ID and contains all the
properties we need. You can imagine, then, for a given tile, how we populate
the "utfgrids" column (a single SQL cell) and the "features" list (each entry
corresponds to an SQL row).

We do not render "statistics" in this phase. We postpone that to the last
possible instant, because we need to pre-process everything we can. That way,
when new statistics come out we can publish them much more quickly.

#### Implementation

1. Create schema. (`script/create-regions-table.sql`)
2. Import regions from StatsCan data into the database, using ogr2ogr. (This is left as an exercise to the reader.)
3. There's one problem: Divisions don't have EconomicRegion parents, even though StatsCan's hierarchy diagram says they should. The reason is one exception: Halton, ON (west of Mississauga), which straddles two EconomicRegions. We'll set the parent to a random one of those two, since following StatsCan's hierarchy makes the rest of the code quicker and easier. `UPDATE regions SET economic_region_uid = (SELECT MAX(r2.economic_region_uid) FROM regions r2 WHERE r2.type = 'Subdivision' AND r2.division_uid = regions.uid) WHERE type = 'Division';`
4. Extract individual polygons and useful data concerning them. (`script/preprocess-polygons.sql`)
5. Render them into `region_polygon_tiles`. (`tile_renderer/render_region_polygon_tiles.py`)
6. From `region_polygon_tiles`, render UTFGrids. (`script/preprocess-utfgrids.sql`, `tile_renderer/render_utfgrids.py`)
7. From `region_polygon_tiles`, render `feature_tiles`. (`script/process-features.sql`)
8. From `feature_tiles` and `utfgrids`, render `tiles`. (`script/render_tiles.py` -- it's a wrapper around SQL so we use multiple processors)

Generally, straight SQL is much faster than Python because it works on all
its source data in bulk, instead of a row at a time. We only use Python where
it makes more sense:

1. Slicing a polygon into tiles: there's no good way in SQL to slice the way we do.
2. Rendering UTFGrids: we render SVG to an image buffer; SQL doesn't do that.

## Phase 2: Statistics

We render a table of region\_id -> (JSON) statistics. See
`statistics_renderer/README`.

The tiles we render in Phase 1 have some stubs in their GeoJSON output. Each
feature's "properties" includes a `region_id` key. Before presenting a row from
`tiles` to the user, we need to replace each `"region_id":"1234"` in the JSON
with `"statistics":{...}`.

## Time and space

There is a massive amount of geographic data to process, which is why it's all
done in Phase 1. But how long will it take?

On a speedy computer (Intel four-core, 2.5Ghz CPU, 8GB RAM), it takes about a
week to build a web-server-ready database--if you use the proper optimizations.

Why so long?

In total, there are about 45 million tiles to render. That means spending 2ms
on every tile on one processor takes one day. With a four-core machine, that
speeds up to 6 hours.

We put many operations on the database server itself, and for the rest we use
a "work\_queue" design pattern, with a database table storing a queue of tasks.
The disadvantage of work\_queue is its overhead: for 45M tiles, it's about 1ms
per tile: 3 hours. The disadvantages of straight SQL are that it's
single-threaded, it can't be interrupted and PostgreSQL sometimes decides to
create enormous temporary tables.

Here's a rough breakdown:

1. Preparing to render polygons: about a day
2. Rendering region\_polygon\_tiles: about three days
3. Rendering utfgrids: less than a day (with optimizations)
4. Rendering tile\_features: less than a day
5. Rendering statistics: a few minutes

Tasks 2 and 3 can be split across computers. Either make them share a database
server, or do the manual work of partitioning the `work_queue` and `work_queue2`
tables, running `render_region\_polygon\_tiles.py` and `render_utfgrids.py` on the
separate computers, and then merging the resulting `region\_polygon\_tiles` and
utfgrids tables afterwards. (And since utfgrids depends exactly on the data
produced from `region\_polygon\_tiles`, you don't need to merge the tables after
step 2 and split them before step 3.)

### How you can optimize it

#### PostgreSQL

Our use case with PostgreSQL is: a few clients (either a single SQL command, or
a small army of paralellel processes doing the same few queries--ideally one
per CPU core. Few connections, massive computations.

* Turn `work_mem` up (e.g. `32MB`)
* Turn `maintenance_work_mem` way up (e.g. `1GB`).
* Turn off `synchronous_commit`: we can restart our processing at any command,
  and it's very slow for lots of commits (which our `work_queue` method uses).
* Bump `checkpoint_segments` up (e.g., to `64`) because we do some enormous UPDATEs.

The `work_queue` overhead, in steps 2 and 3 above, comes out to roughly 10-15%
of the total, which is acceptable.

#### Python

Run `python setup.py build` in the `tile_renderer/ext` directory for some
huge speed-ups to UTFGrid rendering (from 20ms to 3ms on a speedy computer).
We use C code to avoid Python objects and to optimize a loop that turns an
ARGB image buffer into Unicode strings.

Incidentally: Python threading isn't ideal for us, because of its Global
Interpreter Lock. We use processes instead.
