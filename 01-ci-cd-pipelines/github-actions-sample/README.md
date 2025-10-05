
# GitHub Actions - CI/CD Workflows

Project to track setting up and testing CI using Github Actions workflows

## Workflows

### Test Workflow (test.yml)

Checks out code on main and feature branches, runs on ubuntu-latest, sets up Node.js and runs tests.

### Deploy Workflow (deploy.yml)  

Runs on all branches and pull requests to main using ubuntu-latest. Detects which environment branch is being pushed or merged (develop, stage, main, feature/*) and validates it against approved branches. If the branch is invalid, the workflow fails with a clear error message. Displays the detected environment and simulates a deployment.

## Key Features

### Environment Detection

It is important for users and developers to know if code is running in dev vs production because bad code or mishaps in a runaway script could cause a catastrophic outage in the real world.

### Error Handling

Error handling is handled in deploy.yml by referencing github.ref based on the branch being pushed. If the detected env is not one of the allowed branches it will fail as shown here :
```yaml
- name: Detect environment
        id: env
        run: |
          if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "environment=production" >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref }}" == "refs/heads/develop" ]]; then
            echo "environment=development" >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref }}" == "refs/heads/stage" ]]; then
            echo "environment=staging" >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref }}" == refs/heads/feature/* ]]; then
            echo "environment=feature" >> $GITHUB_OUTPUT
          else
            echo "::error::Unsupported branch: ${{ github.ref }}"
            echo "::error::Allowed branches are main, develop, stage, and feature/*"
            exit 1
          fi
```

## Comparison to Jenkins

GitHub Actions is significantly easier to work with than Jenkins:
- **YAML vs Groovy**: Simple YAML syntax instead of complex Groovy scripting
- **Branch-based detection**: Detects environment from Git branches vs Jenkins node names
- **No plugin management**: Uses marketplace actions instead of maintaining Jenkins plugins
- **Cloud-hosted**: No server infrastructure to maintain


## Usage

Workflows are located in `.github/workflows/` and trigger automatically:

- **test.yml**: Runs on pushes to `main` and `feature/*` branches
- **deploy.yml**: Runs on pushes to any branch and pull requests to `main`

### What Happens:
1. Code is checked out
2. Environment is detected based on branch name
3. For deploy.yml: validates branch is approved (main, develop, stage, feature/*)
4. Runs tests or simulated deployment
5. Displays results and detected environment

No manual configuration needed - workflows run automatically on push/PR.

