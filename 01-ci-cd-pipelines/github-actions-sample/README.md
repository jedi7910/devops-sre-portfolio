# GitHub Actions - CI/CD Workflows

A collection of reusable GitHub Actions workflows for automated build, test, and deployment processes. This project demonstrates modern CI/CD patterns using GitHub Actions reusable workflows - similar in concept to Jenkins shared libraries but implemented with simple, composable YAML files.

## Table of Contents

- [GitHub Actions - CI/CD Workflows](#github-actions---cicd-workflows)
  - [Table of Contents](#table-of-contents)
  - [Workflows](#workflows)
    - [Build and Deploy Pipeline (use-reusable.yml)](#build-and-deploy-pipeline-use-reusableyml)
  - [Reusable Workflows](#reusable-workflows)
    - [Reusable Build (reusable-build.yml)](#reusable-build-reusable-buildyml)
    - [Reusable Deploy (reusable-deploy.yml)](#reusable-deploy-reusable-deployyml)
  - [Key Features](#key-features)
    - [Environment Detection](#environment-detection)
  - [Matrix Testing Configuration](#matrix-testing-configuration)
    - [Customizing Version Matrix](#customizing-version-matrix)
    - [Error Handling](#error-handling)
    - [Reusable Components](#reusable-components)
  - [Comparison to Jenkins](#comparison-to-jenkins)
  - [Usage](#usage)
    - [Main Pipeline (use-reusable.yml)](#main-pipeline-use-reusableyml)
    - [Workflow Execution Flow](#workflow-execution-flow)
    - [Calling Reusable Workflows](#calling-reusable-workflows)
    - [Monitoring Workflow Runs](#monitoring-workflow-runs)

## Workflows

### Build and Deploy Pipeline (use-reusable.yml)

The main orchestration workflow that coordinates the complete CI/CD process. This workflow demonstrates how to compose multiple reusable workflows into a complete pipeline.

**Triggers:**
- Pull requests to `main` branch
- Direct pushes to `main` branch

**Jobs:**
1. **Build** - Calls reusable build workflow to compile and test the application
2. **Set Environment** - Detects target environment based on Git branch
3. **Deploy** - Calls reusable deploy workflow with environment-specific configuration
4. **Display Results** - Shows build time and deployment URL

**Flow:**
```
PR/Push → Build (test) → Detect Environment → Deploy → Display Results
```

## Reusable Workflows

### Reusable Build (reusable-build.yml)

A reusable workflow component for building and testing Node.js applications. Can be called from any workflow in the repository.

**Purpose:** Standardizes the build and test process across multiple workflows, ensuring consistency and reducing duplication.

**Inputs:**

- `node-versions` (string, optional, default: '["16", "18", "20"]') - Node.js versions to test (JSON array)
- `run-tests` (boolean, optional, default: true) - Whether to execute test suite
- `working-directory` (string, optional, default: './01-ci-cd-pipelines/github-actions-sample') - Directory containing the application

**Outputs:**
- `build-time` (string) - ISO 8601 timestamp of when the build completed

**Usage Example:**
```yaml
jobs:
  build:
    uses: ./.github/workflows/reusable-build.yml
    with:
      node-version: '20'
      run-tests: true
```

### Reusable Deploy (reusable-deploy.yml)

A reusable workflow component for deploying applications to different environments with validation and security.

**Purpose:** Provides a standardized deployment process with environment validation, secret handling, and deployment URL generation.

**Inputs:**
- `environment` (string, required) - Target environment: must be 'prod', 'stage', or 'dev'
- `app-name` (string, required) - Name of the application being deployed

**Secrets:**
- `deploy-token` (required) - Authentication token for deployment operations

**Outputs:**
- `deployment-url` (string) - URL where the application was deployed

**Environment URL Mapping:**
- `prod` → `https://app-name.example.com`
- `stage` → `https://stage-app-name.example.com`
- `dev` → `https://dev-app-name.example.com`

**Usage Example:**
```yaml
jobs:
  deploy:
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: 'prod'
      app-name: 'myapp'
    secrets:
      deploy-token: ${{ secrets.DEPLOY_TOKEN }}
```

## Key Features

### Environment Detection

Automatically detects the target deployment environment based on the Git branch being built. This prevents accidental deployments to production and ensures code flows through proper promotion paths.

**Branch to Environment Mapping:**
- `main` branch → `prod` environment
- `develop` branch → `dev` environment
- All other branches → `stage` environment

**Why This Matters:** Deploying untested code to production or running production code in development environments can cause catastrophic outages, data corruption, or security vulnerabilities. Automatic environment detection ensures code is always deployed to the appropriate environment based on the branch strategy.

## Matrix Testing Configuration

The build workflow tests across multiple dimensions by default:
- **Operating Systems:** Ubuntu, Windows, macOS
- **Node.js Versions:** 16, 18, 20
- **Total Jobs:** 9 parallel test runs (with exclusions: 8 actual jobs)

### Customizing Version Matrix

Override the default version matrix for specific projects:

```yaml
build:
  uses: ./.github/workflows/reusable-build.yml
  with:
    node-versions: '["18", "20"]'  # Test only LTS versions
    run-tests: true
```

Or use defaults to test all supported versions:

```yaml
build:
  uses: ./.github/workflows/reusable-build.yml
  with:
    run-tests: true  # Tests Node 16, 18, 20 automatically
```

### Error Handling

The reusable deploy workflow includes strict environment validation that fails fast if an invalid environment is specified.

**Validation Logic:**
```yaml
- name: Validate Environment
  run: |
    VALID_ENVS=("prod" "stage" "dev")
    if [[ ! " ${VALID_ENVS[@]} " =~ " ${{ inputs.environment }} " ]]; then
      echo "::error::Invalid environment: ${{ inputs.environment }}"
      echo "::error::Allowed environments: ${VALID_ENVS[*]}"
      exit 1
    fi
    echo "✅ Environment validation passed"
```

**Benefits:**
- Fails immediately with clear error message
- Prevents deployment to misconfigured or non-existent environments
- Uses GitHub Actions error annotations for visibility
- Provides explicit list of allowed environments

### Reusable Components

This project implements the reusable workflow pattern, which is conceptually similar to Jenkins shared libraries but simpler to implement and maintain.

**Key Advantages:**
- **DRY Principle** - Write build/deploy logic once, use it everywhere
- **Consistency** - All projects use the same tested workflows
- **Maintainability** - Update workflow logic in one place
- **Composability** - Combine reusable workflows to create complex pipelines
- **Version Control** - Workflows are versioned alongside code

**Comparison to Jenkins Shared Libraries:**
- No Groovy scripting required - just YAML
- No separate library repository needed
- Works with GitHub's native secrets management
- Simpler syntax and easier debugging

## Comparison to Jenkins

GitHub Actions provides significant advantages over traditional Jenkins pipelines:

- **YAML vs Groovy**: Simple, declarative YAML syntax instead of complex Groovy scripting
- **Branch-based detection**: Detects environment from Git branches instead of relying on Jenkins node name patterns
- **No plugin management**: Uses marketplace actions instead of maintaining a fragile plugin ecosystem
- **Cloud-hosted**: No server infrastructure to provision, patch, or maintain
- **Reusable workflows**: Similar concept to Jenkins shared libraries but implemented as simple YAML files that can call each other

**When Jenkins Still Makes Sense:**
- On-premise deployment requirements
- Complex enterprise integrations with legacy systems
- Specific regulatory or compliance requirements
- Existing large-scale Jenkins infrastructure with hundreds of jobs

## Usage

All workflows are located in `.github/workflows/` and trigger automatically based on Git events.

### Main Pipeline (use-reusable.yml)

**Triggers:**
- Automatically on pull requests to `main`
- Automatically on pushes to `main`

**Prerequisites:**
- Repository secret `DEPLOY_TOKEN` must be configured in Settings → Secrets and variables → Actions

**What Happens:**
1. Code is checked out from the repository
2. Application is built using Node.js 20
3. Test suite is executed
4. Target environment is determined based on branch name
5. Environment is validated against allowed list
6. Application is deployed with appropriate configuration
7. Build time and deployment URL are displayed

**Setting Up Secrets:**
1. Navigate to repository Settings
2. Select "Secrets and variables" → "Actions"
3. Click "New repository secret"
4. Name: `DEPLOY_TOKEN`
5. Value: Your deployment authentication token
6. Click "Add secret"

### Workflow Execution Flow

```
┌─────────────────────┐
│   Push/PR to main   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Reusable Build    │
│  - Setup Node.js    │
│  - Install deps     │
│  - Run tests        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Detect Environment │
│  - Check branch     │
│  - Map to env       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Reusable Deploy    │
│  - Validate env     │
│  - Set URL          │
│  - Deploy app       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Display Results   │
│  - Build time       │
│  - Deployment URL   │
└─────────────────────┘
```

### Calling Reusable Workflows

To use these reusable workflows in other projects or workflows:

```yaml
jobs:
  my-build:
    uses: ./.github/workflows/reusable-build.yml
    with:
      node-version: '20'
      run-tests: true
      working-directory: './my-app'
  
  my-deploy:
    needs: my-build
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: 'prod'
      app-name: 'my-application'
    secrets:
      deploy-token: ${{ secrets.MY_DEPLOY_TOKEN }}
```

### Monitoring Workflow Runs

1. Navigate to the "Actions" tab in the GitHub repository
2. Select a workflow run to view details
3. Click on individual jobs to see step-by-step execution logs
4. Check outputs in the "Display Results" job for build time and deployment URL

No manual configuration or intervention is required - workflows run automatically on push/PR events.
