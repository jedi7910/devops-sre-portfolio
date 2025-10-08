# Terraform Infrastructure

Modular, reusable Terraform configurations for provisioning AWS infrastructure following best practices.

## Overview

This project demonstrates Infrastructure as Code (IaC) using Terraform modules to create a production-ready AWS environment with:
- **VPC** with public and private subnets across multiple availability zones
- **Security Groups** with dynamic ingress rules
- **EC2 instances** distributed across subnets with auto-discovery of latest AMIs

## Architecture
```bash
VPC (10.0.0.0/16)
├── Public Subnets (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
│   ├── Internet Gateway
│   ├── Route Table (public routes)
│   └── EC2 Instances (web servers)
├── Private Subnets (10.0.4.0/24, 10.0.5.0/24, 10.0.6.0/24)
└── Security Groups (HTTP, HTTPS, SSH)
```

## Project Structure
```bash
terraform/
├── docs/
│   └── terraform-basics.md       # Terraform fundamentals reference
├── modules/
│   ├── vpc/                      # VPC with subnets, IGW, routing
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security/                 # Security groups with dynamic rules
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── ec2/                      # EC2 instances with AMI data source
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── main.tf                       # Root configuration
├── variables.tf                  # Input variables
├── outputs.tf                    # Output values
├── terraform.tfvars              # Variable values (not in git)
└── README.md
```

## Modules

### VPC Module
Creates a complete VPC with:
- Configurable CIDR block
- Public and private subnets across multiple AZs
- Internet Gateway for public subnet access
- Route tables and associations
- DNS support enabled

**Inputs:**
- `environment` - Environment name (dev, staging, prod)
- `vpc_cidr` - VPC CIDR block
- `availability_zones` - List of AZs
- `public_subnet_cidrs` - Public subnet CIDR blocks
- `private_subnet_cidrs` - Private subnet CIDR blocks

**Outputs:**
- `vpc_id` - VPC identifier
- `public_subnet_ids` - List of public subnet IDs
- `private_subnet_ids` - List of private subnet IDs

### Security Module
Creates security groups with dynamic ingress rules.

**Features:**
- Dynamic ingress rule generation from list
- Configurable egress rules
- Lifecycle management (create_before_destroy)

**Inputs:**
- `environment` - Environment name
- `vpc_id` - VPC to create security group in
- `ingress_rules` - List of ingress rule objects

**Outputs:**
- `security_group_id` - Security group identifier

### EC2 Module
Creates EC2 instances with best practices.

**Features:**
- Data source for latest Amazon Linux 2 AMI
- Count-based instance creation
- Distribution across multiple subnets using modulo
- Encrypted EBS volumes
- IMDSv2 enforcement
- User data for initialization

**Inputs:**
- `environment` - Environment name
- `instance_count` - Number of instances
- `instance_type` - EC2 instance type
- `subnet_ids` - List of subnets for distribution
- `security_group_id` - Security group to attach
- `key_name` - SSH key pair (optional)
- `user_data` - Initialization script (optional)

**Outputs:**
- `instance_ids` - List of instance IDs
- `instance_public_ips` - List of public IPs
- `instance_private_ips` - List of private IPs

## Usage

### Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.5 installed
- AWS account with appropriate permissions

### Quick Start
```bash
# Initialize Terraform
terraform init

# Review configuration
terraform validate
terraform fmt -recursive

# Preview changes
terraform plan

# Apply infrastructure
terraform apply

# Access outputs
terraform output

# Destroy infrastructure
terraform destroy 

```

## Configuration
Create a terraform.tfvars file (not tracked in git):
```hcl
aws_region           = "us-east-1"
environment          = "dev"
instance_count       = 2
instance_type        = "t3.micro"
key_name             = "your-ssh-key"  # Optional

common_tags = {
  Team    = "DevOps"
  Owner   = "Your Name"
  Project = "terraform-lab"
}
```

## Example: Deploy Development Environment
```bash
# Deploy with default dev settings
terraform apply

# Deploy with custom variables
terraform apply -var="environment=staging" -var="instance_count=4"

# Deploy specific environment
terraform apply -var-file="environments/production.tfvars"
```

