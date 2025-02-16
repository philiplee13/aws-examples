import boto3


def handler(event, context):
    message = "Hello world"
    print(f"event is {event}")
    details = event.get("Records", [])
    print(f"details is {details[0]}")
    if details:
        print(f"triggered event is {details[0].get("eventName")}")
        print(f"file key is {details[0].get("s3").get("object").get("key")}")
        s3 = boto3.resource("s3")
        s3.meta.client.download_file(
            "lambda-event-notify-test-bucket",
            "test.txt",
            "/tmp/test.txt",
        )
        s3.meta.client.upload_file(
            "/tmp/test.txt",
            "lambda-event-put-test-bucket",
            "file-from-get-bucket.txt",
        )
        print("file uploaded")
