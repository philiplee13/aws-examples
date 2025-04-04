import time
import tracemalloc
import aioboto3
import asyncio


def handler(event, context):
    asyncio.run(main())


async def main():
    await read_file_async()


async def read_file_async():
    print("downloading file async")
    t1 = time.perf_counter(), time.process_time()
    source_bucket = "lambda-source-test-bucket"
    destination_bucket = "lambda-new-bucket"
    key = "random_5gb_file"

    tracemalloc.start()
    session = aioboto3.Session()
    copy_source = {"Bucket": source_bucket, "Key": key}
    async with session.client("s3") as s3:
        await s3.copy(CopySource=copy_source, Bucket=destination_bucket, Key=key)
    t2 = time.perf_counter(), time.process_time()
    print("Total time for async request was")
    print(f" Real time: {t2[0] - t1[0]:.2f} seconds")
    print(f" CPU time: {t2[1] - t1[1]:.2f} seconds")

    current, peak = tracemalloc.get_traced_memory()
    print(f"Current memory usage: {current} bytes")
    print(f"Peak memory usage: {peak} bytes")
