import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'constants.dart';

class BackendApi {
  BackendApi._();

  static final BackendApi instance = BackendApi._();

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
}
