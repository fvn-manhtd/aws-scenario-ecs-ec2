# AWS Setup Guidelines

This guide walks you through obtaining all required configuration values for the `.env` file needed to deploy this ECS infrastructure.

## Prerequisites

- An AWS account with billing enabled
- AWS CLI installed (optional but recommended)
- Terminal access for generating SSH keys

---

## 1. Domain Name Setup

### Option A: Use an Existing Domain

If you already own a domain (e.g., `example.com`), you need to:

1. **Transfer DNS management to Route 53** (if not already there):
   - Go to AWS Console → Route 53 → Hosted Zones
   - Click "Create Hosted Zone"
   - Enter your domain name (e.g., `example.com`)
   - Note the 4 nameservers provided by AWS
   - Update your domain registrar's nameserver settings to use AWS nameservers

2. **Choose a subdomain for this service**:
   - Example: `myapp.example.com`
   - This will be your `DOMAIN_NAME` value

### Option B: Register a New Domain via Route 53

1. Go to AWS Console → Route 53 → Registered Domains
2. Click "Register Domain"
3. Search for an available domain and complete the purchase
4. AWS automatically creates a hosted zone for you
5. Choose a subdomain for this service (e.g., `myapp.yourdomain.com`)

**Result**:
```
DOMAIN_NAME=myapp.example.com
```

---

## 2. Get Route 53 Hosted Zone ID

Once your domain is managed by Route 53:

### Via AWS Console:

1. Go to AWS Console → Route 53 → Hosted Zones
2. Find your domain (e.g., `example.com`)
3. Click on the domain name
4. Copy the "Hosted Zone ID" from the top right
   - Format: `Z1234567890ABC`

### Via AWS CLI:

```bash
aws route53 list-hosted-zones --query "HostedZones[?Name=='example.com.'].Id" --output text
```

Note: The CLI output may include `/hostedzone/` prefix - you can use either format, but just the ID is cleaner.

**Result**:
```
TLD_ZONE_ID=Z1234567890ABC
```

---

## 3. Create AWS Access Keys

### Step 1: Create an IAM User (Recommended for Non-Root Access)

1. Go to AWS Console → IAM → Users
2. Click "Create user"
3. Enter username (e.g., `ecs-deployment-user`)
4. Click "Next"
5. Attach policies directly:
   - `AmazonEC2FullAccess`
   - `AmazonECS_FullAccess`
   - `AmazonVPCFullAccess`
   - `AmazonRoute53FullAccess`
   - `CloudFrontFullAccess`
   - `AmazonEC2ContainerRegistryFullAccess`
   - `IAMFullAccess` (for creating roles)
   - Or create a custom policy with necessary permissions
6. Click "Create user"

### Step 2: Generate Access Keys

1. Click on the newly created user
2. Go to "Security credentials" tab
3. Scroll down to "Access keys"
4. Click "Create access key"
5. Select use case: "Command Line Interface (CLI)"
6. Check the confirmation checkbox
7. Click "Next" and optionally add a description
8. Click "Create access key"
9. **IMPORTANT**: Copy both the Access Key ID and Secret Access Key immediately
   - You cannot retrieve the secret key again after closing this dialog
   - Download the .csv file as backup

### Alternative: Use Root Account Keys (Not Recommended)

1. Go to AWS Console → Account menu (top right) → Security Credentials
2. Expand "Access keys"
3. Click "Create access key"
4. Acknowledge the warning and create
5. Download the credentials

**Result**:
```
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

---

## 4. Generate SSH Key Pair

This key pair allows you to SSH into the bastion host and ECS EC2 instances.

### Generate New Key Pair:

#### On Linux/macOS:

```bash
# Generate a new SSH key pair
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ~/.ssh/aws-ecs-key

# Display the public key
cat ~/.ssh/aws-ecs-key.pub
```

#### On Windows (PowerShell):

```powershell
# Generate a new SSH key pair
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f $env:USERPROFILE\.ssh\aws-ecs-key

# Display the public key
Get-Content $env:USERPROFILE\.ssh\aws-ecs-key.pub
```

### Use Existing Key Pair:

If you already have an SSH key:

```bash
# Linux/macOS
cat ~/.ssh/id_rsa.pub

