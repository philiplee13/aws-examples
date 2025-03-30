import time
import boto3
import tracemalloc


def handler(event, context):
    read_file_synchrnous()


def read_file_synchrnous():
    t1 = time.perf_counter(), time.process_time()

    tracemalloc.start()
    s3 = boto3.client("s3")
    s3.download_file(
        "lambda-source-test-bucket",
        "random_5gb_file",
        "tmp/5gb-file-froms3",
    )
    print("now writing to source bucket")
    s3.upload_file(
        "tmp/5gb-file-froms3",
        "lambda-new-bucket",
        "5gb-from-test-bucket-sync",
    )
    t2 = time.perf_counter(), time.process_time()
    print("Total time for synchronous request was")
    print(f" Real time: {t2[0] - t1[0]:.2f} seconds")
    print(f" CPU time: {t2[1] - t1[1]:.2f} seconds")

    current, peak = tracemalloc.get_traced_memory()
    print(f"Current memory usage: {current} bytes")
    print(f"Peak memory usage: {peak} bytes")
