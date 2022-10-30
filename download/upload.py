#!/usr/bin/env python3

import asyncio
import re
import sqlite3
import traceback
import zlib
from collections import deque
from concurrent.futures import ThreadPoolExecutor
from typing import Dict, Iterator, NamedTuple, Optional, Tuple

import aioboto3

N_GEOJSON_WORKERS = 3  # bottleneck is S3 upload
N_UPLOAD_WORKERS = 200

class TileCoordinates(NamedTuple):
    """
    Integer coordinates of a tile.

    Map servers use "zoom/column/row.ext". Our mbtiles database has it
    backwards: it's indexed by "zoom, row, column". Be careful.
    """
    zoom: int
    row: int
    column: int

BUCKET = "censusfile.adamhooper.com"
REGION_REGEX = re.compile(b'"region_id":(\d+)')


def load_region_statistics() -> Dict[bytes, bytes]:
    """
    Load a dictionary from region ID to region value.

    Keys are integers encoded as `bytes`, because that's what we lookup
    """
    connection = sqlite3.connect("statistics.sqlite3")
    cursor = connection.cursor()
    ret: Dict[bytes,bytes] = {}
    for region_id, compressed_stats in cursor.execute(
        "SELECT region_id, statistics FROM region_statistics"
    ):
        ret[str(region_id).encode("ascii")] = zlib.decompress(compressed_stats)
    cursor.close()
    connection.close()
    return ret


def iterate_tiles(last_ordered_finish: TileCoordinates) -> Iterator[Tuple[TileCoordinates,bytes]]:
    """
    Iterate over all (coord, zlib_compressed_geojson) pairs.
    """
    connection = sqlite3.connect('tiles.sqlite3')
    cursor = connection.cursor()
    cursor.arraysize = 100
    z, r, c = last_ordered_finish
    try:
        cursor.execute(
            """
            SELECT zoom_level, tile_row, tile_column, tile_data
            FROM tiles
            WHERE zoom_level > ?
               OR (zoom_level = ? AND tile_row > ?)
               OR (zoom_level = ? AND tile_row = ? AND tile_column > ?)
            ORDER BY zoom_level, tile_row, tile_column
            """,
            (z, z, r, z, r, c)
        )
        print("Prepared tile list")
        for [zoom_level, tile_row, tile_column, tile_data] in cursor:
            yield TileCoordinates(zoom_level, tile_row, tile_column), tile_data
    finally:
        cursor.close()
        connection.close()


class ProgressPointer:
    """
    Maintain `last_ordered_finish`, a value we can use to resume later.

    Assume we start elements in order but finish out-of-order. Then at any
    moment we'll have progress like this

        F F F F F F F S S S F F S F F S S . . . . . . . . . . .
                                         ^ everything after this isn't started
                     ^ everything before this is finished
    """

    def __init__(self, last_ordered_finish: TileCoordinates):
        self.last_ordered_finish = last_ordered_finish  # what we're maintaining
        self.started: deque[TileCoordinates] = deque()
        self.started_finished: set[TileCoordinates] = set()  # included in self.started
        self.n_finished = 0
        self.errored: Dict[TileCoordinates,str] = {}

    def start(self, coord: TileCoordinates):
        """
        Mark the next `coord` as "started".
        """
        assert coord > self.last_ordered_finish
        self.started.append(coord)

    def finish(self, coord: TileCoordinates, error_message: Optional[str]):
        """
        Mark `coord` as "finished", and update `self.last_ordered_finish`.

        If `error_message` is set, store that error forever.
        """
        assert len(self.started) > 0

        if error_message is not None:
            self.errored[coord] = error_message

        if self.started[0] == coord:
            self.last_ordered_finish = self.started.popleft()
            while len(self.started) and self.started[0] in self.started_finished:
                self.last_ordered_finish = self.started.popleft()
                self.started_finished.remove(self.last_ordered_finish)
        else:
            self.started_finished.add(coord)

        self.n_finished += 1
        if self.n_finished % 1000 == 0:
            print("Finished %d this run, notably zoom=%d, row=%d, column=%d" % (self.n_finished, *self.last_ordered_finish))
            if self.errored:
                print("Errors: %r" % (self.errored))


