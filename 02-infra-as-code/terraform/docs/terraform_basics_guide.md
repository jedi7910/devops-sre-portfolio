# Terraform Basics - Quick Reference Guide

**For DevOps Engineers Coming from CloudFormation**

---

## Table of Contents

1. [HCL Syntax Basics](#hcl-syntax-basics)
2. [The Three Main Block Types](#the-three-main-block-types)
3. [Referencing Things](#referencing-things)
4. [State - The Critical Concept](#state---the-critical-concept)
5. [The Terraform Workflow](#the-terraform-workflow)
6. [Variables - Three Ways to Set Them](#variables---three-ways-to-set-them)
7. [Quick Example - Putting It Together](#quick-example---putting-it-together)
8. [Common Patterns](#common-patterns)
9. [Quick Reference Cheat Sheet](#quick-reference-cheat-sheet)

---

## HCL Syntax Basics

Terraform uses **HCL (HashiCorp Configuration Language)** with this structure:

```hcl
block_type "label" "name" {
  argument = value
  
  nested_block {
    argument = value
  }
}
```

### Example - Creating an AWS S3 Bucket

```hcl
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-unique-bucket-name"
  
  tags = {
    Name        = "My bucket"
    Environment = "dev"
  }
}
```

**Breaking it down:**
- `resource` = block type (this creates something)
- `"aws_s3_bucket"` = resource type (what to create)
- `"my_bucket"` = local name (how YOU reference it in your code)
- Inside `{}` = configuration arguments

---

## The Three Main Block Types

### 1. `resource` - Creates Infrastructure

Creates new infrastructure resources.

```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345"
  instance_type = "t3.micro"
  
  tags = {
    Name = "web-server"
  }
}
```

This **creates** an EC2 instance.

### 2. `data` - Queries Existing Infrastructure

Looks up existing resources without creating them.

```hcl
data "aws_ami" "latest" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
```

This **looks up** an existing AMI (doesn't create anything).

### 3. `variable` - Defines Inputs

Defines input parameters for your configuration.

```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}
```

Think: function parameters.

### 4. `output` - Returns Values

Exports values from your configuration.

```hcl
output "instance_ip" {
  description = "Public IP of the instance"
  value       = aws_instance.web.public_ip
}
```

Think: function return values.

---

## Referencing Things

### Reference a Resource

```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345"
  instance_type = "t3.micro"
}

resource "aws_eip" "ip" {
  instance = aws_instance.web.id  # ← Reference the instance above
}
```

**Pattern:** `resource_type.local_name.attribute`

### Reference a Variable

```hcl
variable "region" {
  default = "us-east-1"
}

provider "aws" {
  region = var.region  # ← Use the variable
}
```

**Pattern:** `var.variable_name`

### Reference a Data Source

```hcl
data "aws_ami" "latest" {
  most_recent = true
  owners      = ["amazon"]
}

resource "aws_instance" "web" {
  ami = data.aws_ami.latest.id  # ← Use the data source result
}
```

**Pattern:** `data.data_type.local_name.attribute`

### Reference Module Outputs

```hcl
module "vpc" {
  source = "./modules/vpc"
}

resource "aws_instance" "web" {
  subnet_id = module.vpc.public_subnet_ids[0]  # ← Use module output
}
```

**Pattern:** `module.module_name.output_name`

---

## State - The Critical Concept

### CloudFormation vs Terraform State

| CloudFormation | Terraform |
|----------------|-----------|
| Tracks state automatically in AWS | Uses local file: `terraform.tfstate` |
| State managed by AWS | You manage the state file |
| Stacks visible in AWS Console | State only in your working directory |

### What's in the State File?

The `terraform.tfstate` file contains:
- What infrastructure currently exists
- Resource IDs, attributes, metadata
- How your code maps to real cloud resources

### Example State Flow

```
1. You write: resource "aws_instance" "web" { ... }
              ↓
2. terraform apply creates the instance
              ↓
3. State file records: instance ID = i-abc123
              ↓
4. Next terraform plan:
   - Reads state file
   - Compares to your code
   - Calculates what needs to change
```

### Golden Rules

⚠️ **Don't lose the state file** or you lose track of your infrastructure!

⚠️ **Don't edit state manually** - use `terraform state` commands

⚠️ **Use remote state** (S3, Terraform Cloud) for team projects

---

## The Terraform Workflow

### Standard Workflow Steps

```
init → validate → plan → apply → destroy
```

### 1. `terraform init`

**Purpose:** Initialize the working directory

**What it does:**
- Downloads provider plugins (AWS, Azure, etc.)
- Sets up backend for state storage
- Prepares modules

**When to run:** Once when you first create/clone a project, or after adding new providers/modules

```bash
terraform init
```

**Output:**
```
Initializing provider plugins...
- Installing hashicorp/aws v5.0.0...

Terraform has been successfully initialized!
```

---

### 2. `terraform validate`

**Purpose:** Check syntax without contacting cloud providers

**What it does:**
- Validates HCL syntax
- Checks for missing required arguments
- Verifies references are valid

**When to run:** After writing/editing code, before plan

```bash
terraform validate
```

**Output:**
```
Success! The configuration is valid.
```

---

### 3. `terraform fmt`

**Purpose:** Format code consistently

**What it does:**
- Fixes indentation
- Aligns equal signs
- Sorts arguments

**When to run:** Before committing code

```bash
terraform fmt -recursive
```

---

### 4. `terraform plan`

**Purpose:** Preview changes without making them

**What it does:**
- Compares current state to desired state
- Shows what **would** change
- **Doesn't create anything** (safe to run)

**When to run:** Before every apply, to review changes

```bash
terraform plan
```

**Output symbols:**
```
+ create
~ modify
- destroy

Plan: 3 to add, 0 to change, 0 to destroy.
```

**Example output:**
```
Terraform will perform the following actions:

  # aws_instance.web will be created
  + resource "aws_instance" "web" {
      + ami           = "ami-12345"
      + instance_type = "t3.micro"
      + id            = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

---

### 5. `terraform apply`

**Purpose:** Create/update infrastructure

**What it does:**
- Shows the plan
- Asks for confirmation
- **Actually creates/modifies** resources
- Updates state file

**When to run:** After reviewing plan, when ready to make changes

```bash
terraform apply

# Or skip confirmation (dangerous!)
terraform apply -auto-approve
```

**Interactive prompt:**
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

---

### 6. `terraform destroy`

**Purpose:** Delete all infrastructure

**What it does:**
- Shows what will be destroyed
- Asks for confirmation
- **Deletes everything** Terraform created
- Updates state file

**When to run:** When cleaning up test environments

```bash
terraform destroy
```

⚠️ **WARNING:** This deletes EVERYTHING in the state file. Be careful!

---

## Variables - Three Ways to Set Them

### 1. Define the Variable

**File:** `variables.tf`

```hcl
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "environment" {
  description = "Environment name"
  type        = string
  # No default = required variable
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = false
}
```

### 2. Set Values - Option 1: Default in Definition

```hcl
variable "instance_type" {
  type    = string
  default = "t3.micro"  # ← Default value
}
```

### 3. Set Values - Option 2: `.tfvars` File

**File:** `terraform.tfvars`

```hcl
instance_type = "t3.small"
environment   = "production"
enable_monitoring = true
```

Terraform automatically loads `terraform.tfvars`.

### 4. Set Values - Option 3: Command Line

```bash
terraform apply -var="instance_type=t3.large" -var="environment=prod"
```

### 5. Set Values - Option 4: Environment Variables

```bash
export TF_VAR_instance_type="t3.large"
export TF_VAR_environment="prod"
terraform apply
```

### Variable Types

```hcl
# String
variable "region" {
  type = string
}

# Number
variable "instance_count" {
  type = number
}

# Boolean
variable "enable_feature" {
  type = bool
}

# List
variable "availability_zones" {
  type = list(string)
}

# Map
variable "tags" {
  type = map(string)
}

# Object
variable "instance_config" {
  type = object({
    type  = string
    count = number
  })
}
```

---

## Quick Example - Putting It Together

### Project Structure

```
my-terraform-project/
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfvars
```

### variables.tf

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}
```

### main.tf

```hcl
provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = var.instance_type
  
  tags = {
    Name        = "${var.environment}-server"  # String interpolation
    Environment = var.environment
  }
}
```

### outputs.tf

```hcl
output "server_ip" {
  description = "Public IP of the web server"
  value       = aws_instance.web.public_ip
}

output "server_id" {
  description = "Instance ID"
  value       = aws_instance.web.id
}
```

### terraform.tfvars

```hcl
environment   = "dev"
instance_type = "t3.small"
```

### Running It

```bash
# Initialize
terraform init

# Check syntax
terraform validate

# Preview changes
terraform plan

# Apply changes
terraform apply
# Type 'yes' when prompted

# View outputs
terraform output

# Clean up
terraform destroy
```

---

## Common Patterns

### Pattern 1: Count - Create Multiple Resources

```hcl
resource "aws_instance" "web" {
  count = 3  # Creates 3 instances
  
  ami           = "ami-12345"
  instance_type = "t3.micro"
  
  tags = {
    Name = "web-server-${count.index + 1}"
  }
}

# Reference: aws_instance.web[0], aws_instance.web[1], aws_instance.web[2]
# Get all IDs: aws_instance.web[*].id
```

### Pattern 2: String Interpolation

```hcl
locals {
  name_prefix = "${var.environment}-${var.project}"
}

resource "aws_instance" "web" {
  tags = {
    Name = "${local.name_prefix}-web-server"
    # Results in: "dev-myapp-web-server"
  }
}
```

### Pattern 3: Conditional Resources

```hcl
resource "aws_instance" "optional" {
  count = var.create_instance ? 1 : 0  # Create only if true
  
  ami           = "ami-12345"
  instance_type = "t3.micro"
}
```

### Pattern 4: Dynamic Blocks

```hcl
resource "aws_security_group" "web" {
  name = "web-sg"
  
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}
```

### Pattern 5: Locals for Computed Values

```hcl
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
  
  name_prefix = "${var.environment}-${var.project_name}"
}

resource "aws_instance" "web" {
  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-web"
    }
  )
}
```

---

## Quick Reference Cheat Sheet

### Basic Syntax

```hcl
# Resource
resource "type" "name" {
  argument = value
}

# Variable
variable "name" {
  type    = string
  default = "value"
}

# Output
output "name" {
  value = resource.type.name.attribute
}

# Data source
data "type" "name" {
  argument = value
}

# Module
module "name" {
  source = "./path/to/module"
  input  = value
}
```

### Reference Patterns

```hcl
var.variable_name                    # Variable
resource_type.name.attribute         # Resource
data.type.name.attribute             # Data source
module.name.output_name              # Module output
local.name                           # Local value
```

### Common Commands

```bash
terraform init          # Initialize directory
terraform validate      # Check syntax
terraform fmt           # Format code
terraform plan          # Preview changes
terraform apply         # Create/update infrastructure
terraform destroy       # Delete infrastructure
terraform output        # Show output values
terraform state list    # List resources in state
terraform state show    # Show resource details
```

### Variable Types

```hcl
string              # "hello"
number              # 42
bool                # true
list(string)        # ["a", "b", "c"]
map(string)         # {key = "value"}
set(string)         # Unique list
object({})          # Complex structure
```

### Built-in Functions (Common)

```hcl
length(list)                    # Get list length
element(list, index)            # Get element at index
concat(list1, list2)            # Join lists
merge(map1, map2)               # Merge maps
join(",", list)                 # Join list to string
split(",", string)              # Split string to list
lookup(map, key, default)       # Get map value with default
```

### Operators

```hcl
==, !=                  # Equality
<, >, <=, >=            # Comparison
&&, ||, !               # Logical
+, -, *, /, %           # Arithmetic
? :                     # Conditional (ternary)
```

---

## Key Differences: CloudFormation vs Terraform

| Feature | CloudFormation | Terraform |
|---------|----------------|-----------|
| **Language** | YAML/JSON | HCL |
| **Cloud Support** | AWS only | Multi-cloud |
| **State** | Managed by AWS | Local file (or remote backend) |
| **Modularity** | Nested stacks | Modules |
| **Variables** | Parameters | Variables |
| **Outputs** | Outputs | Outputs |
| **Conditions** | Conditions section | count, conditional expressions |
| **Loops** | Limited (Count, Fn::Each) | count, for_each, dynamic blocks |

---

## Best Practices

### 1. Project Structure

```
project/
├── main.tf           # Main configuration
├── variables.tf      # Variable definitions
├── outputs.tf        # Output definitions
├── terraform.tfvars  # Variable values (don't commit if secrets!)
├── versions.tf       # Provider versions
└── modules/          # Reusable modules
    └── vpc/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### 2. Always Use Version Constraints

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
```

### 3. Use Remote State for Teams

```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "project/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### 4. Always Run Plan Before Apply

```bash
# Never skip this!
terraform plan
terraform apply
```

### 5. Use Meaningful Names

```hcl
# Good
resource "aws_instance" "web_server" { }

# Bad
resource "aws_instance" "i1" { }
```

### 6. Tag Everything

```hcl
resource "aws_instance" "web" {
  tags = {
    Name        = "web-server"
    Environment = "production"
    ManagedBy   = "Terraform"
    Owner       = "team@company.com"
  }
}
```

---

## Troubleshooting Common Issues

### Issue: "Error: Inconsistent dependency lock file"

**Solution:**
```bash
terraform init -upgrade
```

### Issue: "Error: Resource already exists"

**Cause:** Resource exists but not in state file

**Solution:** Import the resource
```bash
terraform import aws_instance.web i-1234567890abcdef0
```

### Issue: State file conflicts (team collaboration)

**Solution:** Use remote state with locking
```hcl
terraform {
  backend "s3" {
    bucket         = "my-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"  # For locking
  }
}
```

### Issue: "Error: Cycle" (circular dependency)

**Cause:** Resources reference each other in a loop

**Solution:** Break the cycle or use `depends_on`

---

## Next Steps

### You're Ready When You Can:

- ✅ Read and understand HCL syntax
- ✅ Explain the difference between resource, data, variable, output
- ✅ Understand what the state file does
- ✅ Run the basic workflow (init → plan → apply → destroy)
- ✅ Reference resources and variables

### Continue Learning:

1. **Complete Lab 3** - Build modular infrastructure
2. **Study modules** - Reusable components
3. **Learn provisioners** - Run scripts on resources
4. **Explore backends** - Remote state storage
5. **Practice workspaces** - Manage multiple environments

---

## Additional Resources

- **Official Docs:** https://developer.hashicorp.com/terraform/docs
- **Registry:** https://registry.terraform.io/ (find providers and modules)
- **AWS Provider:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **Style Guide:** https://developer.hashicorp.com/terraform/language/syntax/style

---

**Ready to start Lab 3!** 🚀

This guide covers everything you need to understand Terraform basics. Keep it handy as you work through the lab.
