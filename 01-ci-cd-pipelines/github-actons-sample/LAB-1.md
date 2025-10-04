# Lab 1: GitHub Actions Fundamentals

## Objective
Build your first GitHub Actions workflow and understand the core concepts. You'll translate some of your Jenkins shared library knowledge into GitHub Actions.

## Prerequisites
- Completed Jenkins Shared Library project
- GitHub account
- Basic understanding of YAML

## Background: Jenkins vs GitHub Actions

| Jenkins Concept | GitHub Actions Equivalent |
|----------------|---------------------------|
| Jenkinsfile | Workflow YAML file |
| Pipeline | Workflow |
| Stage | Job |
| Step | Step |
| Agent | Runner |
| Shared Library | Reusable Workflow / Action |

## Lab Setup

**Your Task**: Create the following structure in `01-ci-cd-pipelines/github-actions-sample/`:

```
github-actions-sample/
├── .github/
│   └── workflows/
│       └── test.yml
├── src/
│   └── app.js
├── test/
│   └── app.test.js
├── package.json
└── README.md
```

---

## Challenge 1: Your First Workflow

### Task 1.1: Create a Basic Test Workflow

Create `.github/workflows/test.yml` that:
1. Triggers on `push` and `pull_request` to `main` branch
2. Runs on `ubuntu-latest`
3. Has a job called `test`
4. Checks out the code
5. Prints "Hello from GitHub Actions"

**Try it yourself first!** Use the YAML structure you're familiar with from configs.

<details>
<summary>💡 Hint: Basic workflow structure</summary>

```yaml
name: ???

on:
  push:
    branches: [???]
  pull_request:
    branches: [???]

jobs:
  ???:
    runs-on: ???
    steps:
      - name: ???
        uses: ???
      
      - name: Print hello
        run: ???
```
</details>

<details>
<summary>✅ Solution</summary>

```yaml
name: Test Workflow

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Say hello
      run: echo "Hello from GitHub Actions"
```
</details>

---

## Challenge 2: Building a Node.js Test Pipeline

Remember your Jenkins tests with Gradle? Let's do something similar with Node.js.

### Task 2.1: Create a Simple Node.js App

Create `src/app.js`:
```javascript
function add(a, b) {
    return a + b;
}

function detectEnvironment() {
    return process.env.NODE_ENV || 'development';
}

module.exports = { add, detectEnvironment };
```

### Task 2.2: Create a Test File

Create `test/app.test.js`:
```javascript
const { add, detectEnvironment } = require('../src/app');

test('add function works', () => {
    if (add(2, 3) !== 5) {
        throw new Error('Addition failed!');
    }
    console.log('✓ Addition test passed');
});

test('environment detection', () => {
    const env = detectEnvironment();
    console.log(`✓ Running in ${env} environment`);
});

// Run tests
try {
    test('add function works', () => {});
    test('environment detection', () => {});
    console.log('\n✅ All tests passed!');
} catch (error) {
    console.error('\n❌ Tests failed:', error.message);
    process.exit(1);
}
```

### Task 2.3: Create package.json

```json
{
  "name": "github-actions-demo",
  "version": "1.0.0",
  "scripts": {
    "test": "node test/app.test.js"
  }
}
```

### Task 2.4: Update Your Workflow

**Your Challenge**: Modify `test.yml` to:
1. Setup Node.js (version 18)
2. Run `npm test`
3. Print the Node.js version being used

**Think about**: What's the equivalent of Jenkins' `tool` directive in GitHub Actions?

<details>
<summary>💡 Hint: Setup actions</summary>

Look for `actions/setup-node@v4` - it's similar to how you'd configure tools in Jenkins.
</details>

<details>
<summary>✅ Solution</summary>

```yaml
name: Test Workflow

on:
  push:
    branches: [main]
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
    
    - name: Display Node version
      run: node --version
      
    - name: Run tests
      run: npm test
```
</details>

---

## Challenge 3: Environment Detection (Like Your Jenkins Library!)

Remember your `detectEnvironment` function in Jenkins? Let's do something similar.

### Task 3.1: Create an Environment-Aware Workflow

Create `.github/workflows/deploy.yml` that:
1. Triggers on push to `main`, `develop`, or `staging` branches
2. Sets an environment variable based on the branch
3. Uses different configuration per environment

**Your Challenge**: Figure out how to:
- Detect which branch triggered the workflow
- Set environment-specific variables
- Print the detected environment

<details>
<summary>💡 Hint: GitHub Context</summary>

GitHub Actions provides `github.ref` which contains the branch name. You can use:
- `if` conditionals in steps
- `env` to set environment variables
- `${{ }}` syntax for expressions
</details>

<details>
<summary>✅ Solution</summary>

```yaml
name: Deploy

on:
  push:
    branches: [main, develop, staging]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Detect environment
      id: env
      run: |
        if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
          echo "environment=production" >> $GITHUB_OUTPUT
          echo "endpoint=https://api.example.com" >> $GITHUB_OUTPUT
        elif [[ "${{ github.ref }}" == "refs/heads/staging" ]]; then
          echo "environment=staging" >> $GITHUB_OUTPUT
          echo "endpoint=https://staging-api.example.com" >> $GITHUB_OUTPUT
        else
          echo "environment=development" >> $GITHUB_OUTPUT
          echo "endpoint=https://dev-api.example.com" >> $GITHUB_OUTPUT
        fi
    
    - name: Display detected environment
      run: |
        echo "Environment: ${{ steps.env.outputs.environment }}"
        echo "Endpoint: ${{ steps.env.outputs.endpoint }}"
    
    - name: Deploy (simulated)
      run: |
        echo "Deploying to ${{ steps.env.outputs.environment }}..."
        echo "Using endpoint: ${{ steps.env.outputs.endpoint }}"
```
</details>

---

## Questions to Consider

1. **Compare**: How is this environment detection different from your Jenkins `detectEnvironment`?
2. **Think**: What are the advantages/disadvantages of each approach?
3. **Extend**: How would you add error handling like you did in Jenkins?

---

## Verification Checklist

- [ ] Created `.github/workflows/test.yml`
- [ ] Workflow runs on push/PR
- [ ] Node.js tests execute successfully
- [ ] Created environment detection workflow
- [ ] Can explain the difference between jobs and steps
- [ ] Understand GitHub Actions context variables

---

## Next Steps

Once you complete this lab:
1. Commit your changes
2. Push to GitHub and watch the Actions run
3. Document what you learned in your README
4. Ready for **Lab 2: Reusable Workflows** (the GitHub Actions equivalent of your shared library!)

---

## Common Issues & Troubleshooting

**Issue**: Workflow doesn't trigger
- Check branch names match exactly
- Verify `.github/workflows/` path is correct

**Issue**: Tests fail
- Make sure `package.json` exists
- Check Node.js version compatibility

**Issue**: Environment detection wrong
- Verify branch name in `github.ref`
- Check conditional logic syntax

---

## Documentation Challenge

Before moving to Lab 2, create a `README.md` in `github-actions-sample/` that documents:
- What workflows you created
- How to trigger them
- What each workflow does
- Comparison with your Jenkins approach

Use the same style as your Jenkins shared library README!