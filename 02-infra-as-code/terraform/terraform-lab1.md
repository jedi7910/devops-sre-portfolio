# Lab 3: Terraform Modular Infrastructure - VPC, EC2, and Security

## Objective
Build production-ready, reusable Terraform modules for AWS infrastructure. Learn Infrastructure as Code (IaC) best practices by creating modular, maintainable infrastructure.

## Prerequisites
- AWS account (free tier is sufficient)
- AWS CLI configured with credentials
- Terraform installed (v1.5+)
- Basic understanding of AWS networking (VPC, subnets)
- Completed Labs 1-2 (GitHub Actions experience helpful)

## Background: Why Modules?

Think of Terraform modules like your reusable GitHub Actions workflows from Lab 2:

| GitHub Actions | Terraform Modules |
|----------------|------------------|
| Reusable workflows | Reusable modules |
| `inputs:` | `variables.tf` |
| `outputs:` | `outputs.tf` |
| Steps in jobs | Resources in `main.tf` |
| Called with `uses:` | Called with `module` block |

Just like you don't copy the same workflow steps everywhere, you don't copy the same infrastructure code!

---

## Lab Setup

### Step 1: Create Directory Structure

```bash
cd 02-infra-as-code/

# Create the complete structure
mkdir -p terraform/modules/{vpc,ec2,security}

cd terraform

# Create root files
touch main.tf variables.tf outputs.tf terraform.tfvars README.md

# Create module files
touch modules/vpc/{main.tf,variables.tf,outputs.tf}
touch modules/ec2/{main.tf,variables.tf,outputs.tf}
touch modules/security/{main.tf,variables.tf,outputs.tf}

# Create .gitignore
cat > .gitignore << 'EOF'
# Terraform files to ignore
.terraform/
.terraform.lock.hcl
terraform.tfstate
terraform.tfstate.backup
*.tfvars
!terraform.tfvars.example
.terraform.tfstate.lock.info
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
EOF
```

Your structure should look like:
```
02-infra-as-code/
└── terraform/
    ├── modules/
    │   ├── vpc/
    │   │   ├── main.tf
    │   │   ├── variables.tf
    │   │   └── outputs.tf
    │   ├── ec2/
    │   │   ├── main.tf
    │   │   ├── variables.tf
    │   │   └── outputs.tf
    │   └── security/
    │       ├── main.tf
    │       ├── variables.tf
    │       └── outputs.tf
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars
    ├── .gitignore
    └── README.md
```

---

## Challenge 1: VPC Module - Your Network Foundation

### Scenario:
Every application needs a network. You need a VPC with public and private subnets across multiple availability zones for high availability.

### Task 1.1: Define VPC Module Variables

Create `modules/vpc/variables.tf`:

**Requirements:**
1. Variable for `environment` (string, required)
2. Variable for `vpc_cidr` (string, default: "10.0.0.0/16")
3. Variable for `availability_zones` (list of strings, required)
4. Variable for `public_subnet_cidrs` (list of strings, required)
5. Variable for `private_subnet_cidrs` (list of strings, required)
6. Variable for `tags` (map of strings, optional)

**Your Challenge:** Write these variable definitions!

<details>
<summary>💡 Hint: Variable Structure</summary>

```hcl
variable "name" {
  description = "Description of what this variable does"
  type        = string  # or list(string), map(string), etc.
  default     = "value" # optional
}
```
</details>

<details>
<summary>✅ Solution</summary>

```hcl
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
```
</details>

---

### Task 1.2: Build the VPC Resources

Create `modules/vpc/main.tf`:

**Requirements:**
1. Create a VPC with DNS support enabled
2. Create an Internet Gateway attached to the VPC
3. Create public subnets (use `count` to create multiple)
4. Create private subnets (use `count` to create multiple)
5. Create a route table for public subnets with route to Internet Gateway
6. Associate public subnets with the public route table
7. Tag everything with `environment` and merge additional tags

**Challenge:** Use `count.index` to create multiple subnets dynamically!

<details>
<summary>💡 Hint: Using count</summary>

```hcl
resource "aws_subnet" "example" {
  count      = length(var.subnet_cidrs)
  cidr_block = var.subnet_cidrs[count.index]
  # ...
}
```
</details>

<details>
<summary>✅ Solution</summary>

