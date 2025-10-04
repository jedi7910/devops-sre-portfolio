# DevOps Mastery: Phases 2-5 Complete Guide

---

## **Phase 2: GitHub Actions (CI/CD)**

### **2.1 Basic Workflow Examples**

#### **Test Workflow (.github/workflows/test.yml)**
```yaml
name: Test Suite

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        cache: 'npm'
        
    - name: Install dependencies
      run: npm ci
      
    - name: Run linter
      run: npm run lint
      
    - name: Run unit tests
      run: npm test -- --coverage
      
    - name: Upload coverage
      uses: codecov/codecov-action@v3
      with:
        files: ./coverage/coverage-final.json
        fail_ci_if_error: true
```

#### **Build and Deploy Workflow (.github/workflows/deploy.yml)**
```yaml
name: Build and Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3
      
    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
        
    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=sha,prefix={{branch}}-
          type=semver,pattern={{version}}
          
    - name: Build and push
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: production
    
    steps:
    - name: Deploy to Kubernetes
      uses: azure/k8s-deploy@v4
      with:
        manifests: |
          k8s/deployment.yaml
          k8s/service.yaml
        images: ${{ needs.build.outputs.image-tag }}
        namespace: production
```

### **2.2 Matrix Builds for Multi-Environment Testing**

```yaml
name: Matrix Testing

on: [push, pull_request]

jobs:
  test-matrix:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        node-version: [16, 18, 20]
        exclude:
          - os: macos-latest
            node-version: 16
            
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Node ${{ matrix.node-version }}
      uses: actions/setup-node@v4
      with:
        node-version: ${{ matrix.node-version }}
        
    - name: Install and Test
      run: |
        npm ci
        npm test
        
    - name: Upload results
      if: always()
      uses: actions/upload-artifact@v3
      with:
        name: test-results-${{ matrix.os }}-node${{ matrix.node-version }}
        path: test-results/
```

### **2.3 Reusable Workflows**

#### **Reusable Build Workflow (.github/workflows/reusable-build.yml)**
```yaml
name: Reusable Build

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      node-version:
        required: false
        type: string
        default: '18'
    secrets:
      deploy-token:
        required: true
    outputs:
      build-id:
        description: "Build identifier"
        value: ${{ jobs.build.outputs.build-id }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      build-id: ${{ steps.build-info.outputs.id }}
      
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Node
      uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        
    - name: Build
      run: |
        npm ci
        npm run build
        
    - name: Set build info
      id: build-info
      run: echo "id=${{ github.run_number }}-${{ inputs.environment }}" >> $GITHUB_OUTPUT
      
    - name: Upload artifacts
      uses: actions/upload-artifact@v3
      with:
        name: build-${{ steps.build-info.outputs.id }}
        path: dist/
```

#### **Caller Workflow (.github/workflows/main.yml)**
```yaml
name: Main Pipeline

on: [push]

jobs:
  build-staging:
    uses: ./.github/workflows/reusable-build.yml
    with:
      environment: staging
      node-version: '18'
    secrets:
      deploy-token: ${{ secrets.STAGING_TOKEN }}
      
  build-production:
    uses: ./.github/workflows/reusable-build.yml
    with:
      environment: production
      node-version: '20'
    secrets:
      deploy-token: ${{ secrets.PROD_TOKEN }}
```

### **2.4 Advanced Multi-Stage Pipeline**

```yaml
name: Complete CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Validate YAML
      run: yamllint .
    - name: Check formatting
      run: npm run format:check

  security-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Run Trivy scan
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
    - name: Upload results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'

  test:
    needs: validate
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: '18'
    - run: npm ci
    - run: npm test

  build:
    needs: [test, security-scan]
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Build application
      run: npm run build
    - uses: actions/upload-artifact@v3
      with:
        name: build-artifact
        path: dist/

  deploy-staging:
    needs: build
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment: staging
    steps:
    - name: Download artifact
      uses: actions/download-artifact@v3
      with:
        name: build-artifact
    - name: Deploy to staging
      run: echo "Deploying to staging..."

  deploy-production:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
    - name: Download artifact
      uses: actions/download-artifact@v3
      with:
        name: build-artifact
    - name: Deploy to production
      run: echo "Deploying to production..."
```

---

## **Phase 3: Infrastructure as Code**

### **3.1 Terraform - AWS EC2 Deployment with Modules**

#### **Project Structure**
```
terraform/
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
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf
│       └── terraform.tfvars
└── main.tf
```

#### **VPC Module (modules/vpc/main.tf)**
```hcl
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

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-igw"
    }
  )
}

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

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
```

#### **VPC Module Variables (modules/vpc/variables.tf)**
```hcl
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
```

#### **VPC Module Outputs (modules/vpc/outputs.tf)**
```hcl
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}
```

#### **EC2 Module (modules/ec2/main.tf)**
```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "web" {
  count                  = var.instance_count
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name

  user_data = templatefile("${path.module}/user-data.sh", {
    environment = var.environment
  })

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-web-${count.index + 1}"
    }
  )
}

resource "aws_eip" "web" {
  count    = var.assign_eip ? var.instance_count : 0
  instance = aws_instance.web[count.index].id
  domain   = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-eip-${count.index + 1}"
    }
  )
}
```

#### **Security Module (modules/security/main.tf)**
```hcl
resource "aws_security_group" "web" {
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

#### **Root Main Configuration (main.tf)**
```hcl
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Project     = var.project_name
      Environment = var.environment
    }
  }
}

module "vpc" {
  source = "./modules/vpc"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  tags                 = var.common_tags
}

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
      description = "HTTP"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidrs
      description = "SSH"
    }
  ]
  tags = var.common_tags
}

module "ec2" {
  source = "./modules/ec2"

  environment       = var.environment
  instance_count    = var.instance_count
  instance_type     = var.instance_type
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_id = module.security.security_group_id
  key_name          = var.key_name
  assign_eip        = true
  tags              = var.common_tags
}
```

#### **Variables File (terraform.tfvars)**
```hcl
aws_region   = "us-east-1"
environment  = "production"
project_name = "web-app"

vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

instance_count    = 2
instance_type     = "t3.medium"
ssh_allowed_cidrs = ["YOUR_IP/32"]

