## Terraform infra

### Files

- `s3.tf` -> handles creation of s3 bucket for tf state
- `main.tf` -> aws resource creation

### Commands

- to init a config with a specific setting
  `terraform init -reconfigure -backend-config=<settings.conf file>`

- to plan a tf output with specific vars
  `terraform plan -var-file=<variables.tfvars>`

  ### Migrate Monolith state to environment specific state

  - [Ref](https://dev.to/ewsct/breaking-down-terraform-monolith-into-multiple-environments-fcg)
  - Let's assume that your state is in [`main.tf`]
  - You'll need to...
    - first create a location for each "state" (s3 buckets)
    - then you'll need to migrate the appropriate resources `terraform state mv...`
    - then run terraform plan to make sure everything got migrated successfully
  - Or we can use [workspaces](https://developer.hashicorp.com/terraform/tutorials/modules/organize-configuration#separate-states)

### Lambda based apis

- https://www.reddit.com/r/aws/comments/173ybvv/should_you_use_a_lambda_monolith_aka_lambdalith/