```hcl
# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-vpc"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-igw"
    }
  )
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-public-subnet-${count.index + 1}"
      Type = "public"
    }
  )
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-private-subnet-${count.index + 1}"
      Type = "private"
    }
  )
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-public-rt"
    }
  )
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
```
</details>

---

### Task 1.3: Define VPC Module Outputs

Create `modules/vpc/outputs.tf`:

**Requirements:**
Output the following so other modules can use them:
1. `vpc_id` - The VPC ID
2. `vpc_cidr` - The VPC CIDR block
3. `public_subnet_ids` - List of public subnet IDs
4. `private_subnet_ids` - List of private subnet IDs
5. `internet_gateway_id` - The Internet Gateway ID

<details>
<summary>💡 Hint: Output Lists</summary>

```hcl
output "subnet_ids" {
  value = aws_subnet.example[*].id  # The [*] splat operator gets all IDs
}
```
</details>

<details>
<summary>✅ Solution</summary>

```hcl
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}
```
</details>

---

## Challenge 2: Security Module - Defense in Depth

### Task 2.1: Create Security Group Module

Create `modules/security/variables.tf`:

**Requirements:**
1. Variable for `environment` (string)
2. Variable for `vpc_id` (string)
3. Variable for `ingress_rules` (list of objects with from_port, to_port, protocol, cidr_blocks, description)
4. Variable for `tags` (map)

<details>
<summary>✅ Solution</summary>

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security group will be created"
  type        = string
}

variable "ingress_rules" {
  description = "List of ingress rules"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
```
</details>

---

### Task 2.2: Build Security Group with Dynamic Blocks

Create `modules/security/main.tf`:

**Requirements:**
1. Create a security group in the VPC
2. Use `dynamic` blocks to create ingress rules from the variable
3. Allow all outbound traffic (egress)
4. Use `lifecycle` block with `create_before_destroy = true`

**Challenge:** Use dynamic blocks - this is like loops in Terraform!

<details>
<summary>💡 Hint: Dynamic Blocks</summary>

```hcl
dynamic "ingress" {
  for_each = var.ingress_rules
  content {
    from_port   = ingress.value.from_port
    # ... other fields
  }
}
```
</details>

<details>
<summary>✅ Solution</summary>

```hcl
resource "aws_security_group" "main" {
  name_prefix = "${var.environment}-web-"
  description = "Security group for web servers"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-web-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}
```
</details>

---

### Task 2.3: Security Module Outputs

Create `modules/security/outputs.tf`:

```hcl
output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.main.id
}

output "security_group_name" {
  description = "Name of the security group"
  value       = aws_security_group.main.name
}
```

---

## Challenge 3: EC2 Module - Compute Resources

### Task 3.1: EC2 Module Variables

Create `modules/ec2/variables.tf`:

**Requirements:**
1. `environment` (string)
2. `instance_count` (number, default: 1)
3. `instance_type` (string, default: "t3.micro")
4. `subnet_ids` (list of strings) - we'll distribute instances across subnets
5. `security_group_id` (string)
6. `key_name` (string, optional)
7. `user_data` (string, optional)
8. `tags` (map)

<details>
<summary>✅ Solution</summary>

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_ids" {
  description = "List of subnet IDs where instances will be created"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID to attach to instances"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = null
}

variable "user_data" {
  description = "User data script for instance initialization"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to instances"
  type        = map(string)
  default     = {}
}
```
</details>

---

### Task 3.2: EC2 Instances with Data Source

Create `modules/ec2/main.tf`:

**Requirements:**
1. Use a data source to get the latest Amazon Linux 2 AMI
2. Create EC2 instances (use count)
3. Distribute instances across subnets using modulo: `subnet_ids[count.index % length(subnet_ids)]`
4. Attach security group
5. Use encrypted EBS volumes
6. Add IMDSv2 requirement for security
7. Tag instances with environment and index number

**Challenge:** Use a data source to automatically get the latest AMI!