common_tags = {
  Team  = "DevOps"
  Owner = "Infrastructure Team"
}
```

### **3.2 Ansible - Configuration Management**

#### **Project Structure**
```
ansible/
├── inventory/
│   ├── production
│   └── staging
├── roles/
│   ├── common/
│   │   ├── tasks/
│   │   ├── handlers/
│   │   ├── templates/
│   │   └── defaults/
│   ├── webserver/
│   └── database/
├── playbooks/
│   ├── site.yml
│   ├── webserver.yml
│   └── database.yml
└── ansible.cfg
```

#### **Ansible Configuration (ansible.cfg)**
```ini
[defaults]
inventory = ./inventory/production
remote_user = ec2-user
host_key_checking = False
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600

[privilege_escalation]
become = True
become_method = sudo
become_user = root
```

#### **Inventory File (inventory/production)**
```ini
[webservers]
web01 ansible_host=10.0.1.10
web02 ansible_host=10.0.1.11

[databases]
db01 ansible_host=10.0.10.10

[production:children]
webservers
databases

[production:vars]
ansible_ssh_private_key_file=~/.ssh/production.pem
environment=production
```

#### **Common Role (roles/common/tasks/main.yml)**
```yaml
---
- name: Update all packages
  ansible.builtin.yum:
    name: '*'
    state: latest
    update_cache: yes
  tags: [packages]

- name: Install essential packages
  ansible.builtin.yum:
    name:
      - vim
      - git
      - htop
      - curl
      - wget
      - unzip
    state: present
  tags: [packages]

- name: Configure timezone
  community.general.timezone:
    name: "{{ timezone | default('UTC') }}"
  tags: [system]

- name: Configure NTP
  ansible.builtin.template:
    src: chrony.conf.j2
    dest: /etc/chrony.conf
    mode: '0644'
  notify: restart chronyd
  tags: [system]

- name: Start and enable chronyd
  ansible.builtin.service:
    name: chronyd
    state: started
    enabled: yes
  tags: [system]

- name: Create admin users
  ansible.builtin.user:
    name: "{{ item.name }}"
    groups: "{{ item.groups }}"
    shell: /bin/bash
    create_home: yes
  loop: "{{ admin_users }}"
  when: admin_users is defined
  tags: [users]

- name: Add SSH keys for admin users
  ansible.posix.authorized_key:
    user: "{{ item.name }}"
    key: "{{ item.ssh_key }}"
    state: present
  loop: "{{ admin_users }}"
  when: admin_users is defined
  tags: [users]

- name: Configure firewall
  ansible.posix.firewalld:
    port: "{{ item }}"
    permanent: yes
    state: enabled
    immediate: yes
  loop: "{{ firewall_allowed_ports }}"
  when: firewall_allowed_ports is defined
  tags: [firewall]

- name: Disable SELinux (if required)
  ansible.posix.selinux:
    state: "{{ selinux_state | default('enforcing') }}"
  tags: [security]
```

#### **Webserver Role (roles/webserver/tasks/main.yml)**
```yaml
---
- name: Install Nginx
  ansible.builtin.yum:
    name: nginx
    state: present
  tags: [nginx]

- name: Create web root directory
  ansible.builtin.file:
    path: "{{ web_root }}"
    state: directory
    owner: nginx
    group: nginx
    mode: '0755'
  tags: [nginx]

- name: Deploy Nginx configuration
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    mode: '0644'
    validate: 'nginx -t -c %s'
  notify: reload nginx
  tags: [nginx, config]

- name: Deploy site configuration
  ansible.builtin.template:
    src: site.conf.j2
    dest: "/etc/nginx/conf.d/{{ site_name }}.conf"
    mode: '0644'
  notify: reload nginx
  tags: [nginx, config]

- name: Deploy application files
  ansible.builtin.copy:
    src: "{{ item }}"
    dest: "{{ web_root }}/"
    owner: nginx
    group: nginx
    mode: '0644'
  with_fileglob:
    - "files/app/*"
  tags: [deploy]

- name: Ensure Nginx is started and enabled
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: yes
  tags: [nginx]

- name: Configure log rotation
  ansible.builtin.template:
    src: logrotate.j2
    dest: /etc/logrotate.d/nginx
    mode: '0644'
  tags: [nginx, logs]
```

#### **Webserver Handlers (roles/webserver/handlers/main.yml)**
```yaml
---
- name: reload nginx
  ansible.builtin.service:
    name: nginx
    state: reloaded

- name: restart nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
```

#### **Main Playbook (playbooks/site.yml)**
```yaml
---
- name: Configure all servers
  hosts: all
  become: yes
  
  pre_tasks:
    - name: Display environment info
      ansible.builtin.debug:
        msg: "Configuring {{ inventory_hostname }} in {{ environment }} environment"
    
    - name: Verify connectivity
      ansible.builtin.ping:

  roles:
    - common

- name: Configure web servers
  hosts: webservers
  become: yes
  
  vars:
    web_root: /var/www/html
    site_name: myapp
    firewall_allowed_ports:
      - 80/tcp
      - 443/tcp
  
  roles:
    - webserver
  
  post_tasks:
    - name: Verify Nginx is running
      ansible.builtin.uri:
        url: "http://{{ ansible_default_ipv4.address }}"
        status_code: 200
      register: result
      retries: 3
      delay: 5
      until: result.status == 200

- name: Configure database servers
  hosts: databases
  become: yes
  
  roles:
    - database
