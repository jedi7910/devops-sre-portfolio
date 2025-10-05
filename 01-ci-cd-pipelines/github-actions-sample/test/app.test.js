const { add, detectEnvironment } = require('../src/app');

// Test 1: Addition
console.log('Testing add function...');
if (add(2, 3) !== 5) {
    console.error('❌ Addition test failed!');
    process.exit(1);
}
console.log('✅ Addition test passed');

// Test 2: Environment detection
console.log('Testing environment detection...');
const env = detectEnvironment();
console.log(`✅ Running in ${env} environment`);

console.log('\n✅ All tests passed!');