# Windows PowerShell
Get-Content $env:USERPROFILE\.ssh\id_rsa.pub
```

The public key should look like:
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... your_email@example.com
```

**Result**:
```
PUBLIC_EC2_KEY=ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... your_email@example.com
```

---

## 5. Choose AWS Region (Optional)

The default region is `eu-central-1` (Frankfurt). You can override this in `.env`:

```
REGION=us-east-1
```

Common regions:
- `us-east-1` - N. Virginia
- `us-west-2` - Oregon
- `eu-central-1` - Frankfurt
- `eu-west-1` - Ireland
- `ap-southeast-1` - Singapore
- `ap-northeast-1` - Japan

---

## 6. Create Your .env File

1. Run the bootstrap command:
   ```bash
   make bootstrap
   ```

2. Edit the generated `.env` file:
   ```bash
   nano .env
   # or
   vim .env
   # or use any text editor
   ```

3. Replace all placeholder values with your actual values:
   ```bash
   DOMAIN_NAME=myapp.example.com
   TLD_ZONE_ID=Z1234567890ABC
   AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
   AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
   PUBLIC_EC2_KEY=ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... your_email@example.com
   REGION=eu-central-1
   ```

4. Save the file

---

## 7. Verify Configuration

### Test AWS CLI Access:

```bash
# Export credentials (or source .env)
export AWS_ACCESS_KEY_ID=your_key_id
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=eu-central-1

# Verify access
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAI...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/ecs-deployment-user"
}
```

### Verify Route 53 Access:

```bash
aws route53 list-hosted-zones
```

You should see your hosted zone in the output.

---

## 8. Deploy

Once all values are configured in `.env`:

```bash
make deploy
```

This will:
1. Initialize Terraform
2. Plan infrastructure changes
3. Apply infrastructure (creates VPC, ECS cluster, ALB, CloudFront, etc.)
4. Build Docker image
5. Push to ECR
6. Deploy ECS tasks

Deployment typically takes 5-10 minutes on first run.

---

## Security Best Practices

1. **Never commit `.env` file to version control**
   - It's already in `.gitignore`

2. **Rotate access keys regularly**
   - Create new keys every 90 days
   - Delete old keys after rotation

3. **Use IAM roles in production**
   - For automated deployments, use IAM roles instead of access keys

4. **Restrict IAM permissions**
   - Follow principle of least privilege
   - Use the minimum permissions required

5. **Enable MFA on your AWS account**
   - Especially for root account and IAM users with admin access

6. **Protect your SSH private key**
   - Set proper permissions: `chmod 600 ~/.ssh/aws-ecs-key`
   - Never share your private key

---

## Troubleshooting

### Issue: "Invalid Hosted Zone ID"
- Verify the hosted zone ID is correct
- Check that the hosted zone is in the same AWS account
- Ensure there's no `/hostedzone/` prefix unless required

### Issue: "Access Denied" errors
- Verify IAM user has necessary permissions
- Check that access keys are correct
- Ensure credentials are properly exported/sourced

### Issue: "Domain name doesn't match hosted zone"
- The `DOMAIN_NAME` must be a subdomain of the hosted zone
- Example: If hosted zone is `example.com`, domain can be `app.example.com` but not `otherdomain.com`

### Issue: SSH key format error
- Ensure you're using the PUBLIC key (`.pub` file), not the private key
- The key should be a single line starting with `ssh-rsa` or `ssh-ed25519`
- Remove any line breaks in the key

---

## Cost Estimation

Running this infrastructure will incur AWS costs. Approximate monthly costs:

- EC2 instances (2x t3.micro): ~$15/month
- Application Load Balancer: ~$20/month
- NAT Gateway: ~$35/month
- CloudFront: Variable, minimal for low traffic
- Route 53: $0.50/hosted zone + $0.40/million queries
- ECR: $0.10/GB/month
- Data transfer: Variable

**Estimated total**: ~$70-100/month for minimal usage

Remember to run `make destroy` when done to avoid ongoing charges.
