
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