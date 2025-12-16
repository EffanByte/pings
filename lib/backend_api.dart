import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'constants.dart';

class BackendApi {
  /// Get all courses (for students to browse)
  Future<List<Map<String, dynamic>>> getAllCourses() async {
    final uri = Uri.parse('$BACKEND_BASE_URL/api/courses');
    final resp = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception(
              'Backend request timed out after 10 seconds. Please check if the server is running at $BACKEND_BASE_URL',
            );
          },
        );

    if (resp.statusCode != 200) {
      throw Exception('Failed to get courses: ${resp.statusCode} ${resp.body}');
    }

    final data = jsonDecode(resp.body) as List;
    return data.cast<Map<String, dynamic>>();
  }

  BackendApi._();

  static final BackendApi instance = BackendApi._();

  static const _storageKeyDeviceId = 'device_id';
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Returns a stable device id stored in secure storage, or creates one.
  static Future<String> getOrCreateDeviceId() async {
    final existing = await _secureStorage.read(key: _storageKeyDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    // Use a simple stable token — avoid adding new dependencies for UUID.
    final rnd = DateTime.now().microsecondsSinceEpoch.toRadixString(36) + '_' + DateTime.now().millisecondsSinceEpoch.toString();
    await _secureStorage.write(key: _storageKeyDeviceId, value: rnd);
    return rnd;
  }

  /// Read the stored device id if present, otherwise return null.
  static Future<String?> getDeviceId() async {
    final existing = await _secureStorage.read(key: _storageKeyDeviceId);
    if (existing == null || existing.isEmpty) return null;
    return existing;
  }

  /// Create a new session for a given course + teacher.
  /// Returns the created session id.
  /// Throws an exception if the request fails or times out.
  Future<int> createSession({
    required int courseId,
    required int teacherId,
  }) async {
    final uri = Uri.parse('$BACKEND_BASE_URL/api/sessions');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'course_id': courseId, 'teacher_id': teacherId}),
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Backend request timed out after 10 seconds');
          },
        );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception(
        'Failed to create session: ${resp.statusCode} ${resp.body}',
      );
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['id'] as int;
  }

  /// Submit a signed challenge as attendance for a given session.
  Future<void> submitAttendance({
    required int sessionId,
    required String deviceId,
    required Uint8List challengeBytes,
    required Uint8List signatureBytes,
  }) async {
    final uri = Uri.parse(
      '$BACKEND_BASE_URL/api/sessions/$sessionId/attendance',
    );

    final challengeB64 = base64Encode(challengeBytes);
    final signatureB64 = base64Encode(signatureBytes);

    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'device_id': deviceId,
            'challenge_b64': challengeB64,
            'signature_b64': signatureB64,
          }),
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Backend request timed out after 10 seconds');
          },
        );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception(
        'Failed to submit attendance: ${resp.statusCode} ${resp.body}',
      );
    }
  }

  /// Get courses for a teacher
  Future<List<Map<String, dynamic>>> getCourses({
    required int teacherId,
  }) async {
    final uri = Uri.parse('$BACKEND_BASE_URL/api/teachers/$teacherId/courses');
    print('Fetching courses from: $uri');

    final resp = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Backend request timed out after 10 seconds');
          },
        );

    print('Response status: ${resp.statusCode}');
    print('Response body: ${resp.body}');

    if (resp.statusCode != 200) {
      throw Exception('Failed to get courses: ${resp.statusCode} ${resp.body}');
    }

    final data = jsonDecode(resp.body) as List;
    print('Parsed ${data.length} courses');
    return data.cast<Map<String, dynamic>>();
  }

  /// Get sessions for a course
  Future<List<Map<String, dynamic>>> getSessions({
    required int courseId,
  }) async {
    final uri = Uri.parse('$BACKEND_BASE_URL/api/courses/$courseId/sessions');
    final resp = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Backend request timed out after 10 seconds');
          },
        );

    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to get sessions: ${resp.statusCode} ${resp.body}',
      );
    }

    final data = jsonDecode(resp.body) as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// Get attendance records for a session
  Future<List<Map<String, dynamic>>> getAttendance({
    required int sessionId,
  }) async {
    final uri = Uri.parse(
      '$BACKEND_BASE_URL/api/sessions/$sessionId/attendance',
    );
    final resp = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Backend request timed out after 10 seconds');
          },
        );

    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to get attendance: ${resp.statusCode} ${resp.body}',
      );
    }

    final data = jsonDecode(resp.body) as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// Get courses for a student (enrolled courses)
  Future<List<Map<String, dynamic>>> getStudentCourses({
    required String deviceId,
  }) async {
    final uri = Uri.parse('$BACKEND_BASE_URL/api/students/$deviceId/courses');
    final resp = await http
        .get(uri)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Backend request timed out after 10 seconds');
          },
        );

    if (resp.statusCode != 200) {
      throw Exception(
        'Failed to get student courses: ${resp.statusCode} ${resp.body}',
      );
    }

    final data = jsonDecode(resp.body) as List;
    return data.cast<Map<String, dynamic>>();
  }

  /// Register a student with the backend. `publicKeyBytes` should be the raw
  /// Falcon public key bytes — the method will Base64-encode them.
  Future<Map<String, dynamic>> registerStudent({
    required String deviceId,
    required String name,
    required Uint8List publicKeyBytes,
  }) async {
    final uri = Uri.parse('$BACKEND_BASE_URL/api/students/register');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'device_id': deviceId,
            'name': name,
            'falcon_public_key_b64': base64Encode(publicKeyBytes),
          }),
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Backend request timed out after 10 seconds');
          },
        );

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Failed to register student: ${resp.statusCode} ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data;
  }
}
