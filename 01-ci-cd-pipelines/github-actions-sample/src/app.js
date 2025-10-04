function add(a, b) {
    return a + b;
}

function detectEnvironment() {
    return process.env.NODE_ENV || 'development';
}

module.exports = { add, detectEnvironment };