<details>
<summary>💡 Hint: Data Sources</summary>

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Then use: ami = data.aws_ami.amazon_linux.id
```
</details>

<details>
<summary>✅ Solution</summary>

```hcl
# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instances
resource "aws_instance" "main" {
  count                  = var.instance_count
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name
  user_data              = var.user_data

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens                 = "required"  # Require IMDSv2
    http_put_response_hop_limit = 1
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-instance-${count.index + 1}"
    }
  )
}
```
</details>

---

### Task 3.3: EC2 Module Outputs

Create `modules/ec2/outputs.tf`:

```hcl
output "instance_ids" {
  description = "List of instance IDs"
  value       = aws_instance.main[*].id
}

output "instance_public_ips" {
  description = "List of public IPs"
  value       = aws_instance.main[*].public_ip
}

output "instance_private_ips" {
  description = "List of private IPs"
  value       = aws_instance.main[*].private_ip
}
```

---

## Challenge 4: Root Configuration - Compose the Modules

### Task 4.1: Root Variables

Create `variables.tf` in the terraform root directory:

**Requirements:**
Define variables for:
- AWS region
- Environment name
- VPC CIDR and subnet CIDRs
- Availability zones
- Instance settings (type, count)
- SSH key name
- Common tags

<details>
<summary>✅ Solution</summary>

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "Number of EC2 instances"
  type        = number
  default     = 2
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Team    = "DevOps"
    Owner   = "Portfolio"
    Project = "terraform-lab"
  }
}
```
</details>

---

### Task 4.2: Compose Modules in Main Configuration

Create `main.tf` in the terraform root directory:

**Requirements:**
1. Configure Terraform and AWS provider
2. Call the VPC module
3. Call the Security module (depends on VPC output)
4. Call the EC2 module (depends on VPC and Security outputs)
5. Pass outputs between modules

**Challenge:** Notice how module outputs become inputs to other modules!

<details>
<summary>✅ Solution</summary>

```hcl
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Project     = "devops-portfolio"
      Environment = var.environment
    }
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = var.common_tags
}

# Security Module
module "security" {
  source = "./modules/security"

  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  
  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP from anywhere"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS from anywhere"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["YOUR_IP/32"]  # CHANGE THIS!
      description = "SSH from your IP"
    }
  ]
  
  tags = var.common_tags
}

# EC2 Module
module "ec2" {
  source = "./modules/ec2"

  environment       = var.environment
  instance_count    = var.instance_count
  instance_type     = var.instance_type
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_id = module.security.security_group_id
  key_name          = var.key_name
  
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from ${var.environment}!</h1>" > /var/www/html/index.html
              EOF
  
  tags = var.common_tags
}
```
</details>

---

### Task 4.3: Root Outputs

Create `outputs.tf` in the terraform root:

```hcl
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "security_group_id" {
  description = "Security group ID"
  value       = module.security.security_group_id
}

output "instance_ids" {
  description = "EC2 instance IDs"
  value       = module.ec2.instance_ids
}

output "instance_public_ips" {
  description = "EC2 instance public IPs"
  value       = module.ec2.instance_public_ips
}

output "web_urls" {
  description = "URLs to access web servers"
  value       = [for ip in module.ec2.instance_public_ips : "http://${ip}"]
}
```

---

## Challenge 5: Initialize and Test

### Task 5.1: Initialize Terraform

```bash
cd 02-infra-as-code/terraform

# Initialize Terraform (downloads providers)
terraform init

# You should see: "Terraform has been successfully initialized!"
```

### Task 5.2: Validate Configuration

```bash
# Check for syntax errors
terraform validate

# Format code consistently
terraform fmt -recursive

# You should see: "Success! The configuration is valid."
```

### Task 5.3: Plan Infrastructure

```bash
# See what Terraform will create
terraform plan

# Review the output:
# - How many resources will be created?
# - What are their names?
# - Any errors?
```

**Expected output should show:**
- 1 VPC
- 1 Internet Gateway
- 2 Public Subnets
- 2 Private Subnets
- 1 Route Table
- 2 Route Table Associations
- 1 Security Group
- 2 EC2 Instances

**Total: ~10 resources**

---

## Challenge 6: Apply (Optional - Costs Money!)

