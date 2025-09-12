const express = require('express');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100
});
app.use(limiter);

// PostgreSQL connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

// Authentication middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

// Utility function for database queries
const dbQuery = async (text, params) => {
  const client = await pool.connect();
  try {
    const result = await client.query(text, params);
    return result;
  } catch (error) {
    throw error;
  } finally {
    client.release();
  }
};

// Login endpoint
app.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    // Fallback authentication for demo
    if ((username === 'teacher' && password === 'teach123') || 
        (username === '2500032073' && password === '2500032073')) {
      const token = jwt.sign({ username, role: 'teacher' }, JWT_SECRET, { expiresIn: '24h' });
      return res.json({
        success: true,
        token,
        user: { username, role: 'teacher' }
      });
    }

    res.status(401).json({ error: 'Invalid credentials' });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all students
app.get('/students', (req, res) => {
  const students = [];
  for (let i = 1; i <= 80; i++) {
    students.push({
      id: i,
      name: `Student ${i.toString().padStart(2, '0')}`,
      face_id: `FACE${i.toString().padStart(3, '0')}`,
      section: `S${33 + Math.floor((i-1)/30)}`,
      id_number: `25000${(32000 + i).toString()}`
    });
  }

  res.json({
    success: true,
    students: students
  });
});

// Batch submit attendance
app.post('/attendance/batch-submit', (req, res) => {
  const { session_id, attendance_data } = req.body;

  res.json({
    success: true,
    message: 'Attendance submitted successfully',
    summary: {
      successful: attendance_data ? attendance_data.length : 0,
      failed: 0,
      total: attendance_data ? attendance_data.length : 0
    }
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    service: 'Face Recognition Attendance API'
  });
});

app.listen(PORT, () => {
  console.log(`🚀 Face Recognition Attendance API running on port ${PORT}`);
});

module.exports = app;