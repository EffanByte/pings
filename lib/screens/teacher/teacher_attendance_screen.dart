import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../backend_api.dart';
import '../../constants.dart';
import '../../instructor_screen.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  final int courseId;
  final String courseCode;
  final String courseTitle;

  const TeacherAttendanceScreen({
    super.key,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
  });

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = true;
  int? _currentSessionId;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    try {
      // Get active session for this course
      final sessions = await BackendApi.instance.getSessions(
        courseId: widget.courseId,
      );
      if (sessions.isNotEmpty) {
        final activeSession = sessions.firstWhere(
          (s) => s['ended_at'] == null,
          orElse: () => sessions.first,
        );
        _currentSessionId = activeSession['id'] as int;
        final records = await BackendApi.instance.getAttendance(
          sessionId: _currentSessionId!,
        );
        setState(() {
          _attendanceRecords = records;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading attendance: $e'),
            backgroundColor: AppTheme.black,
          ),
        );
      }
    }
  }

  Future<void> _startSession() async {
    try {
      setState(() => _isLoading = true);
      final sessionId = await BackendApi.instance.createSession(
        courseId: widget.courseId,
        teacherId: BACKEND_TEACHER_ID,
      );
      setState(() {
        _currentSessionId = sessionId;
        _isLoading = false;
      });

      // Navigate to instructor screen for Nearby Connections
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InstructorScreen(sessionId: sessionId),
          ),
        ).then((_) {
          // Refresh attendance when returning from instructor screen
          _loadAttendance();
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting session: $e'),
            backgroundColor: AppTheme.black,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.courseCode),
            Text(widget.courseTitle, style: GoogleFonts.inter(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAttendance,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startSession,
        backgroundColor: AppTheme.black,
        foregroundColor: AppTheme.white,
        icon: Icon(_currentSessionId == null ? Icons.play_arrow : Icons.add),
        label: Text(
          _currentSessionId == null ? 'Start Session' : 'New Session',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _currentSessionId == null
                ? AppTheme.grayLight
                : AppTheme.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentSessionId == null
                          ? 'No active session'
                          : 'Session Active',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.black,
                      ),
                    ),
                    if (_currentSessionId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Session ID: $_currentSessionId',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.grayDark,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_currentSessionId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.black),
                    ),
                  )
                : _attendanceRecords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AppTheme.grayMedium,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No attendance records yet',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            color: AppTheme.grayDark,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAttendance,
                    color: AppTheme.black,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _attendanceRecords.length,
                      itemBuilder: (context, index) {
                        final record = _attendanceRecords[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.black,
                              child: Text(
                                (record['student_name'] as String? ?? '?')[0]
                                    .toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              record['student_name'] ?? 'Unknown',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.black,
                              ),
                            ),
                            subtitle: Text(
                              record['device_id'] ?? 'N/A',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.grayDark,
                              ),
                            ),
                            trailing: Text(
                              _formatTime(record['created_at']),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.grayMedium,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = DateTime.parse(timestamp);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }
}
