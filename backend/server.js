
const express = require('express');
const cors = require('cors');
const Database = require('better-sqlite3');
const path = require('path');

const app = express();
const PORT = 8000;


// Get all courses (for students to browse)
app.get('/api/courses', (req, res) => {
  const courses = db.prepare('SELECT * FROM course ORDER BY code').all();
  res.json(courses);
});

// Middleware
app.use(cors());
app.use(express.json());

// Request logging middleware
app.use((req, res, next) => {
  console.log(`\n${new Date().toISOString()} ${req.method} ${req.url}`);
  if (req.body && Object.keys(req.body).length > 0) {
    console.log('  📦 Body:', JSON.stringify(req.body));
  }
  next();
});

// Database setup
const dbPath = path.join(__dirname, 'attendance.db');
const db = new Database(dbPath);

// Check if old sessionmodel table exists with wrong schema and drop it
try {
  const oldTableInfo = db.prepare("PRAGMA table_info(sessionmodel)").all();
  if (oldTableInfo.length > 0) {
    // Check if it has the old schema (course_code instead of course_id)
    const hasOldSchema = oldTableInfo.some(col => col.name === 'course_code');
    if (hasOldSchema) {
      console.log('⚠️  Old database schema detected. Migrating...');
      // Drop old tables that need migration
      db.exec(`
        DROP TABLE IF EXISTS attendance;
        DROP TABLE IF EXISTS sessionmodel;
      `);
      console.log('✓ Old tables dropped');
    }
  }
} catch (e) {
  // Table doesn't exist yet, that's fine
}

// Create tables if they don't exist
db.exec(`
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
    enrolled_at DATETIME DEFAULT CURRENT_TIMESTAMP,
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

  CREATE INDEX IF NOT EXISTS idx_student_device_id ON student(device_id);
  CREATE INDEX IF NOT EXISTS idx_enrollment_course_student ON enrollment(course_id, student_id);
`);

// Routes

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'ping-attendance-backend' });
});

// Create teacher
app.post('/api/teachers', (req, res) => {
  const { email, name } = req.body;
  if (!email || !name) {
    return res.status(400).json({ detail: 'Email and name are required' });
  }

  const existing = db.prepare('SELECT * FROM teacher WHERE email = ?').get(email);
  if (existing) {
    db.prepare('UPDATE teacher SET name = ? WHERE email = ?').run(name, email);
    return res.json({ id: existing.id, email: existing.email, name });
  }

  const result = db.prepare('INSERT INTO teacher (email, name) VALUES (?, ?)').run(email, name);
  res.json({ id: Number(result.lastInsertRowid), email, name });
});

// Create course
app.post('/api/courses', (req, res) => {
  const { code, title, teacher_id } = req.body;
  if (!code || !title || !teacher_id) {
    return res.status(400).json({ detail: 'Code, title, and teacher_id are required' });
  }

  const teacher = db.prepare('SELECT * FROM teacher WHERE id = ?').get(teacher_id);
  if (!teacher) {
    return res.status(404).json({ detail: 'Teacher not found' });
  }

  const result = db.prepare('INSERT INTO course (code, title, teacher_id) VALUES (?, ?, ?)')
    .run(code, title, teacher_id);
  res.json({ id: Number(result.lastInsertRowid), code, title, teacher_id });
});

// Get courses for a teacher
app.get('/api/teachers/:teacher_id/courses', (req, res) => {
  const teacherId = parseInt(req.params.teacher_id);
  const courses = db.prepare('SELECT * FROM course WHERE teacher_id = ? ORDER BY code').all(teacherId);
  res.json(courses);
});

// Get sessions for a course
app.get('/api/courses/:course_id/sessions', (req, res) => {
  const courseId = parseInt(req.params.course_id);
  const sessions = db.prepare(`
    SELECT s.*, c.code as course_code, c.title as course_title, t.name as teacher_name
    FROM sessionmodel s
    JOIN course c ON s.course_id = c.id
    JOIN teacher t ON s.teacher_id = t.id
    WHERE s.course_id = ?
    ORDER BY s.started_at DESC
  `).all(courseId);
  res.json(sessions);
});

