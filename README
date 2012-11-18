== To generate data files

=== db/statistics.sqlite3

TODO: describe how to set up the `venv` directory, using Python 3.3.

Open a console and run this:

    ./script/run_mongodb.sh

Keep that running. Open a second console and run this:

    ./script/render_statistics.sh db/statistics.sqlite3

(Ensure `db/statistics.sqlite3` does not exist before running this. Always create a new file.)

After it's done (it should take about 10-15 minutes), you can close both consoles. The statistics will remain easily-accessible via MongoDB, in `db/mongodb/db/`. You can re-run certain steps to overwrite that data.

The code you're running lives in `statistics_renderer`, and the source data (from Statistics Canada) are in `db/statistics/`.

See `statistics_renderer/README` to see how this all works.

=== db/tiles.sqlite3

It's a long, enormous story. I'll write it up later.

See `tile_renderer/README` to see how tiles are rendered.

== To launch on Amazon EC2

You need at least 40GB of hard drive space, and it's probably faster to stay away from EBS. That means the minimum instance is m1.small. (So it isn't free.)

Run these commands on a brand-new Ubuntu 12.10 instance, with instance storage attached in `/mnt`.

    $ sudo apt-get install nginx python3.3 uwsgi uwsgi-plugin-python3

    $ sudo mkdir /mnt/censusfile
    $ sudo chown ubuntu:ubuntu /mnt/censusfile
    $ sudo ln -s /mnt/censusfile /opt/censusfile

    $ mkdir /opt/censusfile/db
    $ # copy "tiles.sqlite3" and "statistics.sqlite3" to /opt/censusfile/db
    $ mkdir /opt/censusfile/conf
    $ # add "nginx-vhost.conf" to /opt/censusfile/conf
    $ # add "uwsgi.ini" /opt/censusfile/conf

    $ sudo ln -s /opt/censusfile/conf/uwsgi.ini /etc/uwsgi/apps-available/censusfile.ini
    $ sudo ln -s /etc/uwsgi/apps-available/censusfile.ini /etc/uwsgi/apps-enabled
    $ sudo service uwsgi restart
    $ sudo ln -s /opt/censusfile/conf/nginx-vhost.conf /etc/nginx/sites-available/censusfile
    $ sudo ln -s /etc/nginx/sites-available/censusfile /etc/nginx/sites-enabled
    $ sudo rm /etc/nginx/sites-enabled/default
    $ sudo service nginx restart
    $ curl --resolve censusfile.adamhooper.com:80:127.0.0.1 \
           http://censusfile.adamhooper.com/regions/8/74/92.geojson # test it renders tiles

    $ mkdir /opt/censusfile/public
    $ # add "index.html" to /opt/censusfile/public
    $ # add "assets" directory to /opt/censusfile/public
