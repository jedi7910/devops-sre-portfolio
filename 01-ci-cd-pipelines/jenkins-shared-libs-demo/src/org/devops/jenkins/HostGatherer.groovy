package org.devops.jenkins

class HostGatherer implements Serializable {
    
    def steps
    
    HostGatherer(steps) {
        this.steps = steps
    }
    
    List<String> getHosts(String inventoryPath, String groupName, Closure environmentWrapper) {
        // Define the ansible command as a closure
        def ansibleCommand = {
            steps.sh(
                script: "ansible -i ${inventoryPath} --list-hosts ${groupName} 2>/dev/null | grep -v hosts",
                returnStdout: true
            ).trim()
        }
        
        // Execute the ansible command inside the provided environment wrapper
        def rawOutput = environmentWrapper(ansibleCommand)
        
        // Parse the output into a clean list
        return parseHostList(rawOutput)
    }
    
    private List<String> parseHostList(String rawOutput) {
        if (!rawOutput || rawOutput.isEmpty()) {
            return []
        }
        
        return rawOutput.split('\n')
            .collect { it.trim() }
            .findAll { it && !it.isEmpty() }
    }
}