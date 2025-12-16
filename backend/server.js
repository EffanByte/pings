const express = require('express');
const cors = require('cors');
const sqlite3 = require('sqlite3').verbose(); // Import standard sqlite3
const path = require('path');

const app = express();
const PORT = 8000;

// Middleware
app.use(cors());
app.use(express.json());

// Request logging
app.use((req, res, next) => {
  console.log(`\n${new Date().toISOString()} ${req.method} ${req.url}`);
  if (req.body && Object.keys(req.body).length > 0) {
    console.log('  📦 Body:', JSON.stringify(req.body));
  }
  next();
});

// ---------------------------------------------------------
// DATABASE SETUP & HELPERS
// ---------------------------------------------------------

const dbPath = path.join(__dirname, 'attendance.db');
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) console.error('Error opening database:', err.message);
  else console.log('Connected to SQLite database.');
});

// --- Promise Wrappers for Async SQLite3 ---
// These make the code look clean like better-sqlite3 using await

function dbRun(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function (err) {
      if (err) reject(err);
      // 'this' context refers to the statement object (lastID, changes)
      else resolve({ lastInsertRowid: this.lastID, changes: this.changes });
    });
  });
}

function dbGet(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.get(sql, params, (err, row) => {
      if (err) reject(err);
      else resolve(row);
    });
  });
}

function dbAll(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });
}

function dbExec(sql) {
  return new Promise((resolve, reject) => {
    db.exec(sql, (err) => {
      if (err) reject(err);
      else resolve();
    });
  });
}

// ---------------------------------------------------------
// INITIALIZATION (Tables & Seed)
// ---------------------------------------------------------

const initializeDatabase = async () => {
  try {
    // 1. Create Tables
    await dbExec(`
      CREATE TABLE IF NOT EXISTS teacher (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS course (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        title TEXT NOT NULL,
        teacher_id INTEGER NOT NULL,
        FOREIGN KEY (teacher_id) REFERENCES teacher(id)
      );

      CREATE TABLE IF NOT EXISTS student (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        falcon_public_key_b64 TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS enrollment (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        enrolled_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (course_id) REFERENCES course(id),
        FOREIGN KEY (student_id) REFERENCES student(id),
        UNIQUE(course_id, student_id)
      );

      CREATE TABLE IF NOT EXISTS sessionmodel (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_id INTEGER NOT NULL,
        teacher_id INTEGER NOT NULL,
        started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        ended_at DATETIME,
        FOREIGN KEY (course_id) REFERENCES course(id),
        FOREIGN KEY (teacher_id) REFERENCES teacher(id)
      );

      CREATE TABLE IF NOT EXISTS attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        student_id INTEGER NOT NULL,
        challenge_b64 TEXT NOT NULL,
        signature_b64 TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (session_id) REFERENCES sessionmodel(id),
        FOREIGN KEY (student_id) REFERENCES student(id)
      );
    `);

    // 2. Seed Data
    const teacherCount = await dbGet('SELECT count(*) as count FROM teacher');
    
    if (teacherCount.count === 0) {
      console.log('🌱 Seeding database with default data...');
      
      const teacherResult = await dbRun('INSERT INTO teacher (email, name) VALUES (?, ?)', ['instructor@example.com', 'Default Instructor']);
      const teacherId = teacherResult.lastInsertRowid;

      const courses = [
        ["CS101", "Introduction to Computer Science"],
        ["CS201", "Data Structures and Algorithms"],
        ["CS301", "Database Systems"],
        ["CS302", "Computer Networks"],
        ["CS401", "Operating Systems"],
        ["CS501", "Machine Learning"],
        ["CS601", "Computer Security"]
      ];

      for (const course of courses) {
        await dbRun('INSERT INTO course (code, title, teacher_id) VALUES (?, ?, ?)', [course[0], course[1], teacherId]);
      }
      console.log(`✅ Created 1 Teacher and ${courses.length} Courses.`);
    }
  } catch (error) {
    console.error("Initialization Error:", error);
  }
};

initializeDatabase();

// ---------------------------------------------------------
// API ROUTES
// ---------------------------------------------------------

// Health Check
app.get('/', (req, res) => res.json({ status: 'ok', service: 'ping-node-backend' }));