```

#### **Advanced Playbook with Error Handling**
```yaml
---
- name: Deploy application with rollback capability
  hosts: webservers
  become: yes
  serial: 1  # Rolling deployment
  max_fail_percentage: 0
  
  vars:
    app_version: "{{ lookup('env', 'APP_VERSION') | default('latest') }}"
    deploy_dir: /opt/myapp
    backup_dir: /opt/backups
    
  tasks:
    - name: Create backup of current deployment
      ansible.builtin.archive:
        path: "{{ deploy_dir }}"
        dest: "{{ backup_dir }}/app-{{ ansible_date_time.epoch }}.tar.gz"
      when: deploy_dir is exists
      tags: [backup]
    
    - name: Stop application
      ansible.builtin.systemd:
        name: myapp
        state: stopped
      tags: [deploy]
    
    - name: Deploy new version
      block:
        - name: Download application artifact
          ansible.builtin.get_url:
            url: "https://releases.example.com/myapp-{{ app_version }}.tar.gz"
            dest: "/tmp/myapp-{{ app_version }}.tar.gz"
            checksum: "sha256:{{ app_checksum }}"
        
        - name: Extract application
          ansible.builtin.unarchive:
            src: "/tmp/myapp-{{ app_version }}.tar.gz"
            dest: "{{ deploy_dir }}"
            remote_src: yes
        
        - name: Update configuration
          ansible.builtin.template:
            src: app-config.j2
            dest: "{{ deploy_dir }}/config.yml"
        
        - name: Start application
          ansible.builtin.systemd:
            name: myapp
            state: started
            daemon_reload: yes
        
        - name: Wait for application to be ready
          ansible.builtin.uri:
            url: "http://localhost:8080/health"
            status_code: 200
          register: health_check
          until: health_check.status == 200
          retries: 10
          delay: 5
      
      rescue:
        - name: Rollback on failure
          block:
            - name: Find latest backup
              ansible.builtin.find:
                paths: "{{ backup_dir }}"
                patterns: "app-*.tar.gz"
              register: backups
            
            - name: Restore from backup
              ansible.builtin.unarchive:
                src: "{{ (backups.files | sort(attribute='mtime') | last).path }}"
                dest: "{{ deploy_dir }}"
                remote_src: yes
            
            - name: Restart application
              ansible.builtin.systemd:
                name: myapp
                state: restarted
            
            - name: Fail deployment
              ansible.builtin.fail:
                msg: "Deployment failed and was rolled back"
      
      always:
        - name: Clean up temporary files
          ansible.builtin.file:
            path: "/tmp/myapp-{{ app_version }}.tar.gz"
            state: absent
```

### **3.3 CloudFormation - AWS Stack Examples**

#### **VPC Stack (vpc-stack.yaml)**
```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'VPC with public and private subnets across 2 AZs'

Parameters:
  EnvironmentName:
    Description: Environment name prefix
    Type: String
    Default: production
  
  VpcCIDR:
    Description: CIDR block for VPC
    Type: String
    Default: 10.0.0.0/16
  
  PublicSubnet1CIDR:
    Type: String
    Default: 10.0.1.0/24
  
  PublicSubnet2CIDR:
    Type: String
    Default: 10.0.2.0/24
  
  PrivateSubnet1CIDR:
    Type: String
    Default: 10.0.10.0/24
  
  PrivateSubnet2CIDR:
    Type: String
    Default: 10.0.20.0/24

Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCIDR
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-vpc

  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-igw

  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [0, !GetAZs '']
      CidrBlock: !Ref PublicSubnet1CIDR
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-public-subnet-1

  PublicSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [1, !GetAZs '']
      CidrBlock: !Ref PublicSubnet2CIDR
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-public-subnet-2

  PrivateSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [0, !GetAZs '']
      CidrBlock: !Ref PrivateSubnet1CIDR
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-private-subnet-1

  PrivateSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      AvailabilityZone: !Select [1, !GetAZs '']
      CidrBlock: !Ref PrivateSubnet2CIDR
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-private-subnet-2

  NatGateway1EIP:
    Type: AWS::EC2::EIP
    DependsOn: AttachGateway
    Properties:
      Domain: vpc

  NatGateway1:
    Type: AWS::EC2::NatGateway
    Properties:
      AllocationId: !GetAtt NatGateway1EIP.AllocationId
      SubnetId: !Ref PublicSubnet1

  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-public-routes

  DefaultPublicRoute:
    Type: AWS::EC2::Route
    DependsOn: AttachGateway
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  PublicSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PublicRouteTable
      SubnetId: !Ref PublicSubnet1

  PublicSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PublicRouteTable
      SubnetId: !Ref PublicSubnet2

  PrivateRouteTable1:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-private-routes-az1

  DefaultPrivateRoute1:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId: !Ref PrivateRouteTable1
      DestinationCidrBlock: 0.0.0.0/0
      NatGatewayId: !Ref NatGateway1

  PrivateSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PrivateRouteTable1
      SubnetId: !Ref PrivateSubnet1

  PrivateSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PrivateRouteTable1
      SubnetId: !Ref PrivateSubnet2

Outputs:
  VPC:
    Description: VPC ID
    Value: !Ref VPC
    Export:
      Name: !Sub ${EnvironmentName}-VPC

  PublicSubnets:
    Description: List of public subnet IDs
    Value: !Join [",", [!Ref PublicSubnet1, !Ref PublicSubnet2]]
    Export:
      Name: !Sub ${EnvironmentName}-PublicSubnets

  PrivateSubnets:
    Description: List of private subnet IDs
    Value: !Join [",", [!Ref PrivateSubnet1, !Ref PrivateSubnet2]]
    Export:
      Name: !Sub ${EnvironmentName}-PrivateSubnets
```

#### **Application Stack (app-stack.yaml)**
```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Web application with Auto Scaling and Load Balancer'

Parameters:
  EnvironmentName:
    Type: String
    Default: production
  
  InstanceType:
    Type: String
    Default: t3.medium
    AllowedValues:
      - t3.small
      - t3.medium
      - t3.large
  
  KeyName:
    Type: AWS::EC2::KeyPair::KeyName
    Description: EC2 Key Pair
  
  MinSize:
    Type: Number
    Default: 2
    Description: Minimum instances
  
  MaxSize:
    Type: Number
    Default: 6
    Description: Maximum instances
  
  DesiredCapacity:
    Type: Number
    Default: 2
    Description: Desired instances

Mappings:
  RegionAMI:
    us-east-1:
      AMI: ami-0c55b159cbfafe1f0
    us-west-2:
      AMI: ami-0d1cd67c26f5fca19

