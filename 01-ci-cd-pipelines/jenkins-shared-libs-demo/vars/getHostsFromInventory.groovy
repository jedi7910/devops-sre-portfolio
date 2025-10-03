def call(Map config) {
    def hostGatherer = new org.devops.jenkins.HostGatherer(this)
    
    return hostGatherer.getHosts(
        config.inventoryPath,
        config.groupName,
        config.environmentWrapper
    )
}