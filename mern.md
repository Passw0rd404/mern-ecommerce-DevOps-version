---
title: "Building and Deploying a Three-Tier MERN E-Commerce Platform on AWS"
date: "2026-10-13"
summary: "A case study of the architecture, infrastructure, security, deployment pipeline, and operational lessons behind an AWS-hosted MERN e-commerce application."
cover: "/images/blog/mern/mern-aws.png"
tags: ["MERN", "AWS", "Terraform", "DevOps", "CI/CD"]
published: true
---

## 1. Project overview

This project is a production-oriented three-tier MERN e-commerce platform deployed on AWS. The main engineering work is the infrastructure around the application: private networking, managed services, reproducible Terraform, immutable releases, OIDC-based CI/CD, and centralized observability.

The application provides the business workload—storefront, admin dashboard, authentication, products, carts, coupons, payments, and analytics—while the platform is designed to give that workload a secure and repeatable operating environment.

I designed and implemented the application structure, Terraform modules, AWS networking, Packer image build, CodeDeploy lifecycle, GitHub Actions workflows, authentication, payment integration, product image storage, caching, and observability integration.

The repository is available on [GitHub](https://github.com/Passw0rd404/mern-ecommerce-DevOps-version). The project also includes a [video walkthrough](https://youtu.be/sX57TLIPNx8).

## 2. Architecture

![Three-tier AWS architecture and request flow](/images/blog/mern/3-tier.png)

CloudFront is the single public entry point. A DNS name is associated with the distribution, and an ACM certificate enables HTTPS for that custom domain. The certificate is created in `us-east-1`, as required by CloudFront, while the application infrastructure runs in `eu-central-1`.

The request path is:

1. A user reaches the application through CloudFront and HTTPS.
2. CloudFront serves the React frontend from a private S3 bucket.
3. Requests under `/api/*` are forwarded through a CloudFront VPC origin to an internal Network Load Balancer.
4. The load balancer sends traffic to backend EC2 instances in private subnets.
5. The API reads and writes application data in MongoDB Atlas through an AWS PrivateLink endpoint.
6. Redis/Valkey provides caching and refresh-token storage inside the VPC.
7. Product images are uploaded by the backend to a private S3 bucket and delivered through CloudFront.

The frontend and backend are therefore separated at the delivery layer, while the backend and data services remain inside private network boundaries. CloudFront also applies HTTPS redirection, caching policies, and security headers; API responses are not cached because authentication cookies must reach the backend.

## 3. AWS infrastructure and networking

The infrastructure is organized around a VPC in `eu-central-1` with public and private subnets across two pinned Availability Zones: `euc1-az2` and `euc1-az3`. These exact zone IDs are used because the Grafana Cloud PrivateLink service supports those physical zones, and AWS Availability Zone names can map differently between accounts. Pinning IDs keeps the deployment aligned with the endpoint service instead of relying on account-specific names such as `eu-central-1a`.

`eu-central-1` is used consistently for the application, EC2 fleet, Valkey, MongoDB Atlas cluster, VPC endpoints, and primary observability metrics because it is the selected deployment region and the region passed to the Atlas and AWS modules. CloudFront is the deliberate exception: its ACM certificate must be in `us-east-1`, and CloudFront metrics are read there by Grafana.

Public subnets host the NAT gateways and internet gateway route. Application instances, Valkey, and interface endpoints use private subnets.

The main traffic boundaries are:

- CloudFront is the public entry point.
- The backend NLB is internal and is reached through a CloudFront VPC origin.
- Backend security groups allow application traffic from the NLB rather than from the public internet.
- Valkey accepts connections from the application security group on port `6379`.
- MongoDB Atlas is connected through a private interface endpoint.
- S3 uses a VPC gateway endpoint so application traffic can reach S3 without traversing the public internet.

The endpoint layout is intentional:

- The **S3 gateway endpoint** keeps S3 traffic on the AWS network and avoids NAT for S3 access.
- The **MongoDB Atlas interface endpoint** uses Atlas PrivateLink across the private subnets. Atlas supplies the private connection information, so AWS private DNS is disabled and the application uses the matching private SRV connection string.
- The **Grafana Cloud interface endpoint** provides private OTLP ingestion from the EC2 instances. Its supported zones are the reason the VPC uses `euc1-az2` and `euc1-az3`.

PrivateLink is safer than sending database or telemetry traffic through public internet paths because the traffic stays on private AWS networking, access is limited by endpoint security groups, and the services are not exposed as public application endpoints.

The design favors isolation and predictable traffic flow over exposing individual services. NAT gateways provide private instances with outbound access, while security groups and bucket policies limit which components can communicate or write data.

## 4. Infrastructure as Code

Terraform is organized into reusable modules under [`infrastructure-live-v1/modules`](https://github.com/Passw0rd404/mern-ecommerce-DevOps-version/tree/main/infrastructure-live-v1/modules), with the development composition in [`infrastructure-live-v1/dev`](https://github.com/Passw0rd404/mern-ecommerce-DevOps-version/tree/main/infrastructure-live-v1/dev).

The modules separate concerns such as:

- VPC networking and VPC endpoints
- EC2, Auto Scaling, security groups, and the internal NLB
- CloudFront, S3 origins, the CloudFront Function, and the key-value store
- MongoDB Atlas PrivateLink
- Valkey/ElastiCache
- ACM certificates and DNS support
- Secrets Manager
- CodeDeploy
- Grafana Cloud and CloudWatch access

Terraform state is stored in an encrypted S3 backend with lockfile-based state locking. The deployment configuration needed by GitHub Actions is published through the deploy-config module and loaded by a reusable GitHub Action.

One important implementation decision is that the AMI is environment-neutral. The launch template provides the environment-specific Secrets Manager name at instance launch, while the AMI contains only shared operating-system, Node.js, PM2, CodeDeploy, and Alloy tooling.

The `bootstrap` stack is applied first. It creates the encrypted, versioned Terraform state bucket and the GitHub OIDC provider with the roles used by the workflows:

- `gha-terraform` — applies and destroys the infrastructure; it currently uses `AdministratorAccess` because the stack creates and removes IAM, VPC, CloudFront, ElastiCache, and other cross-service resources.
- `gha-packer` — builds and verifies AMIs with EC2 permissions.
- `gha-backend-deploy` — uploads backend bundles, starts and monitors CodeDeploy deployments, and reads deployment configuration from SSM.
- `gha-frontend-release` — uploads versioned frontend files and archives, reads deployment configuration, and updates the CloudFront key-value store used to activate or roll back a release.

The role trust policies restrict tokens by GitHub repository, branch, and release-tag subject. GitHub Actions receives short-lived AWS credentials through `AssumeRoleWithWebIdentity`; no long-lived AWS access key is stored in the repository.

## 5. Application deployment and CI/CD

![Application delivery CI/CD: code quality, backend deployment, frontend release, and rollback](/images/blog/mern/cicd-1.png)

![Infrastructure CI/CD: OIDC, Terraform, Packer, DNS reporting, and lifecycle automation](/images/blog/mern/cicd-2.png)

The pipeline is split into infrastructure, image, backend, frontend, rollback, and quality workflows:

1. **AMI workflow:** validates the Packer template, builds an Amazon Linux image, and waits until the AMI is available.
2. **Infrastructure apply:** formats and validates Terraform, runs TFLint and Checkov, creates a plan, and applies the approved plan.
3. **Backend deployment:** installs production dependencies in an isolated deployment directory, creates a versioned tarball, uploads it to a versioned S3 artifact, and starts CodeDeploy.
4. **Frontend release:** builds the React application, writes a release version to `version.txt`, archives the build, uploads it under an immutable version prefix, and switches the active version.
5. **Frontend rollback:** accepts the full Git commit SHA of the version to restore, validates that input, restores the version from the artifact archive if necessary, and changes the active CloudFront key-value-store pointer.
6. **Code quality:** runs frontend linting, production builds, dependency audits, Semgrep, and OpenSSF Scorecard checks.
7. **Infrastructure destroy:** can remove the `dev` environment only after the operator enters `destroy-dev`. It can optionally delete Packer AMIs and their snapshots through the `delete_amis` input, then lists remaining resources tagged `Project=mern`.

GitHub Actions authenticates to AWS through OIDC roles rather than storing long-lived AWS access keys in the repository. Deployment configuration is loaded from AWS Systems Manager Parameter Store, while application secrets are stored in AWS Secrets Manager and fetched by the EC2 deployment lifecycle.

The frontend release strategy separates uploading a build from activating it. Each build remains available under its own version prefix, and the CloudFront Function reads the active version from a CloudFront key-value store. This makes switching versions and rolling back possible without rebuilding the frontend. Backend deployments use CodeDeploy traffic control and automatic rollback on deployment failure.

## 6. Security

The security design focuses on reducing public exposure and limiting credentials:

- Frontend and application S3 buckets block public access and are read through CloudFront Origin Access Control.
- The backend NLB is internal; the application security group accepts the application port only from the NLB security group.
- EC2 metadata access requires IMDSv2 with a hop limit of one.
- EC2 uses an instance IAM role for Secrets Manager, S3 product-image operations, CodeDeploy artifacts, and Systems Manager instead of embedding AWS credentials.
- Backend secrets and generated JWT signing keys are stored in Secrets Manager.
- Access tokens are short-lived, while refresh tokens are stored server-side in Redis and can be invalidated.
- Authentication cookies are HTTP-only, use `SameSite=Strict`, and use the `Secure` flag in production.
- Payment redirect and webhook payloads are verified with Kashier signatures before an order is finalized.
- MongoDB Atlas and Valkey are encrypted in transit; Valkey also uses encryption at rest and an authentication token.
- CloudFront uses HTTPS redirection and TLS 1.2 or newer when a custom ACM certificate is configured.
- The S3 gateway endpoint and the MongoDB Atlas and Grafana Cloud interface endpoints keep service traffic on private AWS paths instead of routing it through the public internet. Endpoint security groups allow access only from the VPC.
- MongoDB Atlas PrivateLink gives the application a private database path, while Atlas supplies its own managed monitoring, backups, and database dashboards.

These controls do not eliminate every operational risk, but they establish clear network, identity, storage, and payment boundaries without publishing credentials in the repository.

## 7. Monitoring and observability

Grafana Cloud is the central observability platform for the AWS and application layers. The backend is instrumented with OpenTelemetry, and Grafana Alloy runs on each EC2 instance. Alloy receives application OTLP telemetry locally, collects host metrics through the Unix exporter, batches the data, and sends metrics, logs, and traces to Grafana Cloud through the private Grafana Cloud endpoint.

Terraform also connects Grafana Cloud to AWS CloudWatch through a cross-account IAM role protected by an external ID. Grafana Cloud reads infrastructure metrics directly from CloudWatch, while Alloy supplies host and application telemetry. MongoDB Atlas remains the source of truth for database-specific monitoring and dashboards because its managed MongoDB monitoring provides database signals that would be expensive and incomplete to recreate from scratch.

The configured CloudWatch scrape jobs cover signals such as:

- EC2 CPU utilization and status-check failures
- Auto Scaling desired and in-service capacity
- Network Load Balancer active flows and healthy hosts
- Valkey CPU utilization and connections
- NAT gateway traffic and port-allocation errors
- S3 size and object counts
- CloudFront requests, cache hit rate, and 5xx error rate

The application also exposes readiness checks used by the CodeDeploy validation hook. This gives the deployment process a concrete signal for whether a newly started backend is ready to receive traffic.

## 8. Reliability and availability

The application fleet is distributed across two private subnets, with an Auto Scaling group per Availability Zone. Each group has a minimum of one and a maximum of three `t3.small` instances by default, uses load balancer health checks, performs rolling instance refreshes, and targets 60% average CPU utilization.

Valkey runs in cluster mode with one shard per private subnet, one replica per shard by default, automatic failover, Multi-AZ enabled, encryption in transit and at rest, snapshots, and optional Application Auto Scaling for replicas. The current default `cache.t4g.small` is suitable for development, but **do not enable replica autoscaling with `cache.t4g.small`**: AWS rejected that combination in this configuration. Use a larger node type such as `cache.m7g` or `cache.r7g` for real production load and autoscaling.

MongoDB Atlas is a managed three-node replica set with backups, compute and disk autoscaling, TLS 1.2, and a private endpoint. AWS-managed services such as CloudFront, the load balancer, and the managed cache/database components provide their own service-level availability guarantees; the application design adds multi-AZ placement, health checks, autoscaling, and deployment recovery around them.

CodeDeploy can automatically roll back a failed backend deployment, and the frontend rollback workflow accepts a chosen commit SHA and switches the active immutable frontend version.

The infrastructure still has operational dependencies, including AWS, MongoDB Atlas, the payment provider, and Grafana Cloud. Availability is designed through redundancy and managed services, but an SLA or disaster-recovery recovery time should be established and tested separately for a specific production workload.

## 9. Cost analysis

There is no single fixed monthly cost for this project. The cost depends on how the operator configures and uses it, including:

- EC2 instances and EBS volumes
- NAT gateways and data processing
- Network Load Balancer hours and data processing
- MongoDB Atlas and Valkey capacity
- CloudFront requests and data transfer
- S3 storage, requests, and versioned deployment artifacts
- Grafana Cloud usage
- Whether optional Valkey replica autoscaling is enabled
- The MongoDB Atlas cluster tier and autoscaling ceiling
- The minimum and maximum EC2 instance counts in each Auto Scaling group
- Traffic, request volume, storage growth, and data transfer

A proper estimate should state the `eu-central-1` region, EC2 and cache sizes, Atlas tier, number of running instances, expected request volume, storage growth, and data-transfer assumptions. Development settings such as `force_destroy`, `cache.t4g.small`, and one minimum instance per AZ should not be treated as production cost guidance.

## 10. Challenges and solutions

### Keeping the backend private while serving a public application

**Problem:** The storefront needed a public entry point, but the application instances should not be directly exposed.

**Investigation:** The infrastructure separates CloudFront, the internal NLB, and the private EC2 subnets. Security-group rules show that the application port is accepted from the NLB rather than from arbitrary internet addresses.

**Solution:** CloudFront handles public HTTPS traffic and uses a VPC origin to reach the internal NLB. The NLB then forwards traffic to the private application fleet.

**Verification:** The Terraform configuration makes the NLB internal and scopes application ingress to the NLB security group. Deployment health checks target the application through the load-balancing path.

### Making frontend releases reversible

**Problem:** Replacing one live frontend directory makes rollback dependent on rebuilding and redeploying.

**Investigation:** The release workflow archives each build and uploads it to a version-specific S3 prefix. A CloudFront Function reads the active version from a key-value store.

**Solution:** Uploads are immutable, and activation is a separate pointer switch. The rollback workflow restores the requested version from the artifact archive when needed.

**Verification:** The release writes `version.txt`, and the switch script waits until the site serves the requested version before succeeding.

### Handling duplicate payment completion events

**Problem:** A successful payment can be reported through both the browser redirect and the provider webhook.

**Investigation:** Both paths verify signatures, locate the checkout record, and call the same finalization function. The order schema uses the Kashier reference as a unique value.

**Solution:** Finalization checks the paid amount and treats a duplicate-key result as an already-created order, making the operation safe to repeat.

**Verification:** The webhook returns a non-2xx response on processing errors so the provider can retry, while duplicate successful notifications resolve to the existing order.

### Creating one useful monitoring strategy across multiple platforms

**Problem:** The system spans AWS infrastructure, EC2 hosts, application telemetry, Grafana Cloud, and MongoDB Atlas. Building a custom database dashboard from raw MongoDB data would duplicate work and risk missing database-specific signals.

**Investigation:** AWS exposes infrastructure metrics through CloudWatch, while Alloy can collect host and application telemetry from each EC2 instance. MongoDB Atlas already provides managed MongoDB monitoring and dashboards designed for its replica sets, storage, performance, and database health.

**Solution:** Grafana Cloud is used as the central dashboard for AWS, host, and application signals. Atlas remains the specialized monitoring system for MongoDB, and the private Grafana Cloud endpoint keeps Alloy telemetry on the AWS network.

**Verification:** Terraform configures the Grafana Cloud AWS account, CloudWatch scrape jobs, and the cross-account role. The AMI installs Alloy, and the launch-time configuration supplies the Grafana endpoint and credentials without baking secrets into the image.

## 11. Results and lessons learned

The completed project demonstrates:

- A working MERN shopping flow with authentication, products, carts, coupons, payments, and an admin area
- A modular Terraform design for AWS networking and application infrastructure
- Private application and data paths behind CloudFront and an internal load balancer
- Versioned backend artifacts and reversible frontend releases
- OIDC-based GitHub Actions access to AWS
- Secrets Manager, IAM roles, encrypted services, signed payment callbacks, and protected cookies
- OpenTelemetry and Grafana-based application and infrastructure observability
- A production-grade infrastructure foundation that can be adapted for a high-traffic e-commerce workload
- Integration across AWS, MongoDB Atlas, Grafana Cloud, Kashier, GitHub Actions, and CodeDeploy

The most important lesson was that infrastructure is a systems problem. Designing a production-grade platform requires understanding how networking, managed services, IAM, deployment tooling, observability platforms, and application behavior fit together. The project strengthened my ability to integrate different platforms and clouds, reason structurally about a problem, and build an effective solution instead of optimizing one component in isolation.

Planned improvements should be measured and explicit: add repeatable disaster-recovery tests, document real cost data, expand automated integration tests, and define production availability targets before presenting the development environment as production-ready.
