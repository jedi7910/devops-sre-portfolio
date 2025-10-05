# Lab 2: Reusable Workflows - GitHub Actions Shared Library

## Objective
Build reusable workflow components that can be called from multiple workflows - the GitHub Actions equivalent of your Jenkins shared library.

## Prerequisites
- Completed Lab 1
- Understanding of your Jenkins shared library concept
- Basic GitHub Actions workflow syntax

## Background: Jenkins Shared Library vs Reusable Workflows

| Jenkins Shared Library | GitHub Actions Reusable Workflows |
|------------------------|-----------------------------------|
| `vars/myFunction.groovy` | `.github/workflows/reusable-*.yml` |
| `@Library('my-lib')` | `uses: ./.github/workflows/reusable.yml` |
| Called with parameters | Called with `inputs:` and `secrets:` |
| Returns values | Provides `outputs:` |

Remember your Jenkins library? You had:
- `getHostsFromInventory()` - a reusable function
- `detectEnvironment()` - another reusable function
- Called from Jenkinsfile with parameters

Same concept here!

---

## Challenge 1: Your First Reusable Workflow

### Scenario:
You're tired of copying the same "setup and test" steps into every workflow. Let's make it reusable!

### Task 1.1: Create a Reusable Build Workflow

Create `.github/workflows/reusable-build.yml`:

**Requirements:**
1. Must be callable by other workflows (`workflow_call`)
2. Accept inputs: `node-version` (string, optional, default: '18')
3. Accept inputs: `run-tests` (boolean, optional, default: true)
4. Checkout code
5. Setup Node.js with specified version
6. Install dependencies
7. Optionally run tests (if `run-tests` is true)
8. Return output: `build-time` (timestamp when build completed)

**Your Challenge:** Write this workflow using the reference guide as help, but try it yourself first!

<details>
<summary>💡 Hint: Reusable Workflow Structure</summary>

```yaml
name: Reusable Build Workflow

on:
  workflow_call:
    inputs:
      # Define your inputs here
    outputs:
      # Define your outputs here

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      # Map job outputs to workflow outputs
    steps:
      # Your steps here
```
</details>

<details>
<summary>✅ Solution</summary>

```yaml
name: Reusable Build Workflow

on:
  workflow_call:
    inputs:
      node-version:
        description: 'Node.js version to use'
        required: false
        type: string
        default: '18'
      run-tests:
        description: 'Whether to run tests'
        required: false
        type: boolean
        default: true
      working-directory:
        description: 'Working directory for the app'
        required: false
        type: string
        default: './01-ci-cd-pipelines/github-actions-sample'
    outputs:
      build-time:
        description: 'Timestamp when build completed'
        value: ${{ jobs.build.outputs.build-time }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      build-time: ${{ steps.build-info.outputs.time }}
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
    
    - name: Install dependencies
      working-directory: ${{ inputs.working-directory }}
      run: npm ci || npm install
    
    - name: Run tests
      if: inputs.run-tests
      working-directory: ${{ inputs.working-directory }}
      run: npm test
    
    - name: Set build info
      id: build-info
      run: echo "time=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> $GITHUB_OUTPUT
```
</details>

---

## Challenge 2: Call Your Reusable Workflow

### Task 2.1: Create a Caller Workflow

Create `.github/workflows/use-reusable.yml` that:
1. Triggers on push to any branch
2. Calls your `reusable-build.yml` workflow
3. Uses Node.js version 20
4. Runs tests
5. Displays the build time after completion

**Try it yourself first!**

<details>
<summary>💡 Hint: Calling Reusable Workflows</summary>

```yaml
jobs:
  call-reusable:
    uses: ./.github/workflows/reusable-build.yml
    with:
      # Pass inputs here
```
</details>

<details>
<summary>✅ Solution</summary>

