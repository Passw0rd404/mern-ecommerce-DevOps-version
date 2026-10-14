# Prerequisites

This project has two setup paths:

- **Local application development** — run the MERN application on your machine.
- **AWS deployment** — provision the complete infrastructure and run the GitHub Actions workflows.

Never commit `.env`, Terraform variable files containing real credentials, API keys, tokens, or private keys.

## Required local tools

Install the following tools before working with the repository:

| Requirement | Why it is needed | Where to get it |
|---|---|---|
| Git | Clone the repository and work with GitHub Actions source | [git-scm.com/downloads](https://git-scm.com/downloads) |
| Node.js 24.x | Run the backend and build the frontend | [nodejs.org](https://nodejs.org/) |
| npm | Install JavaScript dependencies; included with Node.js | [npm documentation](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm) |
| Terraform `>= 1.10` | Provision AWS, MongoDB Atlas, and Grafana resources | [developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install) |
| AWS CLI | Authenticate locally and inspect AWS resources | [AWS CLI installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Packer | Validate and build the EC2 AMI | [developer.hashicorp.com/packer/install](https://developer.hashicorp.com/packer/install) |
| Docker (optional) | Useful for local supporting services or troubleshooting | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) |

Install project dependencies from the repository root and frontend directory:

```bash
npm ci
npm ci --prefix frontend
```

## Required accounts and services

Create or obtain access to the following services:

| Service | What you need | Where to get it |
|---|---|---|
| AWS | An account with permission to bootstrap IAM, S3, VPC, EC2, CloudFront, ACM, ElastiCache, Secrets Manager, CodeDeploy, SSM, and related resources | [aws.amazon.com](https://aws.amazon.com/) |
| GitHub | A repository and permission to configure Actions variables, secrets, and OIDC workflows | [github.com](https://github.com/) |
| MongoDB Atlas | An organization, project, database user, and cluster/PrivateLink access | [mongodb.com/atlas](https://www.mongodb.com/atlas) |
| Grafana Cloud | A stack, CloudWatch integration, OTLP credentials, and AWS PrivateLink service | [grafana.com/products/cloud](https://grafana.com/products/cloud/) |
| Kashier | Test or live merchant credentials for payment sessions and signed callbacks | [kashier.io](https://kashier.io/) |
| DNS provider | A domain and permission to create CNAME records; this project reports records for manual creation | Use the DNS provider where your domain is managed |

The deployment currently targets AWS `eu-central-1`. CloudFront ACM certificates must be created in `us-east-1`.

## Values required for Terraform

Copy `infrastructure-live-v1/dev/dev.tfvars` and replace its example values for your environment. The file requires:

- `domain_name`: a domain you control, such as `dev.example.com`
- `grafana_stack_slug`: your Grafana Cloud stack slug
- `grafana_external_id`: the external ID configured for the Grafana AWS integration
- `grafana_cloud_provider_api_url`: the Grafana Cloud provider API endpoint for your stack
- `grafana_otlp_instance_id`: your Grafana OTLP instance ID
- `grafana_otlp_endpoint`: the OTLP endpoint for your Grafana Cloud stack
- `grafana_privatelink_service_name`: the AWS PrivateLink service name supplied by Grafana Cloud

Terraform variables marked sensitive in `infrastructure-live-v1/dev/main.tf` must be supplied securely:

- `atlas_org_id`
- `grafana_cloud_access_policy_token`
- `grafana_otlp_token`
- `kashier_secret_key`
- `kashier_api_key`
- `kashier_merchant_id`

For CI, the workflows read these from GitHub Actions Secrets. Do not replace them with literal values in workflow files.

## AWS bootstrap requirements

Apply `infrastructure-live-v1/bootstrap` once using an administrator identity that is separate from the normal application workflows:

```bash
cd infrastructure-live-v1/bootstrap
terraform init
terraform apply -var='github_repo=OWNER/REPOSITORY'
```

Replace `OWNER/REPOSITORY` with the exact GitHub repository name. The bootstrap stack creates:

- The GitHub Actions OIDC provider
- `gha-terraform` for Terraform apply, destroy, and DNS reporting
- `gha-packer` for AMI build and verification
- `gha-backend-deploy` for backend artifact delivery and CodeDeploy
- `gha-frontend-release` for frontend release and rollback
- The encrypted and versioned Terraform state bucket

The bootstrap output provides the role ARNs. GitHub Actions also requires the repository variable:

- `AWS_ACCOUNT_ID`
- `AWS_REGION` — set to `eu-central-1`

The role trust policy must match the actual repository owner and name.

## GitHub Actions Secrets

Configure these repository or environment secrets before running infrastructure workflows:

| Secret | Used for |
|---|---|
| `MONGODB_ATLAS_PUBLIC_API_KEY` | MongoDB Atlas Terraform provider |
| `MONGODB_ATLAS_PRIVATE_API_KEY` | MongoDB Atlas Terraform provider |
| `MONGODB_ATLAS_ORG_ID` | MongoDB Atlas organization |
| `GRAFANA_CLOUD_API_KEY` | Grafana Cloud provider access |
| `GRAFANA_OTLP_TOKEN` | Grafana OTLP export |
| `KASHIER_SECRET_KEY` | Kashier payment integration |
| `KASHIER_API_KEY` | Kashier payment signing and API access |
| `KASHIER_MERCHANT_ID` | Kashier merchant account |

The application runtime secrets are written to AWS Secrets Manager by Terraform and fetched by the CodeDeploy `AfterInstall` hook. They should not be copied into GitHub workflow files.

## DNS prerequisites

You must control the domain used by `domain_name`. The `dns_records.yml` workflow only reports the required records; it does not modify your DNS provider.

Create or update these records manually:

1. The ACM-generated validation CNAME, using the name and target shown in the Terraform apply summary.
2. The website CNAME pointing your domain to the CloudFront distribution domain.

Use DNS-only mode while validating ACM and pointing the website at CloudFront.

## Local environment

For local development, create a root `.env` with values appropriate for your machine:

```dotenv
PORT=5000
MONGO_URI=your_mongodb_connection_string
REDIS_MODE=standalone
REDIS_HOST=localhost
REDIS_PORT=6379
ACCESS_TOKEN_SECRET=generate_a_long_random_value
REFRESH_TOKEN_SECRET=generate_a_different_long_random_value
KASHIER_SECRET_KEY=your_kashier_secret_key
KASHIER_API_KEY=your_kashier_api_key
KASHIER_MERCHANT_ID=your_kashier_merchant_id
KASHIER_MODE=test
KASHIER_CURRENCY=EGP
AWS_REGION=eu-central-1
S3_BUCKET_NAME=your_s3_bucket_name
CLIENT_URL=http://localhost:5173
CLOUDFRONT_URL=https://your_cdn_domain
```

Use test payment credentials for local development. The production deployment obtains its runtime values from AWS Secrets Manager instead.

## Recommended setup order

Complete the following steps in order. The infrastructure and deployment workflows are manual; starting one workflow does not automatically start the next one.

### 1. Install the local tools

Install the tools listed in [Required local tools](#required-local-tools). Confirm the main CLI versions:

```bash
node --version
npm --version
terraform version
aws --version
packer version
```

### 2. Create the required accounts and permissions

Create or obtain access to:

- An AWS account with permission to run the bootstrap stack.
- A GitHub repository where Actions and repository variables/secrets can be configured.
- A MongoDB Atlas organization and API keys.
- A Grafana Cloud stack, CloudWatch integration, OTLP credentials, and PrivateLink service.
- A Kashier test account for development or a live merchant account for production.
- A DNS provider account with permission to manage the selected domain.

Use the exact GitHub repository owner and name when configuring the bootstrap stack because the GitHub OIDC trust policy is restricted to that repository.

### 3. Configure Terraform variables and GitHub secrets

Edit:

```text
infrastructure-live-v1/dev/dev.tfvars
```

Replace the example domain and Grafana values with values from your own accounts. Do not put sensitive API keys or tokens in this file if it will be committed.

In the GitHub repository, open **Settings → Secrets and variables → Actions** and add:

- Repository variable: `AWS_ACCOUNT_ID`
- Repository variable: `AWS_REGION` with value `eu-central-1`
- Secrets listed in [GitHub Actions Secrets](#github-actions-secrets)

The workflows read these values from `${{ vars.* }}` and `${{ secrets.* }}`. The repository variable `AWS_ACCOUNT_ID` is used to construct the OIDC role ARNs and Terraform state bucket name.

### 4. Apply the AWS bootstrap stack

The bootstrap Terraform code is located at:

```text
infrastructure-live-v1/bootstrap
```

This is the first Terraform stack to apply. Run it locally with an AWS administrator profile:

```bash
cd infrastructure-live-v1/bootstrap
aws configure --profile <your-admin-profile>
aws sts get-caller-identity --profile <your-admin-profile>
terraform init
terraform apply \
  -var='github_repo=OWNER/REPOSITORY' \
  -var='project=mern' \
  -var='env=dev'
```

If you use a named profile, export it before running Terraform:

```bash
export AWS_PROFILE=<your-admin-profile>
```

The bootstrap stack creates the GitHub Actions OIDC provider, the four workflow IAM roles, and the encrypted/versioned Terraform state bucket. It must be applied before any GitHub Actions workflow that assumes `gha-terraform`, `gha-packer`, `gha-backend-deploy`, or `gha-frontend-release`.

After the apply completes, confirm that the output role ARNs exist and that the state bucket name matches the bucket used by the workflows:

```bash
terraform output
aws iam get-role --role-name gha-terraform
aws iam get-role --role-name gha-packer
aws iam get-role --role-name gha-backend-deploy
aws iam get-role --role-name gha-frontend-release
```

### 5. Build and verify an AMI

In GitHub, open **Actions → Build AMI**. This workflow is defined at:

```text
.github/workflows/ami.yml
```

Choose **Run workflow**, provide a release version such as `v1.0.0` or a commit identifier, and start it. The workflow runs three dependent jobs:

1. **Validate Packer** checks the version, initializes Packer, checks formatting, and validates `infrastructure-live-v1/packer`.
2. **Build AMI** assumes `gha-packer`, runs Packer in `eu-central-1`, and publishes the AMI ID.
3. **Verify AMI** waits for the AMI to become available and displays its architecture and block-device mappings.

Wait for all three jobs to pass before applying the application infrastructure. The AMI workflow does not automatically run Terraform apply.

### 6. Apply the development infrastructure

In GitHub, open **Actions → Terraform apply** and choose **Run workflow**. This workflow is defined at:

```text
.github/workflows/infrastructure_apply.yml
```

The workflow uses:

```text
Working directory: infrastructure-live-v1/dev
Variable file:     infrastructure-live-v1/dev/dev.tfvars
Region:            eu-central-1
Terraform version: 1.11.0
```

It assumes `gha-terraform`, initializes the encrypted S3 backend, formats and validates Terraform, runs TFLint and Checkov, creates a saved plan, and applies that plan. The ACM watcher may publish a DNS validation CNAME to the job summary while the apply is running.

If the workflow waits for ACM validation, leave the apply running and continue to the DNS step. Do not expose the secret values printed or supplied to the workflow.

### 7. Add the DNS records reported by the workflow

After Terraform creates the certificate and CloudFront distribution, open the **Terraform apply** job summary or run:

```text
.github/workflows/dns_records.yml
```

To run the reporting workflow, open **Actions → DNS records**, choose **Run workflow**, select `dev`, and start it. The workflow assumes `gha-terraform`, reads the deployment configuration from SSM, looks up the ACM certificate in `us-east-1`, and prints:

1. The ACM validation CNAME.
2. The website CNAME pointing to the CloudFront distribution.

Create both records manually in your DNS provider with **DNS only** enabled. This workflow reports records; it does not modify Cloudflare or any other DNS provider.

After the ACM record is created, wait for the certificate to become `ISSUED`. Then create the website CNAME and test the public domain over HTTPS.

### 8. Deploy the backend

Open **Actions → Backend - Build and Deploy**, choose **Run workflow**, select `dev`, and start it. The workflow is:

```text
.github/workflows/build_ship_deploy_backend.yml
```

It assumes `gha-backend-deploy`, reads deployment values from SSM, packages the backend with production dependencies, uploads a versioned artifact to S3, starts CodeDeploy, and waits for deployment success. CodeDeploy then runs the lifecycle scripts in:

```text
scripts/
appspec.yml
```

The validation hook checks the backend readiness endpoint before the deployment is considered successful.

### 9. Release the frontend

Open **Actions → Frontend - Build and Release**, choose **Run workflow**, select `dev`, and start it. The workflow is:

```text
.github/workflows/build_ship_deploy_frontend.yml
```

It builds `frontend/`, stamps the selected version into `version.txt`, archives the build, uploads an immutable version prefix to the frontend bucket, updates the CloudFront KeyValueStore pointer, and verifies that the public site serves the requested version.

Run this after the backend is available and the public DNS/HTTPS path is working.

### 10. Use rollback only when required

For a frontend rollback, open **Actions → Frontend - Rollback** and enter the full release version or commit SHA to restore. The workflow is:

```text
.github/workflows/rollback_frontend.yml
```

It checks whether the version exists in the frontend bucket. If it does not, the workflow restores the archived frontend bundle from the artifacts bucket, then switches the CloudFront version pointer and verifies `version.txt`. It does not rebuild the frontend.

Backend deployment rollback is handled by CodeDeploy when a deployment fails. Review the CodeDeploy deployment status before manually starting another backend deployment.

### 11. Destroy the development environment only intentionally

The destructive workflow is:

```text
.github/workflows/infrastructure_destroy.yml
```

Open **Actions → Terraform destroy**, choose **Run workflow**, enter the exact confirmation value `destroy-dev`, and decide whether to enable the `delete_amis` option.

- With `delete_amis` disabled, Terraform destroys the development infrastructure but leaves Packer AMIs and snapshots.
- With `delete_amis` enabled, the workflow also deregisters project-tagged AMIs and deletes their associated EBS snapshots.

The workflow removes the application bucket policy before destruction so Terraform can empty the bucket, lists remaining resources tagged `Project=mern`, and reminds you to remove the website DNS CNAME before a future rebuild. It does not automatically delete DNS records.

For the detailed engineering explanation, see the [published project case study](https://abdullahsameh.tech/blog/mern).
