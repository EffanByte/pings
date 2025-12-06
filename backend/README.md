## Ping Attendance Backend

This directory contains a minimal backend service for your Ping attendance app.

### What this backend does

- **Student registration**
  - `POST /api/students/register`
  - Stores device ID, student name, and Falcon public key (Base64).
- **Session (class) management**
  - `POST /api/sessions` – instructor starts a session.
  - `POST /api/sessions/{session_id}/end` – instructor ends a session.
- **Attendance verification + storage**
  - `POST /api/sessions/{session_id}/attendance`
    - Input: device ID, challenge (Base64), signature (Base64), optional public key.
    - Currently uses a **stub** verifier (`verify_falcon_signature_stub`) – you will later replace this with real Falcon-512 verification using the same liboqs stack you use on Android.
  - `GET /api/sessions/{session_id}/attendance`
    - Returns a list of all attendance records for a session.

The backend uses **FastAPI + SQLite (via SQLModel)** so you can run it quickly during development.

### Running locally

From the project root:

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate  # on Windows
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

The API will be available at `http://localhost:8000`.

You can explore it using the built-in Swagger UI at:

- `http://localhost:8000/docs`

### Wiring this into the Flutter app

High-level flow you can implement from Flutter:

- **Student app**
  1. On first launch, after generating a Falcon keypair on-device, call `POST /api/students/register` with:
     - `device_id`: some stable ID (e.g., Android ID or a UUID you persist).
     - `name`: displayed student name.
     - `falcon_public_key_b64`: Base64 of the public key you already keep in `flutter_secure_storage`.
  2. When you sign a challenge from the instructor:
     - Base64-encode the challenge bytes and signature bytes.
     - Have the instructor device send them to the backend as part of the attendance request.

- **Instructor app**
  1. When a student’s signed challenge arrives over Nearby:
     - Pair it with the challenge you originally sent.
     - Call `POST /api/sessions/{session_id}/attendance` on the backend with:
       - `device_id` of the student (you can include this in the Nearby message or map endpoint IDs to device IDs).
       - `challenge_b64`
       - `signature_b64`
  2. Use `GET /api/sessions/{session_id}/attendance` to show a live attendance list.

### Next step: real Falcon verification

Right now `verify_falcon_signature_stub` always returns `True` – it is **not secure**.

For production:

- Expose your liboqs Falcon-512 verification from C as a small shared library.
- Wrap it from Python using:
  - `ctypes` or `cffi`, or
  - a small CPython extension module.
- Replace the stub with a real call that:
  - Decodes the Base64 challenge / signature / public key.
  - Calls Falcon-512 `verify` and returns `True` only if valid.


