package org.devops.jenkins

class EnvironmentDetector implements Serializable {
    
    def steps
    
    EnvironmentDetector(steps) {
        this.steps = steps
    }
    
    Map detect(Map nodePatterns, Map configs) {
        def currentNode = steps.env.NODE_NAME
        
        steps.echo "Detecting environment for node: ${currentNode}"
        
        // Find which environment matches
        def matchedEnv = findMatchingEnvironment(currentNode, nodePatterns)
        
        if (!matchedEnv) {
            steps.error("Unable to detect environment. Node '${currentNode}' does not match any configured patterns.")
        }
        
        steps.echo "Detected environment: ${matchedEnv}"
        
        // Get the config for this environment
        def config = configs[matchedEnv]
        
        if (!config) {
            steps.error("Configuration not found for environment: ${matchedEnv}")
        }
        
        // Add the environment name to the returned config
        return config + [environment: matchedEnv]
    }
    
    private String findMatchingEnvironment(String nodeName, Map nodePatterns) {
        for (entry in nodePatterns) {
            def envName = entry.key
            def patterns = entry.value
            
            for (pattern in patterns) {
                if (nodeName.contains(pattern)) {
                    return envName
                }
            }
        }
        return null
    }
}