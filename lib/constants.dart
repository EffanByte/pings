// lib/constants.dart
const String SERVICE_ID = "com.ping.attendance";
const String INSTRUCTOR_NAME = "Ping_Instructor_Device";

/// Base URL of your backend API.
///
/// When running the FastAPI server on your development machine and the
/// instructor app on an Android emulator, use "http://10.0.2.2:8000".
/// When running on a real device, replace with your machine's LAN IP
/// (e.g. "http://192.168.1.10:8000").
const String BACKEND_BASE_URL = "http://10.7.108.93:8000";

/// IDs for the teacher and course that this instructor app represents.
///
/// These must match rows that already exist in the backend database
/// (created via the /api/teachers and /api/courses endpoints or another UI).
const int BACKEND_TEACHER_ID = 1;
const int BACKEND_COURSE_ID = 1;
