# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a production-grade AWS ECS on EC2 demonstration project using Terraform. It deploys a containerized Next.js application with complete AWS infrastructure including VPC, ALB, CloudFront, Route 53, and auto-scaling capabilities.

## Essential Commands

### Initial Setup
```bash
make bootstrap              # Create .env config file from .env.example
# Edit .env to configure: DOMAIN_NAME, TLD_ZONE_ID, AWS credentials, PUBLIC_EC2_KEY
```

### Deployment
```bash
make deploy                 # Full deployment: Terraform apply + Docker build/push
                           # Generates random hash for versioning (simulates CI/CD)
                           # Takes 5-10 minutes on first run
```

### Destruction
```bash
make destroy               # Clean destroy: stops tasks, deregisters, then destroys
make destroy.clean         # Force destroy without task cleanup (use if DRAINING issues occur)
```

### Terraform Operations
```bash
cd infra && terraform init
cd infra && terraform plan -var hash=<HASH>
cd infra && terraform apply -var hash=<HASH>
```

### Application Development
```bash
cd app/src && npm install
cd app/src && npm run dev         # Local development server
cd app/src && npm run build       # Production build
cd app/src && npm run lint        # Lint checks
```

### Docker Operations
```bash
docker build --platform linux/amd64 -t nexgeneerz/scenario-aws-ecs-ec2 app/
# ECR login and push handled by deploy.sh script
```

## Architecture Overview

### Infrastructure Layout (infra/)

**Network Layer:**
- `vpc.tf` - VPC with configurable CIDR (default: 10.1.0.0/16)
- `subnets.tf` - Public/private subnets across 2 AZs
- `security_groups.tf` - Security groups for ALB, ECS instances, bastion

**Compute Layer:**
- `ecs_cluster.tf` - ECS cluster definition
- `ecs_task_definition.tf` - Task definition with hash-based versioning
- `ecs_service.tf` - ECS service with placement strategies (spread by AZ, binpack by memory)
- `launch_template.tf` - EC2 launch template with user_data.sh for ECS agent config
- `autoscaling_group.tf` - ASG for EC2 instances (min: 2, max: 6)
- `capacity_providers.tf` - ECS Capacity Provider linked to ASG for automatic scaling

**Load Balancing & DNS:**
- `alb.tf` - Application Load Balancer with target groups
- `cloudfront.tf` - CloudFront distribution with custom origin header for security
- `route53.tf` - DNS records pointing to CloudFront
- `certificates.tf` - ACM certificates for HTTPS

**Scaling & Monitoring:**
- `ecs_service_autoscaling.tf` - Target tracking policies (CPU: 70%, Memory: 80%)
- `cloudwatch.tf` - Log groups with 7-day retention

**IAM & Access:**
- `ecs_iam.tf` - Task execution role, task role, service role
- `bastion_host.tf` - Bastion host for SSH access to private instances
- `key_pair.tf` - SSH key pair management

**Container Registry:**
- `ecr.tf` - ECR repository with force_delete enabled

**Configuration:**
- `vars.tf` - All Terraform variables with defaults
- `providers.tf` - AWS provider configuration
- `versions.tf` - Terraform version constraints

### Application Structure (app/)

**Next.js Application:**
- `src/` - Next.js 13.3 application with TypeScript and Tailwind CSS
- `Dockerfile` - Multi-stage production build (deps → builder → runner)
- `docker-compose.yml` - Local development setup
- Container runs on port 3000, exposed with dynamic host port mapping (hostPort: 0)

### Deployment Scripts

**deploy.sh:**
1. Generates random hash for version tagging
2. Runs terraform init/plan/apply with hash variable
3. Authenticates with ECR
4. Builds Docker image for linux/amd64 platform
5. Tags and pushes both :latest and :<HASH> versions to ECR

**destroy.sh:**
1. Sets ECS service desired count to 0
2. Waits for tasks to stop
3. Deregisters task definition
4. Checks service is not DRAINING before deletion
5. Deletes ECS service
6. Runs terraform destroy

## Key Architecture Patterns

### Hash-Based Versioning
Every deployment generates a unique hash (via `openssl rand -hex 12`) used to:
- Tag Docker images in ECR (both :latest and :<HASH>)
- Version ECS task definitions
- Simulate CI/CD versioning system

### Rolling Updates
- ECS service configured with 50% minimum healthy percent and 100% maximum percent
- Allows zero-downtime deployments
- Task-by-task replacement during updates

### Capacity Provider Strategy
- ECS Capacity Provider manages ASG scaling automatically
- Target capacity: 100% (uses all available container instance resources)
- Binpack placement strategy optimizes resource utilization

### Security Architecture
- CloudFront → ALB communication secured via custom origin header (Demo123)
- Bastion host required for SSH access to ECS instances
- ECS instances in private subnets
- ALB in public subnets

### Task Placement
1. Spread tasks across availability zones for high availability
2. Binpack by memory within each AZ for efficiency

## Configuration Requirements

Required .env variables:
- `DOMAIN_NAME` - Full subdomain (e.g., service.example.com)
- `TLD_ZONE_ID` - Route 53 Hosted Zone ID for top-level domain
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` - AWS credentials
- `PUBLIC_EC2_KEY` - SSH public key for EC2 instance access
- `REGION` - AWS region (default: ap-northeast-1)

## Known Behaviors

### Temporary Image Pull Failures
Between task deployment and Docker image push (typically a few minutes), ECS will show image pull errors. This is expected and resolves automatically once the image is pushed to ECR.

### DRAINING Status Prevention
The destroy.sh script explicitly handles task deregistration and service deletion to prevent the service from entering DRAINING status, which can block Terraform destroy operations.

### Platform Requirement
Docker images must be built for linux/amd64 platform (not arm64) to run on ECS EC2 instances.
