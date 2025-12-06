"""Check the database state."""
from sqlmodel import Session, select
from main import Teacher, Course, engine

with Session(engine) as db:
    teacher = db.get(Teacher, 1)
    if teacher:
        print(f"Teacher: {teacher.name} (ID: {teacher.id}, Email: {teacher.email})")
    else:
        print("Teacher ID 1 not found")
    
    course = db.get(Course, 1)
    if course:
        print(f"Course: {course.code} - {course.title} (ID: {course.id}, Teacher ID: {course.teacher_id})")
    else:
        print("Course ID 1 not found")