Resources:
  ALBSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: ALB Security Group
      VpcId:
        Fn::ImportValue: !Sub ${EnvironmentName}-VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-alb-sg

  WebServerSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Web Server Security Group
      VpcId:
        Fn::ImportValue: !Sub ${EnvironmentName}-VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          SourceSecurityGroupId: !Ref ALBSecurityGroup
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-web-sg

  ApplicationLoadBalancer:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    Properties:
      Name: !Sub ${EnvironmentName}-alb
      Subnets:
        Fn::Split:
          - ","
          - Fn::ImportValue: !Sub ${EnvironmentName}-PublicSubnets
      SecurityGroups:
        - !Ref ALBSecurityGroup
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-alb

  ALBListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      DefaultActions:
        - Type: forward
          TargetGroupArn: !Ref TargetGroup
      LoadBalancerArn: !Ref ApplicationLoadBalancer
      Port: 80
      Protocol: HTTP

  TargetGroup:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Properties:
      Name: !Sub ${EnvironmentName}-tg
      Port: 80
      Protocol: HTTP
      VpcId:
        Fn::ImportValue: !Sub ${EnvironmentName}-VPC
      HealthCheckEnabled: true
      HealthCheckProtocol: HTTP
      HealthCheckPath: /health
      HealthCheckIntervalSeconds: 30
      HealthCheckTimeoutSeconds: 5
      HealthyThresholdCount: 2
      UnhealthyThresholdCount: 3
      TargetType: instance

  LaunchTemplate:
    Type: AWS::EC2::LaunchTemplate
    Properties:
      LaunchTemplateName: !Sub ${EnvironmentName}-launch-template
      LaunchTemplateData:
        ImageId: !FindInMap [RegionAMI, !Ref "AWS::Region", AMI]
        InstanceType: !Ref InstanceType
        KeyName: !Ref KeyName
        SecurityGroupIds:
          - !Ref WebServerSecurityGroup
        IamInstanceProfile:
          Arn: !GetAtt InstanceProfile.Arn
        UserData:
          Fn::Base64: !Sub |
            #!/bin/bash
            yum update -y
            yum install -y httpd
            systemctl start httpd
            systemctl enable httpd
            echo "<h1>Hello from ${EnvironmentName}</h1>" > /var/www/html/index.html
            echo "OK" > /var/www/html/health
        TagSpecifications:
          - ResourceType: instance
            Tags:
              - Key: Name
                Value: !Sub ${EnvironmentName}-web-server

  AutoScalingGroup:
    Type: AWS::AutoScaling::AutoScalingGroup
    Properties:
      AutoScalingGroupName: !Sub ${EnvironmentName}-asg
      LaunchTemplate:
        LaunchTemplateId: !Ref LaunchTemplate
        Version: !GetAtt LaunchTemplate.LatestVersionNumber
      MinSize: !Ref MinSize
      MaxSize: !Ref MaxSize
      DesiredCapacity: !Ref DesiredCapacity
      VPCZoneIdentifier:
        Fn::Split:
          - ","
          - Fn::ImportValue: !Sub ${EnvironmentName}-PrivateSubnets
      TargetGroupARNs:
        - !Ref TargetGroup
      HealthCheckType: ELB
      HealthCheckGracePeriod: 300
      Tags:
        - Key: Name
          Value: !Sub ${EnvironmentName}-asg-instance
          PropagateAtLaunch: true

  ScaleUpPolicy:
    Type: AWS::AutoScaling::ScalingPolicy
    Properties:
      AdjustmentType: ChangeInCapacity
      AutoScalingGroupName: !Ref AutoScalingGroup
      Cooldown: 60
      ScalingAdjustment: 1

  ScaleDownPolicy:
    Type: AWS::AutoScaling::ScalingPolicy
    Properties:
      AdjustmentType: ChangeInCapacity
      AutoScalingGroupName: !Ref AutoScalingGroup
      Cooldown: 60
      ScalingAdjustment: -1

  CPUAlarmHigh:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmDescription: Scale up if CPU > 70%
      MetricName: CPUUtilization
      Namespace: AWS/EC2
      Statistic: Average
      Period: 300
      EvaluationPeriods: 2
      Threshold: 70
      AlarmActions:
        - !Ref ScaleUpPolicy
      Dimensions:
        - Name: AutoScalingGroupName
          Value: !Ref AutoScalingGroup
      ComparisonOperator: GreaterThanThreshold

  CPUAlarmLow:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmDescription: Scale down if CPU < 30%
      MetricName: CPUUtilization
      Namespace: AWS/EC2
      Statistic: Average
      Period: 300
      EvaluationPeriods: 2
      Threshold: 30
      AlarmActions:
        - !Ref ScaleDownPolicy
      Dimensions:
        - Name: AutoScalingGroupName
          Value: !Ref AutoScalingGroup
      ComparisonOperator: LessThanThreshold

  InstanceRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
        - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

  InstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Roles:
        - !Ref InstanceRole

Outputs:
  LoadBalancerURL:
    Description: URL of the Application Load Balancer
    Value: !GetAtt ApplicationLoadBalancer.DNSName
    Export:
      Name: !Sub ${EnvironmentName}-ALB-URL

  AutoScalingGroup:
    Description: Auto Scaling Group Name
    Value: !Ref AutoScalingGroup
```

---

## **Phase 4: Containers & Orchestration**

### **4.1 Docker - Multi-stage Builds & Optimization**

#### **Multi-stage Node.js Dockerfile**
```dockerfile
# Stage 1: Dependencies
FROM node:18-alpine AS dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && \
    npm cache clean --force

# Stage 2: Build
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build && \
    npm run test

# Stage 3: Production
FROM node:18-alpine AS production
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy dependencies from dependencies stage
COPY --from=dependencies /app/node_modules ./node_modules

# Copy built application
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --chown=nodejs:nodejs package*.json ./

# Security: Run as non-root
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD node healthcheck.js

# Start application
CMD ["node", "dist/server.js"]
```

#### **Optimized Python Dockerfile**
```dockerfile
# Stage 1: Builder
FROM python:3.11-slim AS builder

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

# Install runtime dependencies only
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Create non-root user
RUN useradd -m -u 1001 appuser && \
    chown -R appuser:appuser /app

# Copy Python packages from builder
COPY --from=builder /root/.local /home/appuser/.local

# Copy application code
COPY --chown=appuser:appuser . .

# Update PATH
ENV PATH=/home/appuser/.local/bin:$PATH

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "app:app"]
```

#### **Docker Compose for Development**
```yaml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: development
    ports:
      - "3000:3000"
    volumes:
      - .:/app
      - /app/node_modules
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://user:pass@db:5432/myapp
      - REDIS_URL=redis://cache:6379
    depends_on:
      db:
        condition: service_healthy
      cache:
        condition: service_started
    networks:
      - app-network

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: myapp
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app-network

  cache:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5
    networks:
      - app-network

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - app
    networks:
      - app-network

volumes:
  postgres-data:
  redis-data:

networks:
  app-network:
    driver: bridge