// 1. TEACHERS
app.post('/api/teachers', async (req, res) => {
  try {
    const { email, name } = req.body;
    const existing = await dbGet('SELECT * FROM teacher WHERE email = ?', [email]);
    if (existing) {
      return res.json(existing);
    }
    const result = await dbRun('INSERT INTO teacher (email, name) VALUES (?, ?)', [email, name]);
    res.json({ id: result.lastInsertRowid, email, name });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.get('/api/teachers/:teacher_id/courses', async (req, res) => {
  try {
    const courses = await dbAll('SELECT * FROM course WHERE teacher_id = ?', [req.params.teacher_id]);
    res.json(courses);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// 2. COURSES
app.get('/api/courses', async (req, res) => {
  try {
    const courses = await dbAll('SELECT * FROM course ORDER BY code');
    res.json(courses);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// 3. STUDENTS (Register)
app.post('/api/students/register', async (req, res) => {
  try {
    const { device_id, name, falcon_public_key_b64 } = req.body;
    
    const existing = await dbGet('SELECT * FROM student WHERE device_id = ?', [device_id]);
    if (existing) {
      await dbRun('UPDATE student SET name = ?, falcon_public_key_b64 = ? WHERE device_id = ?', [name, falcon_public_key_b64, device_id]);
      return res.json({ id: existing.id, device_id, name });
    }

    const result = await dbRun('INSERT INTO student (device_id, name, falcon_public_key_b64) VALUES (?, ?, ?)', [device_id, name, falcon_public_key_b64]);
    res.json({ id: result.lastInsertRowid, device_id, name });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// 3b. GET STUDENT by device_id
app.get('/api/students/:device_id', async (req, res) => {
  try {
    const student = await dbGet('SELECT id, device_id, name FROM student WHERE device_id = ?', [req.params.device_id]);
    if (!student) {
      return res.status(404).json({ error: 'Student not found' });
    }
    res.json(student);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// 4. ENROLLMENT
app.post('/api/enrollments', async (req, res) => {
  try {
    const { course_id, student_id } = req.body;
    
    // Try to insert
    try {
      const result = await dbRun('INSERT INTO enrollment (course_id, student_id) VALUES (?, ?)', [course_id, student_id]);
      res.json({ id: result.lastInsertRowid, course_id, student_id });
    } catch (err) {
      // If unique constraint failed (already enrolled), fetch existing
      const existing = await dbGet('SELECT * FROM enrollment WHERE course_id = ? AND student_id = ?', [course_id, student_id]);
      res.json(existing);
    }
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// 5. SESSIONS (Start)
app.post('/api/sessions', async (req, res) => {
  try {
    const { course_id, teacher_id } = req.body;

    const course = await dbGet('SELECT * FROM course WHERE id = ?', [course_id]);
    if (!course) return res.status(404).json({ error: "Course not found" });
    
    if (course.teacher_id !== teacher_id) {
      return res.status(400).json({ error: "Teacher does not own this course" });
    }

    const result = await dbRun('INSERT INTO sessionmodel (course_id, teacher_id) VALUES (?, ?)', [course_id, teacher_id]);
    const session = await dbGet('SELECT * FROM sessionmodel WHERE id = ?', [result.lastInsertRowid]);
    
    console.log(`✅ Session Started: ID ${session.id} for Course ${course.code}`);
    res.json(session);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// 6. ATTENDANCE (Mark)
app.post('/api/sessions/:session_id/attendance', async (req, res) => {
  try {
    const { device_id, challenge_b64, signature_b64 } = req.body;
    const sessionId = req.params.session_id;

    const student = await dbGet('SELECT * FROM student WHERE device_id = ?', [device_id]);
    if (!student) return res.status(404).json({ error: "Student not found" });

    const session = await dbGet('SELECT * FROM sessionmodel WHERE id = ?', [sessionId]);
    if (!session) return res.status(404).json({ error: "Session not found" });

    const enrollment = await dbGet('SELECT * FROM enrollment WHERE course_id = ? AND student_id = ?', [session.course_id, student.id]);
    if (!enrollment) return res.status(403).json({ error: "Student not enrolled in this course" });

    // Stub Verification
    const isValid = true; 
    if (!isValid) return res.status(400).json({ error: "Invalid Signature" });

    const result = await dbRun('INSERT INTO attendance (session_id, student_id, challenge_b64, signature_b64) VALUES (?, ?, ?, ?)', 
      [sessionId, student.id, challenge_b64, signature_b64]);

    const record = await dbGet(`
      SELECT a.*, s.name as student_name, c.code as course_code 
      FROM attendance a 
      JOIN student s ON a.student_id = s.id
      JOIN sessionmodel sm ON a.session_id = sm.id
      JOIN course c ON sm.course_id = c.id
      WHERE a.id = ?
    `, [result.lastInsertRowid]);

    res.json(record);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// 7. GET SESSION ATTENDANCE LIST
app.get('/api/sessions/:session_id/attendance', async (req, res) => {
  try {
    const list = await dbAll(`
      SELECT a.*, s.name as student_name, s.device_id
      FROM attendance a
      JOIN student s ON a.student_id = s.id
      WHERE a.session_id = ?
      ORDER BY a.created_at DESC
    `, [req.params.session_id]);
    res.json(list);
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// 8. END SESSION
app.post('/api/sessions/:session_id/end', async (req, res) => {
  try {
    await dbRun('UPDATE sessionmodel SET ended_at = CURRENT_TIMESTAMP WHERE id = ?', [req.params.session_id]);
    res.json({ status: "Session Ended" });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// Start Server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Node Backend running on port ${PORT}`);
});