```yaml
name: Use Reusable Workflow

on: push

jobs:
  build:
    uses: ./.github/workflows/reusable-build.yml
    with:
      node-version: '20'
      run-tests: true
  
  display-results:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Show build time
        run: |
          echo "Build completed at: ${{ needs.build.outputs.build-time }}"
```
</details>

---

## Challenge 3: Reusable Deployment Workflow with Secrets

Remember how your Jenkins library handled credentials? Let's do the same!

### Task 3.1: Create Reusable Deploy Workflow

Create `.github/workflows/reusable-deploy.yml`:

**Requirements:**
1. Accept inputs: `environment` (string, required: 'dev', 'staging', 'prod')
2. Accept inputs: `app-name` (string, required)
3. Accept secrets: `deploy-token` (required)
4. Validate environment is one of the allowed values
5. Display deployment info
6. Simulate deployment (just echo for now)
7. Return output: `deployment-url`

**Challenge:** Add error handling like you did in Lab 1!

<details>
<summary>💡 Hint: Secrets in Reusable Workflows</summary>

```yaml
on:
  workflow_call:
    inputs:
      # inputs here
    secrets:
      deploy-token:
        required: true
```
</details>

<details>
<summary>✅ Solution</summary>

```yaml
name: Reusable Deploy Workflow

on:
  workflow_call:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: string
      app-name:
        description: 'Application name'
        required: true
        type: string
    secrets:
      deploy-token:
        description: 'Deployment token'
        required: true
    outputs:
      deployment-url:
        description: 'URL of deployed application'
        value: ${{ jobs.deploy.outputs.url }}

jobs:
  deploy:
    runs-on: ubuntu-latest
    outputs:
      url: ${{ steps.deploy-info.outputs.url }}
    
    steps:
    - name: Validate environment
      run: |
        VALID_ENVS="dev staging prod"
        if [[ ! " $VALID_ENVS " =~ " ${{ inputs.environment }} " ]]; then
          echo "::error::Invalid environment: ${{ inputs.environment }}"
          echo "::error::Allowed environments: $VALID_ENVS"
          exit 1
        fi
        echo "✅ Environment validation passed"
    
    - name: Set deployment URL
      id: deploy-info
      run: |
        if [[ "${{ inputs.environment }}" == "prod" ]]; then
          echo "url=https://${{ inputs.app-name }}.example.com" >> $GITHUB_OUTPUT
        else
          echo "url=https://${{ inputs.environment }}-${{ inputs.app-name }}.example.com" >> $GITHUB_OUTPUT
        fi
    
    - name: Deploy application
      env:
        DEPLOY_TOKEN: ${{ secrets.deploy-token }}
      run: |
        echo "🚀 Deploying ${{ inputs.app-name }} to ${{ inputs.environment }}"
        echo "📍 Target URL: ${{ steps.deploy-info.outputs.url }}"
        echo "🔑 Using token: ${DEPLOY_TOKEN:0:5}***"
        echo "✅ Deployment simulated successfully"
```
</details>

### Task 3.2: Call the Deploy Workflow

Update `.github/workflows/use-reusable.yml` to:
1. First call the build workflow
2. Then call the deploy workflow (only if build succeeds)
3. Pass environment based on branch:
   - `main` → `prod`
   - `develop` → `dev`
   - others → `staging`

<details>
<summary>✅ Solution</summary>

```yaml
name: Build and Deploy Pipeline

on: push

jobs:
  build:
    uses: ./.github/workflows/reusable-build.yml
    with:
      node-version: '20'
      run-tests: true
  
  set-environment:
    runs-on: ubuntu-latest
    outputs:
      environment: ${{ steps.env.outputs.environment }}
    steps:
      - name: Determine environment
        id: env
        run: |
          if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "environment=prod" >> $GITHUB_OUTPUT
          elif [[ "${{ github.ref }}" == "refs/heads/develop" ]]; then
            echo "environment=dev" >> $GITHUB_OUTPUT
          else
            echo "environment=staging" >> $GITHUB_OUTPUT
          fi
  
  deploy:
    needs: [build, set-environment]
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: ${{ needs.set-environment.outputs.environment }}
      app-name: 'myapp'
    secrets:
      deploy-token: ${{ secrets.DEPLOY_TOKEN }}
  
  display-results:
    needs: [build, deploy]
    runs-on: ubuntu-latest
    steps:
      - name: Show results
        run: |
          echo "✅ Build completed at: ${{ needs.build.outputs.build-time }}"
          echo "🚀 Deployed to: ${{ needs.deploy.outputs.deployment-url }}"
```
</details>

