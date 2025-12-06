"""Initialize the database with a default teacher and course."""
from sqlmodel import Session, create_engine, select
from main import Teacher, Course, engine

def init_db():
    """Create a default teacher and course if they don't exist."""
    with Session(engine) as db:
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

        # Check if course with ID 1 exists
        course = db.get(Course, 1)
        if not course:
            course = Course(id=1, code="CS101", title="Introduction to Computer Science", teacher_id=1)
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