// Register student
app.post('/api/students/register', (req, res) => {
  const { device_id, name, falcon_public_key_b64 } = req.body;
  if (!device_id || !name || !falcon_public_key_b64) {
    return res.status(400).json({ detail: 'device_id, name, and falcon_public_key_b64 are required' });
  }

  const existing = db.prepare('SELECT * FROM student WHERE device_id = ?').get(device_id);
  if (existing) {
    db.prepare('UPDATE student SET name = ?, falcon_public_key_b64 = ? WHERE device_id = ?')
      .run(name, falcon_public_key_b64, device_id);
    return res.json({ id: existing.id, device_id: existing.device_id, name });
  }

  const result = db.prepare('INSERT INTO student (device_id, name, falcon_public_key_b64) VALUES (?, ?, ?)')
    .run(device_id, name, falcon_public_key_b64);
  res.json({ id: Number(result.lastInsertRowid), device_id, name });
});

// Create enrollment
app.post('/api/enrollments', (req, res) => {
  const { course_id, student_id } = req.body;
  if (!course_id || !student_id) {
    return res.status(400).json({ detail: 'course_id and student_id are required' });
  }

  const course = db.prepare('SELECT * FROM course WHERE id = ?').get(course_id);
  if (!course) {
    return res.status(404).json({ detail: 'Course not found' });
  }

  const student = db.prepare('SELECT * FROM student WHERE id = ?').get(student_id);
  if (!student) {
    return res.status(404).json({ detail: 'Student not found' });
  }

  const existing = db.prepare('SELECT * FROM enrollment WHERE course_id = ? AND student_id = ?')
    .get(course_id, student_id);
  if (existing) {
    return res.json({
      id: existing.id,
      course_id: existing.course_id,
      student_id: existing.student_id,
      enrolled_at: existing.enrolled_at
    });
  }

  const result = db.prepare('INSERT INTO enrollment (course_id, student_id) VALUES (?, ?)')
    .run(course_id, student_id);
  const enrollment = db.prepare('SELECT * FROM enrollment WHERE id = ?')
    .get(result.lastInsertRowid);
  res.json({
    id: enrollment.id,
    course_id: enrollment.course_id,
    student_id: enrollment.student_id,
    enrolled_at: enrollment.enrolled_at
  });
});

// Create session
app.post('/api/sessions', (req, res) => {
  try {
    console.log('📥 POST /api/sessions - Body:', JSON.stringify(req.body));
    const { course_id, teacher_id } = req.body;
    
    if (!course_id || !teacher_id) {
      console.log('❌ Missing course_id or teacher_id');
      return res.status(400).json({ detail: 'course_id and teacher_id are required' });
    }

    const course = db.prepare('SELECT * FROM course WHERE id = ?').get(course_id);
    if (!course) {
      console.log(`❌ Course ${course_id} not found`);
      return res.status(404).json({ detail: 'Course not found' });
    }

    if (course.teacher_id !== teacher_id) {
      console.log(`❌ Teacher ${teacher_id} does not own course ${course_id} (owner is ${course.teacher_id})`);
      return res.status(400).json({ detail: 'Teacher does not own this course' });
    }

    const teacher = db.prepare('SELECT * FROM teacher WHERE id = ?').get(teacher_id);
    if (!teacher) {
      console.log(`❌ Teacher ${teacher_id} not found`);
      return res.status(404).json({ detail: 'Teacher not found' });
    }

    const result = db.prepare('INSERT INTO sessionmodel (course_id, teacher_id) VALUES (?, ?)')
      .run(course_id, teacher_id);
    const session = db.prepare('SELECT * FROM sessionmodel WHERE id = ?')
      .get(result.lastInsertRowid);
    
    console.log(`✅ Session created: id=${session.id}, course_id=${course_id}, teacher_id=${teacher_id}`);
    res.json({
      id: session.id,
      course_id: session.course_id,
      teacher_id: session.teacher_id,
      started_at: session.started_at,
      ended_at: session.ended_at
    });
  } catch (error) {
    console.error('💥 Error creating session:', error);
    res.status(500).json({ detail: error.message });
  }
});

