## Attribution

The data files in this directory were all created by Statistics Canada, and
they are all shared here under the Statistics Canada Open License Agreement.

The terms: http://www.statcan.gc.ca/reference/licence-eng.html

## region-profiles/

We start with a profile of each region (except for dissemination blocks). These
profiles don't have *all* information, but they are easier to interpret than
the other downloads, so they're a good starting point for developers.

Download files from:

http://www12.statcan.gc.ca/census-recensement/2011/dp-pd/prof/details/download-telecharger/comprehensive/comp-csv-tab-dwnld-tlchrgr.cfm?Lang=E

Files needed:

* 98-316-XWE2011001-101_CSV.zip
* 98-316-XWE2011001-201_CSV.zip
* 98-316-XWE2011001-301_CSV.zip
* 98-316-XWE2011001-401_CSV.zip
* 98-316-XWE2011001-501_CSV.zip
* 98-316-XWE2011001-701_CSV.zip
* 98-316-XWE2011001-901_CSV.zip
* 98-316-XWE2011001-1501_CSV.zip

Leave them as zip files.

## dissemination-blocks/

Statistics Canada also provides population and dwelling counts down to the
dissemination block (a very small area indeed). They must be imported
separately. Statistics Canada does not correlate the data with 2006 data, but
it provides enough data for us to do that ourselves.

Download files from:

http://www12.statcan.gc.ca/census-recensement/2011/geo/ref/att-eng.cfm
http://www12.statcan.gc.ca/census-recensement/2011/geo/ref/cor-eng.cfm

Files needed:

* 2011_92-151_XBB_txt.zip
* 2006_92-151_XBB_txt.zip
* 2011_92-156_DB_ID_txt.zip

Leave them as zip files.
