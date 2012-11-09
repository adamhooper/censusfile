# How CensusFile stores data

All the data Statistics Canada data is grouped by region. (A reminder: a region can be the country, a province, a tract, a metropolitan area, and so on.)

Statistics Canada provides many different representations of its data--often, but not always, as CSV files.

CensusFile does the following:

* Parses Statistics Canada data, grouped by region, from different files;
* Runs calculations on that data, for each region, (for instance, it may turn a number into a percentage); and
* Passes the data to a web client.

For this, it needs three file stores:

* Raw files from Statistics Canada, in whatever format is available;
* A "master" structure for each region, which accumulates parsed data in a format that is easy to process; and
* A "web" structure for each region, which is as quick as possible to query and holds the minimum amount of information the client needs.

This is easiest to explain backwards.

## Dissemination Blocks - "web"

The simplest set of data is for the smallest region, the "Dissemination Block". The server will send JSON that looks like this (in annotated JSON):

    {
        "a": 1000000, /* area in m^2 */
        "2011": {
            "p": 1234, /* population */
            "g": 23.4, /* per cent growth - derived, for Dissemination Blocks, and official for others */
            "d": 1234, /* density - derived */
            "dw": 1000, /* number of dwellings */
        },
        "2006": {
            "p": 1000, /* population in 2006 */
        },
        "notes": {
            "2011.p": [1],
            "2006.p": [1,2],
        }
    }

We can use this as an illustration, to build to our next step.

Remarks:

* The data is keyed by year, even though we rarely care about past years. It helps, conceptually.
* Keys are brief (to save bytes) but not entirely obfuscated (since client code needs to use these same keys).
* `2011.d` is a derived value. When we can, we send derived values to save the client work.
* `2011.g` is a derived value, *but only for Dissemination Blocks*. With everything except Dissemination Blocks, Statistics Canada calculates its own growth number, and we prefer official data to derived data.
* `notes` is a sparse hash of hashes. We use the same positive integers Statistics Canada does to annotate our values. We use negative integers to add our own annotation.

## Marking up derived values

Sometimes CensusFile uses official Statistics Canada numbers, and sometimes it uses numbers it has derived from them.

There *is* a difference. For instance, if there are three women and three men aged 85 or over in a particular Dissemination Area, Statistics Canada will report that there are *five* women and *five* men: it rounds them. Were we to add them, we would derive a total of 10; the official total is five.

We must never present derived data where official data exists, because derived data can be wrong. And when we *do* present derived data, we must mark it as such.

This is part of the schema. Consider this document the definitive guide.

## Arbitrary Regions - "web"

For anything other than a Dissemination Area, we will send all this:

    {
        "z": 12, /* zoom level of largest children--see notes */
        "a": 1000000,
        "2011": {
            "p": 1234, /* population */
            "g": 23.4, /* per cent growth - derived, for Dissemination Blocks, and official for others */
            "a": {
                "m": [ 0, 1, 2, 3, ... ], /* male by age: 0-4, 5-9, etc. */
                "f": [ 0, 1, 2, 3, ... ], /* female by age: 0-4, 5-9, etc. */
                "t": [ 0, 1, 2, 3, ... ], /* people by age: 0-4, 5-9, etc. */
            },
            "d": 1234, /* density - derived */
            "dw": 1000, /* number of dwellings */
            "mtv": [ en, fr, ot, en+fr, en+ot, fr+ot, en+fr+ot ], /* mother-tongue info for a Venn diagram */
            "mt": { "en": 1200, "fr": 30, ... }, /* sparse array of mother tongues */
            "lh": { "en": 1200, "fr": 30, ... }, /* sparse array of language spoken at home */
            "lm": 23.1, /* official language minority (percentage) */
            "f": 600, /* number of Census Families */
            "pf": 3.3, /* people per family */
            "cf": 1.4, /* children at home per family */
            "s": [ s, m, s, d, w ], /* people by status: single, married, separated, divorced, widowed */
            "fp": [ m, c, f, m ], /* number of families that are married, common-law, father-only, mother-only */
            "dt": [ 0, 1, 2, 3, ... ], /* number of dwellings by type (see below) */
            "do": [ o, r, b ], /* number of dwellings by ownership: owned, rented, band */
        },
        "2006": {
            "p": 1234, /* population */
        },
        "notes": {
            ...
        }
    }

Remarks:

* `2011.mtv`: these are *derived*. Statistics Canada provides these as disjoint sets; CensusFile adds them. In CensusFile, `en` includes all the people in `en+fr`.
* `2011.s`: Statistics Canada *presents* census data the way questions were asked. 
* `2011.dt`: Dwelling types are: Single-detached house, Apartment in building that has five or more storeys, Movable dwelling, Other dwelling, Semi-detached house, Row house, Duplex, Apartment in building that has fewer than five storeys, Other single-attached house
* `z`: We can optimize the client-side map by telling it when it can skip rendering a region. It can skip rendering a region when children are visible--in other words, when the client-side zoom level is greater than or equal to `z`.

## Arbitrary Regions - "master"

To arrive at the "web" representation, we store this in our database:

    {
        "_id": "DisseminationArea-2342312", /* regions.type + '-' + regions.uid */
        "area": 1000000,
        "2011": {
            "population": {
                "total": 1234,
                "growth": 23.4,
                "median-age": 43.2,
                "by-age": {
                    "male": [ 0, 1, 2, 3, ... ], /* 0-4, 5-9, etc. */
                    "female": [ 0, 1, 2, 3, ... ],
                    "total": [ 0, 1, 2, 3, ... ]
                },
                "by-official-mother-tongue": {
                    "en": 1200,
                    "fr": 30,
                    ... /* "*" (other), "en+fr", "en+*", etc. */
                },
                "by-mother-tongue": {
                    "en": 1200,
                    "fr": 30,
                    ...
                },
                "by-language-spoken-at-home": {
                    "en": 1200,
                    "fr": 30,
                    ...
                },
                "official-language-minority": 23.1, /* percentage */
            },
            "population-15-and-over": {
                "total": 900,
                "by-marital-status": {
                    "single": 200,
                    "married": 400,
                    "common-law": 200,
                    "separated": 30,
                    "divorced": 30,
                    "widowed": 40,
                },
            },
            "families": {
                "total": 600,
                "people-per-family": 3.3,
                "children-at-home": 790,
                "children-at-home-per-family": 1.4,
                "by-parents": {
                    "married": 230,
                    "common-law": 230,
                    "mother-only": 120,
                    "father-only": 20
                },
            },
            "dwellings": {
                "total": 1234,
                "by-ownership": {
                    "owned": 1000,
                    "rented": 230,
                    "band": 4
                },
                "by-type": {
                    ...
                }
            }
        },
        "2006": { ... },
        "notes": { ... }
    }

## Raw files

Raw files from Statistics Canada are stored in `db/statistics/`. Read `db/statistics/README` for details.