```

#### **.dockerignore**
```
node_modules
npm-debug.log
.git
.gitignore
.env
.DS_Store
*.md
.vscode
.idea
coverage
dist
build
.pytest_cache
__pycache__
*.pyc
```

### **4.2 Kubernetes - Deployments, Services & Ingress**

#### **Deployment (k8s/deployment.yaml)**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: production
  labels:
    app: web-app
    version: v1
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
        version: v1
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "9090"
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
      
      initContainers:
      - name: migration
        image: myapp:latest
        command: ['sh', '-c', 'npm run migrate']
        envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: app-secrets
      
      containers:
      - name: web-app
        image: myapp:latest
        imagePullPolicy: IfNotPresent
        
        ports:
        - name: http
          containerPort: 3000
          protocol: TCP
        - name: metrics
          containerPort: 9090
          protocol: TCP
        
        env:
        - name: NODE_ENV
          value: "production"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        
        envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: app-secrets
        
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        
        livenessProbe:
          httpGet:
            path: /health/live
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /health/ready
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        
        volumeMounts:
        - name: config
          mountPath: /app/config
          readOnly: true
        - name: cache
          mountPath: /app/cache
      
      volumes:
      - name: config
        configMap:
          name: app-config-files
      - name: cache
        emptyDir: {}
      
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - web-app
              topologyKey: kubernetes.io/hostname
```

#### **Service (k8s/service.yaml)**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app
  namespace: production
  labels:
    app: web-app
spec:
  type: ClusterIP
  selector:
    app: web-app
  ports:
  - name: http
    port: 80
    targetPort: http
    protocol: TCP
  - name: metrics
    port: 9090
    targetPort: metrics
    protocol: TCP
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 10800
```

#### **Ingress (k8s/ingress.yaml)**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-app-ingress
  namespace: production
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://example.com"
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls-cert
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-app
            port:
              number: 80
```

#### **ConfigMap (k8s/configmap.yaml)**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: production
data:
  LOG_LEVEL: "info"
  MAX_CONNECTIONS: "100"
  FEATURE_FLAG_NEW_UI: "true"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-files
  namespace: production
data:
  app-config.json: |
    {
      "server": {
        "port": 3000,
        "timeout": 30000
      },
      "database": {
        "pool": {
          "min": 2,
          "max": 10
        }
      }
    }
```

#### **Secret (k8s/secret.yaml)**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: production
type: Opaque
stringData:
  DATABASE_URL: "postgresql://user:password@db:5432/myapp"
  API_KEY: "your-secret-api-key"
  JWT_SECRET: "your-jwt-secret"
```

#### **HorizontalPodAutoscaler (k8s/hpa.yaml)**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
      - type: Pods
        value: 2
        periodSeconds: 30
      selectPolicy: Max
```

### **4.3 Helm Charts**

#### **Chart Structure**
```
helm-chart/
├── Chart.yaml
├── values.yaml
├── values-dev.yaml
├── values-prod.yaml
├── templates/
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── hpa.yaml
│   └── NOTES.txt
└── .helmignore
```

#### **Chart.yaml**
```yaml
apiVersion: v2
name: web-app
description: A Helm chart for web application
type: application
version: 1.0.0
appVersion: "1.0.0"
keywords:
  - web
  - nodejs
  - microservice
maintainers:
  - name: DevOps Team
    email: devops@example.com
dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
  - name: redis
    version: "17.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled
```

#### **values.yaml**
```yaml
replicaCount: 3

image:
  repository: myapp
  pullPolicy: IfNotPresent
  tag: "latest"

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations: {}
  name: ""

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1001
  fsGroup: 1001

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true

service:
  type: ClusterIP
  port: 80
  targetPort: 3000
  annotations: {}

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: app-tls
      hosts:
        - app.example.com

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - web-app
        topologyKey: kubernetes.io/hostname

config:
  logLevel: "info"
  maxConnections: 100

secrets:
  databaseUrl: ""
  apiKey: ""

postgresql:
  enabled: true
  auth:
    username: myapp
    password: changeme
    database: myapp

redis:
  enabled: true
  auth:
    enabled: false
