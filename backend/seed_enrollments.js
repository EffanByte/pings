const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'attendance.db');
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Error opening database:', err.message);
    process.exit(1);
  }
  console.log('Connected to SQLite database.');
});

// Promise wrappers
function dbRun(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function (err) {
      if (err) reject(err);
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

async function seedEnrollments() {
  try {
    console.log('\n📚 Starting Course & Enrollment Seeding...\n');

    // 1. Get all students
    const students = await dbAll('SELECT id, device_id, name FROM student');
    console.log(`✓ Found ${students.length} student(s)`);
    if (students.length === 0) {
      console.log('  (No students registered yet. Run the app signup flow first.)');
      return;
    }

    // 2. Get all courses
    const courses = await dbAll('SELECT id, code, title FROM course');
    console.log(`✓ Found ${courses.length} course(s)`);

    // 3. Get all teachers
    const teachers = await dbAll('SELECT id, email, name FROM teacher');
    console.log(`✓ Found ${teachers.length} teacher(s)`);

    if (courses.length === 0) {
      console.log('\n⚠️  No courses found. Seed the database first by running server.js.');
      return;
    }

    // 4. Enroll all students in all courses
    console.log('\n📝 Enrolling students in courses...');
    let enrollmentCount = 0;
    for (const student of students) {
      for (const course of courses) {
        try {
          await dbRun(
            'INSERT INTO enrollment (course_id, student_id) VALUES (?, ?)',
            [course.id, student.id]
          );
          enrollmentCount++;
        } catch (err) {
          // Ignore duplicate constraint errors
          if (!err.message.includes('UNIQUE')) throw err;
        }
      }
    }
    console.log(`✓ Created/verified ${enrollmentCount} student enrollment(s)`);

    // 5. Verify enrollments
    const totalEnrollments = await dbGet(
      'SELECT count(*) as count FROM enrollment'
    );
    console.log(`\n📊 Total enrollments in database: ${totalEnrollments.count}`);

    // 6. Print summary
    console.log('\n✅ Seeding Complete!');
    console.log(`\n   Students: ${students.length}`);
    console.log(`   Courses:  ${courses.length}`);
    console.log(`   Teachers: ${teachers.length}`);
    console.log(`   Total Enrollments: ${totalEnrollments.count}\n`);

    // 7. Print sample data
    console.log('📋 Sample Data:');
    console.log('   Students:');
    students.slice(0, 3).forEach(s => {
      console.log(`     - ${s.name} (${s.device_id})`);
    });
    if (students.length > 3) console.log(`     ... and ${students.length - 3} more`);

    console.log('\n   Courses:');
    courses.slice(0, 3).forEach(c => {
      console.log(`     - ${c.code}: ${c.title}`);
    });
    if (courses.length > 3) console.log(`     ... and ${courses.length - 3} more`);

  } catch (error) {
    console.error('❌ Error during seeding:', error);
  } finally {
    db.close((err) => {
      if (err) console.error(err);
      else console.log('\n🔒 Database connection closed.');
      process.exit(0);
    });
  }
}

seedEnrollments();
