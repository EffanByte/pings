# Ping Attendance Backend (Node.js/Express)

Simple, reliable backend using Node.js and Express.

## Setup

1. **Install Node.js** (if not already installed)
   - Download from https://nodejs.org/
   - Or use: `winget install OpenJS.NodeJS`

2. **Install dependencies**
   ```bash
   cd backend
   npm install
   ```

3. **Start the server**
   ```bash
   npm start
   ```
   
   Or for auto-reload during development:
   ```bash
   npm run dev
   ```

The server will start on `http://0.0.0.0:8000` (accessible from your network).

## API Endpoints

All endpoints match the FastAPI version:

- `GET /` - Health check
- `POST /api/teachers` - Create/update teacher
- `POST /api/courses` - Create course
- `POST /api/students/register` - Register student
- `POST /api/enrollments` - Enroll student in course
- `POST /api/sessions` - Create session
- `POST /api/sessions/:session_id/attendance` - Submit attendance
- `GET /api/sessions/:session_id/attendance` - List attendance
- `POST /api/sessions/:session_id/end` - End session

## Database

Uses SQLite (`attendance.db`) - same as before, just managed by Node.js instead of Python.

## Why Node.js?

- ✅ Easier to debug
- ✅ No Python/CORS issues
- ✅ Works reliably on Windows
- ✅ Simple setup
- ✅ Same API, just different implementation