// Submit attendance
app.post('/api/sessions/:session_id/attendance', (req, res) => {
  const sessionId = parseInt(req.params.session_id);
  const { device_id, challenge_b64, signature_b64, falcon_public_key_b64 } = req.body;

  if (!device_id || !challenge_b64 || !signature_b64) {
    return res.status(400).json({ detail: 'device_id, challenge_b64, and signature_b64 are required' });
  }

  const session = db.prepare('SELECT * FROM sessionmodel WHERE id = ?').get(sessionId);
  if (!session) {
    return res.status(404).json({ detail: 'Session not found' });
  }

  const course = db.prepare('SELECT * FROM course WHERE id = ?').get(session.course_id);
  if (!course) {
    return res.status(404).json({ detail: 'Course not found for session' });
  }

  const student = db.prepare('SELECT * FROM student WHERE device_id = ?').get(device_id);
  if (!student) {
    return res.status(404).json({ detail: 'Student not registered' });
  }

  // Check enrollment
  const enrollment = db.prepare('SELECT * FROM enrollment WHERE course_id = ? AND student_id = ?')
    .get(course.id, student.id);
  if (!enrollment) {
    return res.status(403).json({
      detail: 'Student is not enrolled in this course and cannot mark attendance'
    });
  }

  // TODO: Real Falcon signature verification
  // For now, stub always returns true
  const publicKey = falcon_public_key_b64 || student.falcon_public_key_b64;
  // verify_falcon_signature_stub(challenge_b64, signature_b64, publicKey) - stub always true

  // Record attendance
  const result = db.prepare(
    'INSERT INTO attendance (session_id, student_id, challenge_b64, signature_b64) VALUES (?, ?, ?, ?)'
  ).run(sessionId, student.id, challenge_b64, signature_b64);

  const attendance = db.prepare('SELECT * FROM attendance WHERE id = ?')
    .get(result.lastInsertRowid);

  res.json({
    student_name: student.name,
    device_id: student.device_id,
    course_code: course.code,
    course_title: course.title,
    challenge_b64: attendance.challenge_b64,
    signature_b64: attendance.signature_b64,
    created_at: attendance.created_at
  });
});

// List attendance
app.get('/api/sessions/:session_id/attendance', (req, res) => {
  const sessionId = parseInt(req.params.session_id);

  const session = db.prepare('SELECT * FROM sessionmodel WHERE id = ?').get(sessionId);
  if (!session) {
    return res.status(404).json({ detail: 'Session not found' });
  }

  const course = db.prepare('SELECT * FROM course WHERE id = ?').get(session.course_id);
  if (!course) {
    return res.status(404).json({ detail: 'Course not found for session' });
  }

  const rows = db.prepare(`
    SELECT a.*, s.name as student_name, s.device_id
    FROM attendance a
    JOIN student s ON a.student_id = s.id
    WHERE a.session_id = ?
    ORDER BY a.created_at DESC
  `).all(sessionId);

  const results = rows.map(row => ({
    student_name: row.student_name,
    device_id: row.device_id,
    course_code: course.code,
    course_title: course.title,
    challenge_b64: row.challenge_b64,
    signature_b64: row.signature_b64,
    created_at: row.created_at
  }));

  res.json(results);
});

// End session
app.post('/api/sessions/:session_id/end', (req, res) => {
  const sessionId = parseInt(req.params.session_id);

  const session = db.prepare('SELECT * FROM sessionmodel WHERE id = ?').get(sessionId);
  if (!session) {
    return res.status(404).json({ detail: 'Session not found' });
  }

  db.prepare('UPDATE sessionmodel SET ended_at = CURRENT_TIMESTAMP WHERE id = ?').run(sessionId);
  const updated = db.prepare('SELECT * FROM sessionmodel WHERE id = ?').get(sessionId);

  res.json({
    id: updated.id,
    course_id: updated.course_id,
    teacher_id: updated.teacher_id,
    started_at: updated.started_at,
    ended_at: updated.ended_at
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Ping Attendance Backend running on http://0.0.0.0:${PORT}`);
  console.log(`📱 Access from phone: http://10.7.108.93:${PORT}`);
  console.log(`🌐 Health check: http://localhost:${PORT}/`);
  console.log('\n✅ Server ready! Waiting for requests...\n');
});

