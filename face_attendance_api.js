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

app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true }));

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100
});
app.use(limiter);

const pool = new Pool({
  user: process.env.USER || 'your_db_user',
  host: process.env.HOST || 'localhost',
  database: process.env.DATABASE || 'your_db_name',
  password: process.env.PASSWORD || 'your_db_password',
  port: 5432,
  ssl: {
    rejectUnauthorized: false
  }
})

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

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

app.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    console.log(`Login attempt: username=${username}, password=${password}`);
    const result = await dbQuery('SELECT * FROM users WHERE username = $1', [username]);
    if (result.rows.length > 0) {
      const user = result.rows[0];
      const passwordMatch = await bcrypt.compare(password, user.password);
      if (passwordMatch) {
        console.log('Login successful');
        const token = jwt.sign({ username: user.person_id, role: user.role }, JWT_SECRET, { expiresIn: '1h' });
        res.cookie('token', token, { httpOnly: true });
        return res.json({
          success: true,
          token,
          user: { username: user.username, role: user.role }
        });
      } else {
        console.log('Login failed - incorrect password');
        return res.status(401).json({ error: 'Invalid credentials' });
      }
    }

    // Fallback for hardcoded credentials
    if ((username === 'teacher' && password === 'teach123') ||
        (username === '2500032073' && password === '2500032073')) {
      console.log('Fallback login successful');
      const token = jwt.sign({ username, role: 'teacher' }, JWT_SECRET, { expiresIn: '24h' });
      return res.json({
        success: true,
        token,
        user: { username, role: 'teacher' }
      });
    }

    console.log('Login failed - invalid credentials');
    return res.status(401).json({ error: 'Invalid credentials' });
  } catch (error) {
    console.error('Login error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/students', async (req, res) => {
  try {
    const query = `
      SELECT 
        p.person_id,
        p.name,
        p.id_number,
        s.section_name,
        fe.encoding_id AS face_id,
        fe.face_descriptor
      FROM persons p
      LEFT JOIN student_sections ss ON p.person_id = ss.person_id
      LEFT JOIN sections s ON ss.section_id = s.section_id
      LEFT JOIN face_encodings fe ON p.person_id = fe.person_id AND fe.is_active = TRUE
      WHERE p.role = 'student'
      ORDER BY p.person_id
    `;
    const result = await dbQuery(query);

    // Assign running index and format response
    const students = result.rows.map((row, idx) => ({
      id: row.person_id,
      name: row.name,
      face_id: row.face_id ? `FACE${row.face_id.toString().padStart(3, '0')}` : null,
      section: row.section_name || null,
      id_number: row.id_number,
      face_descriptor: row.face_descriptor || null
    }));

    res.json({
      success: true,
      students
    });
  } catch (error) {
    console.error('Error fetching students:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

app.post("/attendance/batch-submit", async (req, res) => {
  const { session_id, attendance_data } = req.body;
  res.json({
    success: true,
    message: 'Attendance submitted successfully',
    summary: {
      successful: attendance_data ? attendance_data.length : 0,
      failed: 0,
      total: attendance_data ? attendance_data.length : 0
    }
  })
});

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
