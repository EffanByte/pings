"""Initialize the database with a default teacher and course."""
from sqlmodel import Session, create_engine, select
from main import Teacher, Course, engine

def init_db():
    """Create a default teacher and course if they don't exist."""
    with Session(engine) as db:
        # Remove all existing courses to avoid duplicates
        from sqlalchemy import text
        db.exec(text("DELETE FROM course"))
        db.commit()

        # Check if teacher with ID 1 exists
        teacher = db.get(Teacher, 1)
        if not teacher:
            teacher = Teacher(id=1, email="instructor@example.com", name="Default Instructor")
            db.add(teacher)
            db.commit()
            db.refresh(teacher)
            print(f"✓ Created teacher: {teacher.name} (ID: {teacher.id})")
        else:
            print(f"✓ Teacher already exists: {teacher.name} (ID: {teacher.id})")

        # Add multiple unique courses
        courses_data = [
            (1, "CS101", "Introduction to Computer Science", 1),
            (2, "CS201", "Data Structures and Algorithms", 1),
            (3, "CS301", "Database Systems", 1),
            (4, "CS302", "Computer Networks", 1),
            (5, "CS401", "Operating Systems", 1),
            (6, "CS402", "Software Engineering", 1),
            (7, "CS501", "Machine Learning", 1),
            (8, "CS502", "Artificial Intelligence", 1),
            (9, "CS601", "Computer Security", 1),
            (10, "CS602", "Distributed Systems", 1),
            (11, "CS701", "Advanced Algorithms", 1),
            (12, "CS702", "Cloud Computing", 1),
            (13, "CS801", "Quantum Computing", 1),
            (14, "CS802", "Natural Language Processing", 1),
            (15, "CS803", "Computer Vision", 1),
            (16, "CS804", "Robotics", 1),
            (17, "CS805", "Cyber-Physical Systems", 1),
            (18, "CS806", "Blockchain Technologies", 1),
            (19, "CS807", "Augmented Reality", 1),
            (20, "CS808", "Edge Computing", 1),
        ]
        for course_id, code, title, teacher_id in courses_data:
            course = db.exec(select(Course).where(Course.code == code)).first()
            if not course:
                course = Course(id=course_id, code=code, title=title, teacher_id=teacher_id)
                db.add(course)
                db.commit()
                db.refresh(course)
                print(f"✓ Created course: {course.code} - {course.title} (ID: {course.id})")
            else:
                print(f"✓ Course already exists: {course.code} - {course.title} (ID: {course.id})")

if __name__ == "__main__":
    print("Initializing database...")
    init_db()
    print("Done!")