⚠️ **WARNING**: This will create real AWS resources that cost money!
- Free tier: t3.micro instances are usually covered
- VPC/Subnets/IGW: Free
- **NAT Gateway would cost ~$30/month** (we didn't create one)
- Estimated cost: ~$0-5/month if kept running

### Task 6.1: Apply Infrastructure

```bash
# Create the infrastructure
terraform apply

# Type 'yes' when prompted

# Wait 2-3 minutes for creation
```

### Task 6.2: Test Your Infrastructure

```bash
# Get the web URLs from outputs
terraform output web_urls

# Visit the URLs in your browser
# You should see "Hello from dev!"

# SSH to an instance (if you set key_name)
ssh -i ~/.ssh/your-key.pem ec2-user@<instance-ip>
```

### Task 6.3: Destroy Infrastructure

```bash
# IMPORTANT: Clean up to avoid charges!
terraform destroy

# Type 'yes' when prompted
```

---

## Questions to Consider

### 1. Compare: Modules vs Copy-Paste

**Think about:**
- How is using modules different from copying the same code to multiple files?
- What happens if you need to update the VPC configuration in 10 different projects?
- Which approach is more maintainable?

### 2. Data Flow Between Modules

**Consider:**
- How did the VPC module's outputs become the EC2 module's inputs?
- What would happen if you changed the order of module declarations?
- Is this similar to `needs:` in GitHub Actions?

### 3. State Management

**Reflect:**
- Where is Terraform storing the current infrastructure state?
- What happens if you lose the `terraform.tfstate` file?
- Why might you want remote state storage (like S3)?

### 4. Idempotency

**Experiment:**
- Run `terraform apply` twice without changing anything. What happens?
- Change `instance_count` from 2 to 3. What does `terraform plan` show?
- How does Terraform know what already exists?

---

## Verification Checklist

- [ ] Created all three modules (vpc, security, ec2)
- [ ] Each module has variables.tf, main.tf, outputs.tf
- [ ] Root configuration calls all three modules
- [ ] `terraform init` succeeds
- [ ] `terraform validate` passes
- [ ] `terraform fmt` applied
- [ ] `terraform plan` shows expected resources
- [ ] (Optional) Applied and tested infrastructure
- [ ] (Optional) Destroyed infrastructure to avoid costs
- [ ] Understand how module outputs connect to other module inputs

---

## Common Issues & Troubleshooting

**Issue**: "Error: Invalid count argument"
- Check that `length(var.public_subnet_cidrs)` matches `length(var.availability_zones)`
- Both lists must have the same number of elements

**Issue**: "Error: Insufficient subnet blocks"
- Your CIDR blocks might overlap
- Make sure 10.0.1.0/24 and 10.0.2.0/24 don't conflict

**Issue**: "Error: UnauthorizedOperation"
- Check your AWS credentials: `aws sts get-caller-identity`
- Verify your IAM user has EC2, VPC permissions

**Issue**: "Error: Error launching source instance: InvalidKeyPair.NotFound"
- Create an EC2 key pair first, or set `key_name = null` in variables

**Issue**: SSH timeout (can't connect to instance)
- Change the SSH security group rule to your actual IP
- Make sure instance is in a public subnet
- Check that instance has a public IP

---

## What You've Learned

✅ **Terraform Fundamentals:**
- Resources, variables, outputs
- Modules and composition
- Data sources
- Count and splat operators
- Dynamic blocks

✅ **AWS Networking:**
- VPC architecture
- Public vs private subnets
- Internet Gateway and routing
- Security groups

✅ **Best Practices:**
- Modular, reusable code
- DRY principle (Don't Repeat Yourself)
- Tag management
- Security (encrypted volumes, IMDSv2)

---

## Next Steps

1. **Add to GitHub:** Commit your Terraform code
2. **Document:** Update your README with architecture diagram
3. **Compare to Ansible:** Think about when to use Terraform vs Ansible
4. **Next Lab:** Integrate Terraform with GitHub Actions for automated infrastructure deployment

---

## Bonus Challenges (Optional)

### Bonus 1: Add NAT Gateway
Make private subnets able to reach the internet by adding a NAT Gateway module.

### Bonus 2: Multi-Environment
Create separate `.tfvars` files for dev, staging, and prod environments.

### Bonus 3: Remote State
Configure S3 backend for state storage (see Phase 3 reference guide).

### Bonus 4: Variable Validation
Add validation rules to variables:
```hcl
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

### Bonus 5: Locals
Use `locals` block to calculate values:
```hcl
locals {
  common_tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      Terraform   = "true"
    }
  )
}
```
