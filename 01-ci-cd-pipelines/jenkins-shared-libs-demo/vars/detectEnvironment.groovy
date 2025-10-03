def call(Map config) {
    def detector = new org.devops.jenkins.EnvironmentDetector(this)
    
    return detector.detect(
        config.nodePatterns,
        config.configs
    )
}