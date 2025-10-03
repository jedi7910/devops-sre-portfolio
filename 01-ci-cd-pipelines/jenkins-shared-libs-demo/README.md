# Jenkins Shared Library - DevOps Utilities

A collection of reusable Jenkins pipeline components for common DevOps tasks.

## Components

### Host Gatherer

Gets a list of hosts from an Ansible inventory file for a specific group.

#### Usage
```groovy
@Library('my-shared-lib') _

def hosts = getHostsFromInventory(
    inventoryPath: 'inventory/hosts.yaml',
    groupName: 'webservers',
    environmentWrapper: { closure ->
        withPythonEnv('3.9') {
            closure()
        }
    }
)

echo "Found ${hosts.size()} hosts: ${hosts.join(', ')}"
```
#### Parameters
- `inventoryPath`: Path to the Ansible inventory file. (String)
- `groupName` : Ansible group name query
- `environmentWrapper (Closure) : Environment setup wrapper

#### Returns
- List of hostnames (List<String>)

#### Examples with Different Environments
Using Docker:
```groovy
environmentWrapper: { closure ->
    docker.image('python:3.9-alpine').inside {
        closure()
    }
}
```

Direct Execution (if ansible already in PATH)
```groovy
environmentWrapper: { closure -> closure() }
```

### Setup
To use this library in Jenkins, add it as a Global Pipeline Library or configure it at the folder level in your Jenkins configuration.
Refer to the [Jenkins documentation](https://www.jenkins.io/doc/book/pipeline/shared-libraries/) for detailed instructions on setting up shared libraries.

