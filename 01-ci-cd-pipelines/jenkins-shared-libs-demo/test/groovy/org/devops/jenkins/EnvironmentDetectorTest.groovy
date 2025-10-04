package org.devops.jenkins

import org.junit.Before
import org.junit.Test

class EnvironmentDetectorTest {
    
    EnvironmentDetector detector
    def mockSteps
    
    @Before
    void setUp() {
        mockSteps = [
            env: [:],
            echo: { String msg -> println msg },
            error: { String msg -> throw new Exception(msg) }
        ]
        
        detector = new EnvironmentDetector(mockSteps)
    }
    
    @Test
    void testDetectsDevEnvironment() {
        mockSteps.env.NODE_NAME = 'devnode-123'
        
        def result = detector.detect(
            [dev: ['devnode', 'testnode'], prod: ['prodnode']],
            [dev: [endpoint: 'dev-api'], prod: [endpoint: 'prod-api']]
        )
        
        assert result.environment == 'dev'
        assert result.endpoint == 'dev-api'
    }
    
    // Add more tests here
    @Test
    void testErrorWhenNoPatternMatches() {
        mockSteps.env.NODE_NAME = 'unknownnode-123'
        
        try {
            detector.detect(
                [dev: ['devnode', 'testnode'], prod: ['prodnode']],
                [dev: [endpoint: 'dev-api'], prod: [endpoint: 'prod-api']]
            )
            assert false // Should not reach here
        } catch (Exception e) {
            assert e.message.contains('does not match any configured patterns')
        }
    }
    @Test
    void testErrorMissingConfig() {
        mockSteps.env.NODE_NAME = 'devnode-123'
        
        try {
            detector.detect(
                [dev: ['devnode', 'testnode'], prod: ['prodnode']],
                [prod: [endpoint: 'prod-api']]
            )
            assert false // Should not reach here
        } catch (Exception e) {
            assert e.message.contains('Configuration not found for environment')
        }
    }
}