```

#### **templates/deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "web-app.fullname" . }}
  labels:
    {{- include "web-app.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "web-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "web-app.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "web-app.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
      - name: {{ .Chart.Name }}
        securityContext:
          {{- toYaml .Values.securityContext | nindent 12 }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: {{ .Values.service.targetPort }}
          protocol: TCP
        env:
        - name: LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: {{ include "web-app.fullname" . }}
              key: logLevel
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: {{ include "web-app.fullname" . }}
              key: databaseUrl
        livenessProbe:
          httpGet:
            path: /health/live
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

#### **templates/_helpers.tpl**
```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "web-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "web-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "web-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "web-app.labels" -}}
helm.sh/chart: {{ include "web-app.chart" . }}
{{ include "web-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "web-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "web-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "web-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "web-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
```

#### **Helm Commands**
```bash
# Install chart
helm install myapp ./helm-chart -n production --create-namespace

# Install with custom values
helm install myapp ./helm-chart -f values-prod.yaml -n production

# Upgrade
helm upgrade myapp ./helm-chart -n production

# Rollback
helm rollback myapp 1 -n production

# Uninstall
helm uninstall myapp -n production

# Dry run
helm install myapp ./helm-chart --dry-run --debug

# Template rendering
helm template myapp ./helm-chart -f values-prod.yaml

# Package chart
helm package ./helm-chart

# Lint chart
helm lint ./helm-chart
```

---

## **Phase 5: Automation Scripts**

### **5.1 Advanced Bash Scripts**

#### **Deployment Script with Error Handling (deploy.sh)**
```bash
#!/bin/bash

#############################################
# Production Deployment Script
# Author: DevOps Team
# Description: Deploy application with rollback capability
#############################################

set -euo pipefail
IFS=\n\t'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/logs/deploy-$(date +%Y%m%d-%H%M%S).log"
readonly BACKUP_DIR="${SCRIPT_DIR}/backups"
readonly APP_DIR="/opt/myapp"
readonly APP_USER="appuser"
readonly MAX_RETRIES=3
readonly RETRY_DELAY=5

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Ensure log directory exists
mkdir -p "$(dirname "${LOG_FILE}")" "${BACKUP_DIR}"

#############################################
# Logging Functions
#############################################

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
    log "INFO" "$*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
    log "SUCCESS" "$*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
    log "WARNING" "$*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    log "ERROR" "$*"
}

#############################################
# Error Handling
#############################################

cleanup() {
    local exit_code=$?
    if [ ${exit_code} -ne 0 ]; then
        log_error "Deployment failed with exit code ${exit_code}"
        if [ "${BACKUP_CREATED:-false}" = true ]; then
            log_warning "Attempting rollback..."
            rollback || log_error "Rollback failed"
        fi
    fi
    exit ${exit_code}
}

trap cleanup EXIT
trap 'log_error "Script interrupted"; exit 130' INT TERM

#############################################
# Utility Functions
#############################################

check_root() {
    if [ "${EUID}" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_dependencies() {
    local dependencies=("curl" "tar" "systemctl" "jq")
    local missing=()
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "${dep}" &> /dev/null; then
            missing+=("${dep}")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        exit 1
    fi
}

retry() {
    local max_attempts=$1
    local delay=$2
    shift 2
    local command=("$@")
    local attempt=1
    
    while [ ${attempt} -le ${max_attempts} ]; do
        if "${command[@]}"; then
            return 0
        else
            log_warning "Attempt ${attempt}/${max_attempts} failed. Retrying in ${delay}s..."
            sleep "${delay}"
            ((attempt++))
        fi
    done
    
    log_error "Command failed after ${max_attempts} attempts"
    return 1
}

validate_version() {
    local version=$1
    if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid version format: ${version}. Expected: X.Y.Z"
        return 1
    fi
    return 0
}

#############################################
# Backup Functions
#############################################

create_backup() {
    log_info "Creating backup of current deployment..."
    
    local backup_file="${BACKUP_DIR}/app-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    if [ ! -d "${APP_DIR}" ]; then
        log_warning "Application directory does not exist. Skipping backup."
        return 0
    fi
    
    if tar czf "${backup_file}" -C "$(dirname ${APP_DIR})" "$(basename ${APP_DIR})"; then
        log_success "Backup created: ${backup_file}"
        BACKUP_FILE="${backup_file}"
        BACKUP_CREATED=true
        
        # Keep only last 5 backups
        ls -t "${BACKUP_DIR}"/app-*.tar.gz | tail -n +6 | xargs -r rm -f
        return 0
    else
        log_error "Failed to create backup"
        return 1
    fi
}

rollback() {
    log_warning "Starting rollback process..."
    
    if [ -z "${BACKUP_FILE:-}" ]; then
        log_error "No backup file available for rollback"
        return 1
    fi
    
    stop_application
    
    if tar xzf "${BACKUP_FILE}" -C "$(dirname ${APP_DIR})"; then
        log_success "Application restored from backup"
        start_application
        return 0
    else
        log_error "Rollback failed"
        return 1
    fi
}

#############################################
# Application Management
#############################################

stop_application() {
    log_info "Stopping application..."
    if systemctl stop myapp; then
        log_success "Application stopped"
        return 0
    else
        log_error "Failed to stop application"
        return 1
    fi
}

start_application() {
    log_info "Starting application..."
    if systemctl start myapp; then
        log_success "Application started"
        return 0
    else
        log_error "Failed to start application"
        return 1
    fi
}

reload_application() {
    log_info "Reloading application configuration..."
    if systemctl reload myapp; then
        log_success "Application reloaded"
        return 0
    else
        log_warning "Reload failed, attempting restart..."
        systemctl restart myapp
    fi
}

health_check() {
    local max_wait=60
    local elapsed=0
    local health_url="http://localhost:8080/health"
    
    log_info "Performing health check..."
    
    while [ ${elapsed} -lt ${max_wait} ]; do
        if curl -sf "${health_url}" > /dev/null 2>&1; then
            log_success "Health check passed"
            return 0
        fi
        sleep 2
        ((elapsed+=2))
    done
    
    log_error "Health check failed after ${max_wait}s"
    return 1
}

#############################################
# Deployment Functions
#############################################

download_artifact() {
    local version=$1
    local artifact_url="https://releases.example.com/myapp-${version}.tar.gz"
    local artifact_file="/tmp/myapp-${version}.tar.gz"
    
    log_info "Downloading artifact version ${version}..."
    
    if retry ${MAX_RETRIES} ${RETRY_DELAY} curl -fSL "${artifact_url}" -o "${artifact_file}"; then
        log_success "Artifact downloaded: ${artifact_file}"
        ARTIFACT_FILE="${artifact_file}"
        return 0
    else
        log_error "Failed to download artifact"
        return 1
    fi
}

verify_artifact() {
    local artifact=$1
    local checksum_url="${artifact}.sha256"
    
    log_info "Verifying artifact integrity..."
    
    if curl -fsSL "${checksum_url}" -o "${artifact}.sha256"; then
        if sha256sum -c "${artifact}.sha256" --quiet; then
            log_success "Artifact verification passed"
            return 0
        fi
    fi
    
    log_error "Artifact verification failed"
    return 1
}

deploy_artifact() {
    local artifact=$1
    
    log_info "Deploying artifact..."
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    
    # Extract artifact
    if ! tar xzf "${artifact}" -C "${temp_dir}"; then
        log_error "Failed to extract artifact"
        rm -rf "${temp_dir}"
        return 1
    fi
    
    # Deploy files
    if rsync -a --delete "${temp_dir}/" "${APP_DIR}/"; then
        log_success "Files deployed"
        chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"
        rm -rf "${temp_dir}"
        return 0
    else
        log_error "Failed to deploy files"
        rm -rf "${temp_dir}"
        return 1
    fi
}

run_migrations() {
    log_info "Running database migrations..."
    
    if sudo -u "${APP_USER}" "${APP_DIR}/bin/migrate"; then
        log_success "Migrations completed"
        return 0
    else
        log_error "Migrations failed"
        return 1
    fi
}

#############################################
# Main Deployment Flow
#############################################

main() {
    local version="${1:-}"
    
    log_info "========================================="
    log_info "Starting deployment process"
    log_info "========================================="
    
    # Validate input
    if [ -z "${version}" ]; then
        log_error "Usage: $0 <version>"
        exit 1
    fi
    
    validate_version "${version}" || exit 1
    
    # Pre-deployment checks
    check_root
    check_dependencies
    
    # Create backup
    create_backup || exit 1
    
    # Download and verify
    download_artifact "${version}" || exit 1
    verify_artifact "${ARTIFACT_FILE}" || exit 1
    
    # Stop application
    stop_application || exit 1
    
    # Deploy
    deploy_artifact "${ARTIFACT_FILE}" || exit 1
    
    # Run migrations
    run_migrations || exit 1
    
    # Start application
    start_application || exit 1
    
    # Health check
    health_check || exit 1
    
    # Cleanup
    rm -f "${ARTIFACT_FILE}" "${ARTIFACT_FILE}.sha256"
    
    log_success "========================================="
    log_success "Deployment completed successfully!"
    log_success "Version: ${version}"
    log_success "========================================="
}

# Execute main function
main "$@"
```

### **5.2 Python Automation Scripts**

#### **Cloud Resource Manager (cloud_manager.py)**
```python
#!/usr/bin/env python3
"""
Cloud Resource Management Script
Manages AWS EC2 instances, S3 buckets, and monitoring
"""

import sys
import logging
import argparse
import json
import time
from typing import List, Dict, Optional
from datetime import datetime
from pathlib import Path

import boto3
from botocore.exceptions import ClientError, BotoCoreError

# Configure logging
LOG_FORMAT = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
logging.basicConfig(
    level=logging.INFO,
    format=LOG_FORMAT,
    handlers=[
        logging.FileHandler(f'cloud_manager_{datetime.now():%Y%m%d}.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


class AWSResourceManager:
    """Manage AWS resources with error handling and retries"""
    
    def __init__(self, region: str = 'us-east-1', profile: Optional[str] = None):
        """Initialize AWS clients"""
        try:
            session = boto3.Session(
                profile_name=profile,
                region_name=region
            )
            self.ec2 = session.client('ec2')
            self.s3 = session.client('s3')
            self.cloudwatch = session.client('cloudwatch')
            self.region = region
            logger.info(f"Initialized AWS clients for region: {region}")
        except Exception as e:
            logger.error(f"Failed to initialize AWS clients: {e}")
            raise
    
    def retry_on_throttle(self, func, *args, max_retries: int = 5, **kwargs):
        """Retry function on throttling errors"""
        for attempt in range(max_retries):
            try:
                return func(*args, **kwargs)
            except ClientError as e:
                if e.response['Error']['Code'] == 'ThrottlingException':
                    wait_time = 2 ** attempt
                    logger.warning(f"Throttled. Retrying in {wait_time}s...")
                    time.sleep(wait_time)
                else:
                    raise
        raise Exception(f"Max retries ({max_retries}) exceeded")
    
    def list_instances(self, filters: Optional[List[Dict]] = None) -> List[Dict]:
        """List EC2 instances with optional filters"""
        try:
            params = {}
            if filters:
                params['Filters'] = filters
            
            response = self.retry_on_throttle(
                self.ec2.describe_instances,
                **params
            )
            
            instances = []
            for reservation in response['Reservations']:
                for instance in reservation['Instances']:
                    instances.append({
                        'id': instance['InstanceId'],
                        'type': instance['InstanceType'],
                        'state': instance['State']['Name'],
                        'launch_time': instance['LaunchTime'],
                        'tags': {
                            tag['Key']: tag['Value']
                            for tag in instance.get('Tags', [])
                        }
                    })
            
            logger.info(f"Found {len(instances)} instances")
            return instances
            
        except ClientError as e:
            logger.error(f"Failed to list instances: {e}")
            raise
    
    def start_instances(self, instance_ids: List[str]) -> bool:
        """Start EC2 instances"""
        try:
            logger.info(f"Starting instances: {instance_ids}")
            response = self.ec2.start_instances(InstanceIds=instance_ids)
            
            # Wait for instances to be running
            waiter = self.ec2.get_waiter('instance_running')
            waiter.wait(InstanceIds=instance_ids)
            
            logger.info("Instances started successfully")
            return True
            
        except ClientError as e:
            logger.error(f"Failed to start instances: {e}")
            return False
    
    def stop_instances(self, instance_ids: List[str]) -> bool:
        """Stop EC2 instances"""
        try:
            logger.info(f"Stopping instances: {instance_ids}")
            response = self.ec2.stop_instances(InstanceIds=instance_ids)
            
            # Wait for instances to be stopped
            waiter = self.ec2.get_waiter('instance_stopped')
            waiter.wait(InstanceIds=instance_ids)
            
            logger.info("Instances stopped successfully")
            return True
            
        except ClientError as e:
            logger.error(f"Failed to stop instances: {e}")
            return False
    
    def create_snapshot(self, volume_id: str, description: str) -> Optional[str]:
        """Create EBS volume snapshot"""
        try:
            logger.info(f"Creating snapshot for volume: {volume_id}")
            
            response = self.ec2.create_snapshot(
                VolumeId=volume_id,
                Description=description,
                TagSpecifications=[
                    {
                        'ResourceType': 'snapshot',
                        'Tags': [
                            {'Key': 'Name', 'Value': description},
                            {'Key': 'CreatedBy', 'Value': 'cloud_manager'},
                            {'Key': 'CreatedAt', 'Value': datetime.now().isoformat()}
                        ]
                    }
                ]
            )
            
            snapshot_id = response['SnapshotId']
            logger.info(f"Snapshot created: {snapshot_id}")
            
            # Wait for snapshot completion
            waiter = self.ec2.get_waiter('snapshot_completed')
            waiter.wait(SnapshotIds=[snapshot_id])
            
            logger.info("Snapshot completed")
            return snapshot_id
            
        except ClientError as e:
            logger.error(f"Failed to create snapshot: {e}")
            return None
    
    def get_instance_metrics(
        self,
        instance_id: str,
        metric_name: str,
        start_time: datetime,
        end_time: datetime
    ) -> List[Dict]:
        """Get CloudWatch metrics for an instance"""
        try:
            response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/EC2',
                MetricName=metric_name,
                Dimensions=[
                    {'Name': 'InstanceId', 'Value': instance_id}
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,  # 5 minutes
                Statistics=['Average', 'Maximum']
            )
            
            return sorted(
                response['Datapoints'],
                key=lambda x: x['Timestamp']
            )
            
        except ClientError as e:
            logger.error(f"Failed to get metrics: {e}")
            return []
    
    def cleanup_old_snapshots(self, days: int = 30) -> int:
        """Delete snapshots older than specified days"""
        try:
            logger.info(f"Cleaning up snapshots older than {days} days")
            
            response = self.ec2.describe_snapshots(OwnerIds=['self'])
            deleted_count = 0
            cutoff_date = datetime.now().timestamp() - (days * 86400)
            
            for snapshot in response['Snapshots']:
                snapshot_date = snapshot['StartTime'].timestamp()
                
                if snapshot_date < cutoff_date:
                    snapshot_id = snapshot['SnapshotId']
                    try:
                        self.ec2.delete_snapshot(SnapshotId=snapshot_id)
                        logger.info(f"Deleted snapshot: {snapshot_id}")
                        deleted_count += 1
                    except ClientError as e:
                        logger.warning(f"Failed to delete {snapshot_id}: {e}")
            
            logger.info(f"Deleted {deleted_count} snapshots")
            return deleted_count
            
        except ClientError as e:
            logger.error(f"Failed to cleanup snapshots: {e}")
            return 0
    
    def sync_s3_bucket(
        self,
        bucket: str,
        local_path: str,
        prefix: str = '',
        delete: bool = False
    ) -> bool:
        """Sync local directory to S3 bucket"""
        try:
            logger.info(f"Syncing {local_path} to s3://{bucket}/{prefix}")
            
            local_path = Path(local_path)
            if not local_path.exists():
                raise FileNotFoundError(f"Local path not found: {local_path}")
            
            uploaded_files = 0
            for file_path in local_path.rglob('*'):
                if file_path.is_file():
                    relative_path = file_path.relative_to(local_path)
                    s3_key = f"{prefix}/{relative_path}".lstrip('/')
                    
                    try:
                        self.s3.upload_file(
                            str(file_path),
                            bucket,
                            s3_key,
                            ExtraArgs={'ServerSideEncryption': 'AES256'}
                        )
                        uploaded_files += 1
                        logger.debug(f"Uploaded: {s3_key}")
                    except ClientError as e:
                        logger.error(f"Failed to upload {file_path}: {e}")
            
            logger.info(f"Uploaded {uploaded_files} files")
            return True
            
        except Exception as e:
            logger.error(f"Failed to sync S3 bucket: {e}")
            return False


class ResourceMonitor:
    """Monitor and report on resource usage"""
    
    def __init__(self, manager: AWSResourceManager):
        self.manager = manager
    
    def generate_cost_report(self, instance_ids: List[str]) -> Dict:
        """Generate cost estimation report"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'instances': [],
            'total_monthly_estimate': 0.0
        }
        
        # Simplified pricing (actual prices vary by region)
        pricing = {
            't3.micro': 0.0104,
            't3.small': 0.0208,
            't3.medium': 0.0416,
            't3.large': 0.0832
        }
        
        instances = self.manager.list_instances()
        
        for instance in instances:
            if instance['id'] in instance_ids:
                instance_type = instance['type']
                hourly_cost = pricing.get(instance_type, 0.0)
                monthly_cost = hourly_cost * 730  # Average hours per month
                
                report['instances'].append({
                    'id': instance['id'],
                    'type': instance_type,
                    'state': instance['state'],
                    'monthly_cost': round(monthly_cost, 2)
                })
                
                if instance['state'] == 'running':
                    report['total_monthly_estimate'] += monthly_cost
        
        report['total_monthly_estimate'] = round(
            report['total_monthly_estimate'], 2
        )
        
        return report
    
    def check_resource_utilization(self, instance_id: str) -> Dict:
        """Check CPU and memory utilization"""
        end_time = datetime.now()
        start_time = datetime.fromtimestamp(end_time.timestamp() - 3600)
        
        cpu_metrics = self.manager.get_instance_metrics(
            instance_id,
            'CPUUtilization',
            start_time,
            end_time
        )
        
        if cpu_metrics:
            avg_cpu = sum(m['Average'] for m in cpu_metrics) / len(cpu_metrics)
            max_cpu = max(m['Maximum'] for m in cpu_metrics)
        else:
            avg_cpu = max_cpu = 0.0
        
        return {
            'instance_id': instance_id,
            'average_cpu': round(avg_cpu, 2),
            'max_cpu': round(max_cpu, 2),
            'timestamp': datetime.now().isoformat()
        }


def main():
    """Main execution function"""
    parser = argparse.ArgumentParser(
        description='AWS Resource Management Tool'
    )
    parser.add_argument(
        '--region',
        default='us-east-1',
        help='AWS region'
    )
    parser.add_argument(
        '--profile',
        help='AWS profile name'
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # List instances
    list_parser = subparsers.add_parser('list', help='List instances')
    list_parser.add_argument('--filter', help='Filter by tag (key=value)')
    
    # Start instances
    start_parser = subparsers.add_parser('start', help='Start instances')
    start_parser.add_argument('instance_ids', nargs='+', help='Instance IDs')
    
    # Stop instances
    stop_parser = subparsers.add_parser('stop', help='Stop instances')
    stop_parser.add_argument('instance_ids', nargs='+', help='Instance IDs')
    
    # Snapshot
    snapshot_parser = subparsers.add_parser('snapshot', help='Create snapshot')
    snapshot_parser.add_argument('volume_id', help='Volume ID')
    snapshot_parser.add_argument('--description', required=True)
    
    # Cost report
    cost_parser = subparsers.add_parser('cost-report', help='Generate cost report')
    cost_parser.add_argument('instance_ids', nargs='+', help='Instance IDs')
    
    # Cleanup
    cleanup_parser = subparsers.add_parser('cleanup', help='Cleanup old snapshots')
    cleanup_parser.add_argument('--days', type=int, default=30)
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    try:
        manager = AWSResourceManager(
            region=args.region,
            profile=args.profile
        )
        monitor = ResourceMonitor(manager)
        
        if args.command == 'list':
            filters = None
            if args.filter:
                key, value = args.filter.split('=')
                filters = [{'Name': f'tag:{key}', 'Values': [value]}]
            
            instances = manager.list_instances(filters)
            print(json.dumps(instances, indent=2, default=str))
        
        elif args.command == 'start':
            manager.start_instances(args.instance_ids)
        
        elif args.command == 'stop':
            manager.stop_instances(args.instance_ids)
        
        elif args.command == 'snapshot':
            snapshot_id = manager.create_snapshot(
                args.volume_id,
                args.description
            )
            print(f"Snapshot ID: {snapshot_id}")
        
        elif args.command == 'cost-report':
            report = monitor.generate_cost_report(args.instance_ids)
            print(json.dumps(report, indent=2))
        
        elif args.command == 'cleanup':
            count = manager.cleanup_old_snapshots(args.days)
            print(f"Deleted {count} snapshots")
        
        return 0
        
    except Exception as e:
        logger.error(f"Command failed: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
```

### **5.3 Reusable Script Library**

#### **Common Functions Library (lib/common.sh)**
```bash
#!/bin/bash

# Common utility functions for shell scripts

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed"
    exit 1
fi

# Color codes
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR