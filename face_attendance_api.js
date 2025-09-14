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
  const attendance_data_obj = req.body.attendance_data;

  if (!attendance_data_obj || Object.keys(attendance_data_obj).length === 0) {
    return res.status(400).json({ success: false, message: "No attendance data provided" });
  }

  // Extract session_id (key of the object) and the student data
  const session_id = Object.keys(attendance_data_obj)[0];
  const students = attendance_data_obj[session_id];

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // Step 1: Get all person_ids in one query
    const idNumbers = students.map(s => s.idNumber);
    const personRows = await client.query(
      `SELECT person_id, id_number FROM persons 
       WHERE id_number = ANY($1::text[]) AND role = 'student'`,
      [idNumbers]
    );
    const personMap = new Map(personRows.rows.map(r => [r.id_number, r.person_id]));

    // Step 2: Build bulk insert for face_attendance
    const attendanceValues = [];
    const attendanceParams = [];
    let paramIndex = 1;

    for (const student of students) {
      const personId = personMap.get(student.idNumber);
      if (!personId) continue;

      // Compute stats
      const scores = student.confidenceScores;
      const confidenceAvg = scores.length ? scores.reduce((a,b)=>a+b,0)/scores.length : 0;
      const confidenceMin = scores.length ? Math.min(...scores) : 0;
      const confidenceMax = scores.length ? Math.max(...scores) : 0;
      const firstDetection = student.timestamps[0] || null;
      const lastDetection = student.timestamps.at(-1) || null;

      attendanceValues.push(
        `($${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, NOW())`
      );

      attendanceParams.push(
        null, // schedule_id -> NULL since we don't have a numeric schedule_id
        personId,
        session_id,
        student.detections, // detection_count
        confidenceAvg,
        confidenceMin,
        confidenceMax,
        firstDetection,
        lastDetection,
        student.status
      );
    }

    let insertedRows = [];
    if (attendanceValues.length > 0) {
      const attendanceQuery = `
        INSERT INTO face_attendance 
        (schedule_id, person_id, session_id, detection_count, confidence_avg, confidence_min, confidence_max, first_detection, last_detection, status, created_at)
        VALUES ${attendanceValues.join(", ")}
        ON CONFLICT (schedule_id, person_id, session_id)
        DO UPDATE SET 
          detection_count = EXCLUDED.detection_count,
          confidence_avg = EXCLUDED.confidence_avg,
          confidence_min = EXCLUDED.confidence_min,
          confidence_max = EXCLUDED.confidence_max,
          first_detection = EXCLUDED.first_detection,
          last_detection = EXCLUDED.last_detection,
          status = EXCLUDED.status
        RETURNING face_attendance_id, person_id;
      `;
      insertedRows = (await client.query(attendanceQuery, attendanceParams)).rows;
    }

    // Step 3: Bulk insert detection logs
    const logsValues = [];
    const logsParams = [];
    paramIndex = 1;

    for (const row of insertedRows) {
      const student = students.find(s => personMap.get(s.idNumber) === row.person_id);
      if (!student || student.confidenceScores.length === 0) continue;

      for (let i = 0; i < student.confidenceScores.length; i++) {
        logsValues.push(`($${paramIndex++}, $${paramIndex++}, $${paramIndex++})`);
        logsParams.push(row.face_attendance_id, student.confidenceScores[i], student.timestamps[i]);
      }
    }

    if (logsValues.length > 0) {
      await client.query(
        `INSERT INTO face_detection_logs (face_attendance_id, confidence_score, timestamp)
         VALUES ${logsValues.join(", ")}`,
        logsParams
      );
    }

    await client.query("COMMIT");
    res.json({
      success: true,
      message: "Attendance stored successfully",
      summary: {
        successful: insertedRows.length,
        failed: students.length - insertedRows.length,
        total: students.length
      }
    });

  } catch (error) {
    await client.query("ROLLBACK");
    console.error("Error inserting attendance:", error);
    res.status(500).json({ success: false, message: "Failed to store attendance" });
  } finally {
    client.release();
  }
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
