from datetime import datetime
from typing import List, Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlmodel import Field, SQLModel, Session, create_engine, select


# ---------- Data models ----------


class Teacher(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    email: str = Field(index=True, unique=True)
    name: str


class Course(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    code: str = Field(index=True)
    title: str
    teacher_id: int = Field(foreign_key="teacher.id", index=True)


class Student(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    device_id: str = Field(index=True, unique=True)
    name: str
    falcon_public_key_b64: str


class Enrollment(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    course_id: int = Field(foreign_key="course.id", index=True)
    student_id: int = Field(foreign_key="student.id", index=True)
    enrolled_at: datetime = Field(default_factory=datetime.utcnow)


class SessionModel(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    course_id: int = Field(foreign_key="course.id", index=True)
    teacher_id: int = Field(foreign_key="teacher.id", index=True)
    started_at: datetime = Field(default_factory=datetime.utcnow)
    ended_at: Optional[datetime] = None


class Attendance(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    session_id: int = Field(foreign_key="sessionmodel.id", index=True)
    student_id: int = Field(foreign_key="student.id", index=True)
    challenge_b64: str
    signature_b64: str
    created_at: datetime = Field(default_factory=datetime.utcnow)


# ---------- Pydantic schemas ----------


class RegisterStudentRequest(SQLModel):
    device_id: str
    name: str
    falcon_public_key_b64: str


class StudentResponse(SQLModel):
    id: int
    device_id: str
    name: str


class CreateTeacherRequest(SQLModel):
    email: str
    name: str


class TeacherResponse(SQLModel):
    id: int
    email: str
    name: str


class CreateCourseRequest(SQLModel):
    code: str
    title: str
    teacher_id: int


class CourseResponse(SQLModel):
    id: int
    code: str
    title: str
    teacher_id: int


class EnrollmentRequest(SQLModel):
    course_id: int
    student_id: int


class EnrollmentResponse(SQLModel):
    id: int
    course_id: int
    student_id: int
    enrolled_at: datetime


class CreateSessionRequest(SQLModel):
    course_id: int
    teacher_id: int


class SessionResponse(SQLModel):
    id: int
    course_id: int
    teacher_id: int
    started_at: datetime
    ended_at: Optional[datetime]


class VerifyAttendanceRequest(SQLModel):
    device_id: str
    challenge_b64: str
    signature_b64: str
    falcon_public_key_b64: Optional[str] = None  # optional override


class AttendanceRecord(SQLModel):
    student_name: str
    device_id: str
    course_code: str
    course_title: str
    challenge_b64: str
    signature_b64: str
    created_at: datetime


# ---------- Simple "verification" stub ----------


def verify_falcon_signature_stub(
    challenge_b64: str, signature_b64: str, public_key_b64: str
) -> bool:
    """
    Placeholder verifier.

    In production, replace this with a binding to your liboqs Falcon-512
    implementation so the backend independently verifies the signature
    instead of trusting the instructor device.
    """
    # TODO: integrate real Falcon verification via a Python extension or service.
    return True


# ---------- DB setup ----------


engine = create_engine("sqlite:///attendance.db")

SQLModel.metadata.create_all(engine)


app = FastAPI(title="Ping Attendance Backend")

# Add CORS middleware to allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_session() -> Session:
    return Session(engine)


# ---------- Routes ----------


@app.post("/api/teachers", response_model=TeacherResponse)
def create_teacher(payload: CreateTeacherRequest):
    with get_session() as db:
        existing = db.exec(select(Teacher).where(Teacher.email == payload.email)).first()
        if existing:
            existing.name = payload.name
            db.add(existing)
            db.commit()
            db.refresh(existing)
            return TeacherResponse(id=existing.id, email=existing.email, name=existing.name)

        teacher = Teacher(email=payload.email, name=payload.name)
        db.add(teacher)
        db.commit()
        db.refresh(teacher)
        return TeacherResponse(id=teacher.id, email=teacher.email, name=teacher.name)


@app.post("/api/courses", response_model=CourseResponse)
def create_course(payload: CreateCourseRequest):
    with get_session() as db:
        teacher = db.get(Teacher, payload.teacher_id)
        if not teacher:
            raise HTTPException(status_code=404, detail="Teacher not found")

        course = Course(code=payload.code, title=payload.title, teacher_id=payload.teacher_id)
        db.add(course)
        db.commit()
        db.refresh(course)
        return CourseResponse(
            id=course.id,
            code=course.code,
            title=course.title,
            teacher_id=course.teacher_id,
        )


@app.post("/api/students/register", response_model=StudentResponse)
def register_student(payload: RegisterStudentRequest):
    with get_session() as db:
        existing = db.exec(
            select(Student).where(Student.device_id == payload.device_id)
        ).first()
        if existing:
            # Update name / key if they changed
            existing.name = payload.name
            existing.falcon_public_key_b64 = payload.falcon_public_key_b64
            db.add(existing)
            db.commit()
            db.refresh(existing)
            return StudentResponse(
                id=existing.id, device_id=existing.device_id, name=existing.name
            )

        student = Student(
            device_id=payload.device_id,
            name=payload.name,
            falcon_public_key_b64=payload.falcon_public_key_b64,
        )
        db.add(student)
        db.commit()
        db.refresh(student)
        return StudentResponse(id=student.id, device_id=student.device_id, name=student.name)


@app.post("/api/enrollments", response_model=EnrollmentResponse)
def enroll_student(payload: EnrollmentRequest):
    with get_session() as db:
        course = db.get(Course, payload.course_id)
        if not course:
            raise HTTPException(status_code=404, detail="Course not found")

        student = db.get(Student, payload.student_id)
        if not student:
            raise HTTPException(status_code=404, detail="Student not found")

        existing = db.exec(
            select(Enrollment).where(
                Enrollment.course_id == payload.course_id,
                Enrollment.student_id == payload.student_id,
            )
        ).first()
        if existing:
            return EnrollmentResponse(
                id=existing.id,
                course_id=existing.course_id,
                student_id=existing.student_id,
                enrolled_at=existing.enrolled_at,
            )

        enrollment = Enrollment(course_id=payload.course_id, student_id=payload.student_id)
        db.add(enrollment)
        db.commit()
        db.refresh(enrollment)
        return EnrollmentResponse(
            id=enrollment.id,
            course_id=enrollment.course_id,
            student_id=enrollment.student_id,
            enrolled_at=enrollment.enrolled_at,
        )


@app.post("/api/sessions", response_model=SessionResponse)
def create_session(payload: CreateSessionRequest):
    with get_session() as db:
        course = db.get(Course, payload.course_id)
        if not course:
            raise HTTPException(status_code=404, detail="Course not found")
        if course.teacher_id != payload.teacher_id:
            raise HTTPException(status_code=400, detail="Teacher does not own this course")

        teacher = db.get(Teacher, payload.teacher_id)
        if not teacher:
            raise HTTPException(status_code=404, detail="Teacher not found")

        session_model = SessionModel(
            course_id=payload.course_id,
            teacher_id=payload.teacher_id,
        )
        db.add(session_model)
        db.commit()
        db.refresh(session_model)
        return SessionResponse(
            id=session_model.id,
            course_id=session_model.course_id,
            teacher_id=session_model.teacher_id,
            started_at=session_model.started_at,
            ended_at=session_model.ended_at,
        )


@app.post("/api/sessions/{session_id}/attendance", response_model=AttendanceRecord)
def verify_and_record_attendance(session_id: int, payload: VerifyAttendanceRequest):
    with get_session() as db:
        session_model = db.get(SessionModel, session_id)
        if not session_model:
            raise HTTPException(status_code=404, detail="Session not found")

        course = db.get(Course, session_model.course_id)
        if not course:
            raise HTTPException(status_code=404, detail="Course not found for session")

        student = db.exec(
            select(Student).where(Student.device_id == payload.device_id)
        ).first()
        if not student:
            raise HTTPException(status_code=404, detail="Student not registered")

        # Ensure the student is enrolled in the course for this session
        enrollment = db.exec(
            select(Enrollment).where(
                Enrollment.course_id == course.id,
                Enrollment.student_id == student.id,
            )
        ).first()
        if not enrollment:
            raise HTTPException(
                status_code=403,
                detail="Student is not enrolled in this course and cannot mark attendance",
            )

        public_key_b64 = payload.falcon_public_key_b64 or student.falcon_public_key_b64

        if not verify_falcon_signature_stub(
            payload.challenge_b64, payload.signature_b64, public_key_b64
        ):
            raise HTTPException(status_code=400, detail="Invalid Falcon signature")

        # Record attendance
        record = Attendance(
            session_id=session_model.id,
            student_id=student.id,
            challenge_b64=payload.challenge_b64,
            signature_b64=payload.signature_b64,
        )
        db.add(record)
        db.commit()
        db.refresh(record)

        return AttendanceRecord(
            student_name=student.name,
            device_id=student.device_id,
            course_code=course.code,
            course_title=course.title,
            challenge_b64=record.challenge_b64,
            signature_b64=record.signature_b64,
            created_at=record.created_at,
        )


@app.get("/api/sessions/{session_id}/attendance", response_model=List[AttendanceRecord])
def list_attendance(session_id: int):
    with get_session() as db:
        session_model = db.get(SessionModel, session_id)
        if not session_model:
            raise HTTPException(status_code=404, detail="Session not found")

        course = db.get(Course, session_model.course_id)
        if not course:
            raise HTTPException(status_code=404, detail="Course not found for session")

        stmt = select(Attendance, Student).where(
            Attendance.session_id == session_id,
            Attendance.student_id == Student.id,
        ).order_by(Attendance.created_at.desc())

        rows = db.exec(stmt).all()
        results: List[AttendanceRecord] = []
        for attendance, student in rows:
            results.append(
                AttendanceRecord(
                    student_name=student.name,
                    device_id=student.device_id,
                    course_code=course.code,
                    course_title=course.title,
                    challenge_b64=attendance.challenge_b64,
                    signature_b64=attendance.signature_b64,
                    created_at=attendance.created_at,
                )
            )
        return results


@app.post("/api/sessions/{session_id}/end", response_model=SessionResponse)
def end_session(session_id: int):
    with get_session() as db:
        session_model = db.get(SessionModel, session_id)
        if not session_model:
            raise HTTPException(status_code=404, detail="Session not found")
        session_model.ended_at = datetime.utcnow()
        db.add(session_model)
        db.commit()
        db.refresh(session_model)
        return SessionResponse(
            id=session_model.id,
            course_id=session_model.course_id,
            teacher_id=session_model.teacher_id,
            started_at=session_model.started_at,
            ended_at=session_model.ended_at,
        )


@app.get("/")
def root():
    return {"status": "ok", "service": "ping-attendance-backend"}


