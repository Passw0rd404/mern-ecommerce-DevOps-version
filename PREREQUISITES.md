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

1. Install the local tools.
2. Create the AWS, GitHub, MongoDB Atlas, Grafana Cloud, Kashier, and DNS accounts or permissions.
3. Configure `dev.tfvars` and GitHub Actions secrets.
4. Apply the bootstrap Terraform stack.
5. Build and verify an AMI with the AMI workflow.
6. Apply the development infrastructure with `infrastructure_apply.yml`.
7. Add the DNS records reported by the workflow.
8. Deploy the backend and release the frontend.
9. Use the rollback workflows and destroy workflow only when intentionally required.

For the detailed engineering explanation, see the [published project case study](https://abdullahsameh.tech/blog/mern).