---

## Challenge 4: Matrix Strategy with Reusable Workflows

### Task 4.1: Test Across Multiple Versions

Create a workflow that calls your reusable build workflow for:
- Node.js versions: 18, 20, 22
- With and without tests

Use a **matrix strategy** to run all combinations!

<details>
<summary>💡 Hint: Matrix with Reusable Workflows</summary>

You CAN'T use matrix directly with `uses:`, but you can:
1. Create a regular job with matrix
2. That job's steps call the reusable workflow actions
OR
3. Call the reusable workflow multiple times with different inputs
</details>

<details>
<summary>✅ Solution</summary>

```yaml
name: Multi-Version Testing

on:
  push:
    branches: [main, develop]

jobs:
  test-node-18:
    uses: ./.github/workflows/reusable-build.yml
    with:
      node-version: '18'
      run-tests: true
  
  test-node-20:
    uses: ./.github/workflows/reusable-build.yml
    with:
      node-version: '20'
      run-tests: true
  
  test-node-22:
    uses: ./.github/workflows/reusable-build.yml
    with:
      node-version: '22'
      run-tests: true
  
  build-only:
    uses: ./.github/workflows/reusable-build.yml
    with:
      node-version: '20'
      run-tests: false
```
</details>

---

## Questions to Consider

### 1. Compare: Reusable Workflows vs Jenkins Shared Library

**Think about:**
- How is calling a reusable workflow different from calling a Jenkins shared library function?
- What are the advantages of each approach?
- Which feels more natural to you?

### 2. Outputs and Data Flow

**Consider:**
- In Jenkins, you could return values from functions. How do reusable workflows handle this?
- What are the limitations?
- How would you pass complex data between workflows?

### 3. Secrets Management

**Reflect:**
- How does secrets handling in reusable workflows compare to Jenkins credentials?
- Which approach is more secure?
- What are the trade-offs?

---

## Verification Checklist

- [ ] Created `reusable-build.yml`
- [ ] Created `reusable-deploy.yml`
- [ ] Created caller workflow that uses both
- [ ] Workflows accept inputs and return outputs
- [ ] Secrets are passed securely
- [ ] Error handling validates inputs
- [ ] Can explain how this is similar to Jenkins shared library

---

## Common Issues & Troubleshooting

**Issue**: Reusable workflow not found
- Check file path: `./.github/workflows/filename.yml`
- Ensure the reusable workflow is in the same repository
- Verify `on: workflow_call` is set

**Issue**: Secrets not working
- Secrets must be explicitly passed with `secrets:`
- Check secret name matches in GitHub Settings
- Remember: secrets aren't available in `workflow_call` triggers by default

**Issue**: Outputs not available
- Ensure outputs are defined at both job and workflow level
- Check the job name matches in the outputs mapping
- Verify step ID matches the output reference

---

## Next Steps

Once you complete Lab 2:
1. Update your README with reusable workflows documentation
2. Compare to your Jenkins shared library approach
3. Document lessons learned
4. Ready for **Lab 3: Multi-Stage Pipelines & Matrix Builds**

---

## Bonus Challenge (Optional)

**Create a reusable workflow library** with:
- `reusable-security-scan.yml` - runs security checks
- `reusable-quality-check.yml` - runs linting, formatting
- `reusable-notification.yml` - sends Slack/Discord notifications

Then create a master workflow that orchestrates all of them!
