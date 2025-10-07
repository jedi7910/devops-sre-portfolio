# Terraform Infrastructure

This directory contains Terraform configurations for provisioning AWS infrastructure using modular, reusable components.

## Documentation

- [Terraform Basics Guide](docs/terraform-basics.md) - Quick reference for Terraform fundamentals

## Structure
```
terraform/
├── docs/                  # Documentation
├── modules/              # Reusable modules
│   ├── vpc/             # VPC with subnets, IGW
│   ├── ec2/             # EC2 instances
│   └── security/        # Security groups
├── main.tf              # Root configuration
├── variables.tf         # Input variables
├── outputs.tf           # Output values
└── terraform.tfvars     # Variable values
```

## Usage
```bash
# Initialize
terraform init

# Validate syntax
terraform validate

# Preview changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy
```
## Labs Completed
- [ ] Lab 3: Modular Infrastructure (VPC, Security, EC2)