async def step_2_generate_tile(
    worker_index: int,
    geojson_queue,#: asyncio.Queue[Tuple[TileCoordinates,bytes]],
    region_statistics: Dict[bytes, bytes],
    upload_queue,#: asyncio.Queue[Tuple[TileCoordinates,bytes]],
    cpu_executor: ThreadPoolExecutor,
    progress: ProgressPointer
):
    loop = asyncio.get_running_loop()

    def repl(match: re.Match):
        """
        b'"region_id":1234' => b'"region_id":1234,"statistics":{...}'
        """
        region_id: bytes = match.group(1)
        statistics_json = region_statistics[region_id]
        return b'"region_id":' + region_id + b',"statistics":' + statistics_json

    def generate_compressed_tile(compressed_geojson: bytes) -> Optional[bytes]:
        raw_geojson = zlib.decompress(compressed_geojson)
        if raw_geojson == b"{}":
            return None
        geojson = REGION_REGEX.sub(repl, raw_geojson)
        return zlib.compress(geojson)

    while True:
        coord, compressed_geojson = await geojson_queue.get()
        error_message = None
        try:
            final_bytes = await loop.run_in_executor(cpu_executor, generate_compressed_tile, compressed_geojson)
        except Exception as err:
            traceback.print_exc()
            error_message = str(err)

        if final_bytes is None:
            progress.finish(coord, error_message)
        else:
            await upload_queue.put((coord, final_bytes))
        geojson_queue.task_done()


async def step_3_upload_tile(
    worker_index: int,
    upload_queue,#: asyncio.Queue[Tuple[TileCoordinates,bytes]],
    progress: ProgressPointer
):
    session = aioboto3.Session()
    async with session.client("s3") as s3:
        while True:
            coord, geojson = await upload_queue.get()
            key = "tiles/%d/%d/%d.geojson" % (coord.zoom, coord.column, coord.row)
            error_message = None
            try:
                await s3.put_object(
                    Body=geojson,
                    Bucket=BUCKET,
                    Key=key,
                    CacheControl="public, max-age=604800, immutable",
                    ContentType="application/geo+json",
                    ContentEncoding="deflate",
                )
            except Exception as err:
                traceback.print_exc()
                error_message = str(err)

            upload_queue.task_done()
            progress.finish(coord, error_message)


async def main(last_ordered_finish: TileCoordinates):
    region_statistics = load_region_statistics()
    print("Loaded region statistics")

    geojson_queue = asyncio.Queue(N_GEOJSON_WORKERS * 2)
    upload_queue = asyncio.Queue(N_UPLOAD_WORKERS * 2)
    progress = ProgressPointer(last_ordered_finish)

    cpu_executor = ThreadPoolExecutor(N_GEOJSON_WORKERS, thread_name_prefix='cpu_executor')

    step_2_tasks = [
        asyncio.create_task(
            step_2_generate_tile(i, geojson_queue, region_statistics, upload_queue, cpu_executor, progress)
        )
        for i in range(N_GEOJSON_WORKERS)
    ]

    step_3_tasks = [
        asyncio.create_task(step_3_upload_tile(i, upload_queue, progress))
        for i in range(N_UPLOAD_WORKERS)
    ]

    tasks = [*step_2_tasks, *step_3_tasks]

    for coord, zlib_compressed_geojson in iterate_tiles(last_ordered_finish):
        progress.start(coord)
        await geojson_queue.put((coord, zlib_compressed_geojson))

    await geojson_queue.join()
    await upload_queue.join()

    for task in tasks:
        task.cancel()
    await asyncio.gather(*tasks, return_exceptions=True)


if __name__ == "__main__":
    asyncio.run(main((-1, -1, -1)))