## Key Concepts Demonstrated

### Module Composition
Modules are composed in main.tf, with outputs from one module feeding inputs to another:
```hcl
module "vpc" { ... }

module "security" {
  vpc_id = module.vpc.vpc_id  # VPC output → Security input
}

module "ec2" {
  subnet_ids        = module.vpc.public_subnet_ids    # VPC output → EC2 input
  security_group_id = module.security.security_group_id  # Security output → EC2 input
}
```

## Dynamic Resource Creation
### Count-based loops:
```hcl
resource "aws_subnet" "public" {
  count      = length(var.public_subnet_cidrs)
  cidr_block = var.public_subnet_cidrs[count.index]
  # Creates N subnets based on list length
}
```

### Dynamic blocks:
```hcl
dynamic "ingress" {
  for_each = var.ingress_rules
  content {
    from_port = ingress.value.from_port
    # Generates ingress rules from variable
  }
}
``` 
### Data Sources
Query existing resources instead of hardcoding:
```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  # Automatically finds latest AMI
}
```

## Best Practices Implemented
- ✅ Modular design - Reusable, composable components
- ✅ DRY principle - No repeated code
- ✅ Tagging strategy - Consistent resource tagging
- ✅ Security - Encrypted volumes, IMDSv2, least privilege
- ✅ High availability - Multi-AZ deployment
- ✅ Version constraints - Pinned provider versions

## Outputs
```bash
Outputs:

vpc_id = "vpc-xxxxx"
public_subnets = ["subnet-xxxxx", "subnet-yyyyy", "subnet-zzzzz"]
private_subnets = ["subnet-aaaaa", "subnet-bbbbb", "subnet-ccccc"]
security_group_id = "sg-xxxxx"
instance_ids = ["i-xxxxx", "i-yyyyy"]
instance_public_ips = ["54.123.45.67", "54.123.45.68"]
web_urls = ["http://54.123.45.67", "http://54.123.45.68"]
```

## Testing
Verify the deploymnet:
```bash
# Get web server URLs
terraform output web_urls

# Test HTTP access (should show "Hello from dev!")
curl http://$(terraform output -raw instance_public_ips | jq -r '.[0]')

# SSH to instance (if key configured)
ssh -i ~/.ssh/your-key.pem ec2-user@$(terraform output -raw instance_public_ips | jq -r '.[0]')
```

## Cost Estimation
Approximate monthly costs (us-east-1):

- VPC, Subnets, IGW: Free
- t3.micro instances (2): ~$15/month (or free tier)
- EBS volumes (2x 8GB): ~$2/month

Total: ~$17/month (or free with AWS Free Tier)

## Troubleshooting
### Common Issues
#### Error: "Inconsistent dependency lock file"
```bash
terraform init -upgrade
```

### Error: "InvalidKeyPair.NotFound"
- Set key_name = null in variables or create an EC2 key pair first

### Can't SSH to instance
- Ensure security group allows inbound SSH (port 22)
- Check security group allows your IP
- Verify instance has public IP
- Ensure correct key file permissions: chmod 400 key.pem

### User data script did not run
- SSH to instance and check `sudo cat /var/log/cloud-init.log`

## Next Steps
- [ ]  Add remote state backend (S3 + DynamoDB)
- [ ]  Implement multiple environments (dev/staging/prod)
- [ ]  Add NAT Gateway for private subnet internet access
- [ ]  Integrate with CI/CD pipeline (GitHub Actions)
- [ ]  Add monitoring and alerting (CloudWatch)
- [ ]   Implement Auto Scaling Groups

## Resources
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Basics Guide](docs/terraform-basics.md)
- [AWS VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)

## Labs Completed
- [x] Lab 3: Modular Infrastructure (VPC, Security, EC2)
  - Created reusable VPC moduel with multi-AZ subnets
  - Built security group module with dynamic rules
  - Deployed EC2 instances with AMI data source
  - Successfully applied and tested infrastructure
  - Demonstrated full IaC lifecycle

---



### Author: Kenneth Howard

### Last updated: 10/8/2025

### Terraform Version: >= 1.5

### AWS Provider Version: ~> 5.0