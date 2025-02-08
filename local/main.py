import boto3


def main():
    print("hello")
    s3 = boto3.resource("s3")
    my_bucket = s3.Bucket("test-bucket")
    print(f"bucket is {my_bucket}")


if __name__ == "__main__":
    main()
