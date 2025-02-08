## Local stack

- docker-compose free stuff
- makefile
- same services (s3, sqs, etc)
- localstack and how to incorporate in programs

### Local stack docker-compose

- put the services you want in the `environment` attribute
  - https://docs.localstack.cloud/user-guide/aws/feature-coverage/

### To make sample calls

- need to include the `endpoint-url`

  - `aws --endpoint-url=http://localhost:4566 <resource> <action>`
  - `aws --endpoint-url=http://localhost:4566 s3api list-buckets`

- you probably need to include some `init.sh` scripts or something to create some test resources
