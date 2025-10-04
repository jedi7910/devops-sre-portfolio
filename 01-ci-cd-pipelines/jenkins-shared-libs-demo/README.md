# Jenkins Shared Library - DevOps Utilities

A collection of reusable Jenkins pipeline components for common DevOps tasks.

## Table of Contents

- [Jenkins Shared Library - DevOps Utilities](#jenkins-shared-library---devops-utilities)
  - [Table of Contents](#table-of-contents)
  - [Installation](#installation)
  - [Components](#components)
    - [Host Gatherer](#host-gatherer)
    - [Environment Detector](#environment-detector)
  - [Error Handling](#error-handling)
  - [Example Usage](#example-usage)
  - [Testing](#testing)
  - [Contributing](#contributing)

## Installation

To use this library in Jenkins:

1. Add it as a Global Pipeline Library in Jenkins settings
2. Or configure it at the folder level in your Jenkins configuration
3. Reference it in your Jenkinsfile: `@Library('my-shared-lib') _`

## Components

### Host Gatherer

Gets a list of hosts from an Ansible inventory file for a specific group.

**Parameters:**
- `inventoryPath` (String) - Path to Ansible inventory file
- `groupName` (String) - Ansible group name to query
- `environmentWrapper` (Closure) - Environment setup wrapper

**Returns:** List of host strings

**Basic Usage:**
```groovy
def hosts = getHostsFromInventory(
    inventoryPath: 'inventory/hosts.yaml',
    groupName: 'webservers',
    environmentWrapper: { closure ->
        withPythonEnv('3.9') {
            closure()
        }
    }
)
```

**With Docker:**
```groovy
def hosts = getHostsFromInventory(
    inventoryPath: 'inventory/hosts.yaml',
    groupName: 'webservers',
    environmentWrapper: { closure ->
        docker.image('my-ansible-image:latest').inside {
            closure()
        }
    }
)
```

### Environment Detector
Detects which environment (dev, test, prod) the pipeline is running in based on Jenkins node name patterns.

**Parameters:**
- `nodePatterns` (Map) - Environment names mapped to node name patterns
- `configs` (Map) - Environment names mapped to configuration objects

**Returns:** Configuration map with `environment` key added

**Basic Usage:**
```groovy
def envConfig = detectEnvironment(
    nodePatterns: [
        dev: ['devnode', 'testnode'],
        prod: ['prodnode', 'prod-']
    ],
    configs: [
        dev: [
            endpoint: 'https://dev-api.example.com',
            credentialId: 'dev-creds'
        ],
        prod: [
            endpoint: 'https://api.example.com',
            credentialId: 'prod-creds'
        ]
    ]
)

echo "Environment: ${envConfig.environment}"
echo "Endpoint: ${envConfig.endpoint}"
```

## Error Handling
- Fails if code does not match any patterns
- Fails if no configuration exists for matched environment

## Example Usage

See `examples/Jenkinsfile.example` for a complete pipeline that demonstrates using both components together in a deployment scenario.

The example shows:
- Detecting environment based on Jenkins node
- Getting target hosts from Ansible inventory
- Using environment-specific configuration for deployment


## Testing

This library includes unit tests using JUnit and Groovy. To run tests:
```bash
./gradlew test
```
Tests are located in `/test/groovy/or/devops/jenkins` and cover:
- Host gathering with various outputs
- Environment detection with different node patterns
- Error handling for edge cases

## Contributing
- Class implementation in `src/org/devops/jenkins/`
- Pipeline wrapper in `vars/`
- Documentation in this `README`