package org.devops.jenkins

import com.lesfurets.jenkins.unit.BasePipelineTest
import org.junit.Before
import org.junit.Test

class HostGathererTest extends BasePipelineTest {
    
    HostGatherer hostGatherer
    def mockShReturn
    
    @Before
    void setUp() {
        super.setUp()
        
        // Create a mock steps object with the sh method
        def mockSteps = [
            sh: { Map args ->
                return this.mockShReturn
            }
        ]
        
        hostGatherer = new HostGatherer(mockSteps)
    }
    
    @Test
    void testGetHostsReturnsListOfHosts() {
        this.mockShReturn = """
            host1.example.com
            host2.example.com
            host3.example.com
        """
        
        def hosts = hostGatherer.getHosts(
            'inventory/test.yaml',
            'webservers',
            { closure -> closure() }
        )
        
        assert hosts.size() == 3
        assert hosts[0] == 'host1.example.com'
        assert hosts[1] == 'host2.example.com'
        assert hosts[2] == 'host3.example.com'
    }
    
    @Test
    void testGetHostsHandlesEmptyOutput() {
        this.mockShReturn = ""
        
        def hosts = hostGatherer.getHosts(
            'inventory/test.yaml',
            'webservers',
            { closure -> closure() }
        )
        
        assert hosts.size() == 0
    }
}