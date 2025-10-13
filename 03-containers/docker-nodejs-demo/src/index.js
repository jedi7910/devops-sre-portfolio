const express = require('express');
const { Client } = require('pg');
const redis = require('redis');

const app = express();
const PORT = process.env.PORT || 3000;

// PostgreSQL client
const pgClient = new Client({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'myapp',
  user: process.env.DB_USER || 'appuser',
  password: process.env.DB_PASSWORD || 'password'
});

// Redis client
const redisClient = redis.createClient({
  url: `redis://${process.env.REDIS_HOST || 'localhost'}:6379`
});

// Connect to databases
async function connectDatabases() {
  try {
    await pgClient.connect();
    console.log('✅ Connected to PostgreSQL');
    
    await redisClient.connect();
    console.log('✅ Connected to Redis');
  } catch (err) {
    console.error('❌ Database connection error:', err);
    process.exit(1);
  }
}

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    // Check Postgres
    await pgClient.query('SELECT 1');
    
    // Check Redis
    await redisClient.ping();
    
    res.status(200).json({ 
      status: 'healthy',
      postgres: 'connected',
      redis: 'connected'
    });
  } catch (err) {
    res.status(503).json({ 
      status: 'unhealthy',
      error: err.message 
    });
  }
});

// API endpoints
app.get('/', (req, res) => {
  res.json({ message: 'Docker Node.js Demo API' });
});

app.get('/users', async (req, res) => {
  try {
    const result = await pgClient.query('SELECT * FROM users');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Start server
async function start() {
  await connectDatabases();
  app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
  });
}

start();