import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'backend_api.dart';
import 'constants.dart'; // Import your constants

class InstructorScreen extends StatefulWidget {
  final int? sessionId;

  const InstructorScreen({super.key, this.sessionId});

  @override
  _InstructorScreenState createState() => _InstructorScreenState();
}

class _InstructorScreenState extends State<InstructorScreen> {
  final Strategy strategy = Strategy.P2P_STAR; // 1 Instructor, Many Students
  List<String> logs = [];
  Map<String, String> connectedStudents = {}; // endpointId -> Student Name
  final Random _rand = Random.secure();

  int? _backendSessionId;
  bool _isAdvertising = false;
  // Track the last challenge we sent to each endpoint so we can submit it
  // to the backend when the signature is received.
  final Map<String, Uint8List> _lastChallengeByEndpoint = {};

  /// Generate a fresh random challenge each time for a given student.
  Uint8List _buildNewChallenge() {
    // 32 bytes of randomness, then Base64-encode for easy transport/logging.
    final raw = List<int>.generate(32, (_) => _rand.nextInt(256));
    final b64 = base64Encode(raw);
    final challengeString = 'CHALLENGE_KEY_$b64';
    return Uint8List.fromList(challengeString.codeUnits);
  }

  void _sendNewChallenge(String endpointId) {
    final challenge = _buildNewChallenge();
    _lastChallengeByEndpoint[endpointId] = challenge;
    _log("Stored challenge for $endpointId (${challenge.length} bytes)");
    try {
      Nearby().sendBytesPayload(endpointId, challenge);
      _log("✓ Sent new challenge to $endpointId");
    } catch (e) {
      _log("✗ Failed to send challenge to $endpointId: $e");
      // Remove challenge if send failed
      _lastChallengeByEndpoint.remove(endpointId);
    }
  }

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    if (widget.sessionId != null) {
      _backendSessionId = widget.sessionId;
    }
  }

  void _checkPermissions() async {
    // Request minimal permissions required for Nearby Connections
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();
  }

  void startSession() async {
    try {
      // Stop any existing advertising first to avoid STATUS_ALREADY_ADVERTISING error
      if (_isAdvertising) {
        _log("Stopping existing advertising...");
        try {
          await Nearby().stopAdvertising();
          await Future.delayed(
            const Duration(milliseconds: 500),
          ); // Brief delay
        } catch (e) {
          _log("Warning: Error stopping advertising: $e");
        }
        setState(() => _isAdvertising = false);
      }

      // Use provided sessionId or create new one
      if (widget.sessionId != null) {
        _backendSessionId = widget.sessionId;
      } else {
        // Try to create a backend session, but don't block Nearby if it fails.
        _log("Creating backend session for course $BACKEND_COURSE_ID...");
        _log("Backend URL: $BACKEND_BASE_URL");
        BackendApi.instance
            .createSession(
              courseId: BACKEND_COURSE_ID,
              teacherId: BACKEND_TEACHER_ID,
            )
            .then((sessionId) {
              _backendSessionId = sessionId;
              _log("✓ Backend session created with id: $_backendSessionId");
              setState(() {});
            })
            .catchError((e) {
              _log("⚠ Backend session creation failed: $e");
              _log(
                "Continuing with Nearby advertising (attendance won't be saved to backend)",
              );
              setState(() {});
            });
      }

      // Start Nearby advertising immediately, regardless of backend status.
      // This ensures students can always discover and connect.
      bool a = await Nearby().startAdvertising(
        INSTRUCTOR_NAME,
        strategy,
        onConnectionInitiated: (String id, ConnectionInfo info) {
          _log("Connection initiated by ${info.endpointName} ($id)");
          // In a real app, you might verify a token here before accepting
          Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endpointId, payload) {
              _onPayloadReceived(endpointId, payload);
            },
          );
        },
        onConnectionResult: (String id, Status status) {
          _log("Connection status for $id: $status");
          if (status == Status.CONNECTED) {
            // Send a fresh Falcon-512 challenge for this connection
            _sendNewChallenge(id);
          } else {
            connectedStudents.remove(id);
          }
        },
        onDisconnected: (String id) {
          _log("Student disconnected: $id");
          connectedStudents.remove(id);
          setState(() {});
        },
        serviceId: SERVICE_ID,
      );
      setState(() => _isAdvertising = true);
      _log("Advertising Started: $a");
    } catch (e) {
      setState(() => _isAdvertising = false);
      _log("Error starting advertising: $e");
      // If it's already advertising, try to stop and restart
      if (e.toString().contains('ALREADY_ADVERTISING') ||
          e.toString().contains('8001')) {
        _log("Attempting to recover from advertising error...");
        try {
          await Nearby().stopAdvertising();
          await Nearby().stopAllEndpoints();
          await Future.delayed(const Duration(seconds: 1));
          // Retry starting
          startSession();
        } catch (retryError) {
          _log("Failed to recover: $retryError");
        }
      }
    }
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      final bytes = payload.bytes!;
      _log("Received signature bytes from $endpointId (len=${bytes.length})");

      final challenge = _lastChallengeByEndpoint[endpointId];
      if (challenge == null) {
        _log(
          "Warning: No challenge found for $endpointId. Cannot verify attendance.",
        );
        // Still show student as connected even if we can't verify
        setState(() {
          connectedStudents[endpointId] = "Unknown (no challenge)";
        });
        return;
      }

      final sessionId = _backendSessionId;
      if (sessionId == null) {
        _log(
          "Warning: Backend session not ready yet for $endpointId. Will retry in 2 seconds...",
        );
        // Retry after a delay in case backend session is still being created
        Future.delayed(const Duration(seconds: 2), () {
          final retrySessionId = _backendSessionId;
          if (retrySessionId != null) {
            _submitAttendanceToBackend(
              endpointId,
              retrySessionId,
              challenge,
              bytes,
            );
          } else {
            _log(
              "Backend session still not available for $endpointId. Attendance not saved.",
            );
            setState(() {
              connectedStudents[endpointId] = "Connected (backend unavailable)";
            });
          }
        });
        return;
      }

      _submitAttendanceToBackend(endpointId, sessionId, challenge, bytes);
    }
  }

  void _submitAttendanceToBackend(
    String endpointId,
    int sessionId,
    Uint8List challenge,
    Uint8List signatureBytes,
  ) {
    // For now, we use the Nearby endpointId as the device_id expected by the
    // backend. In a real deployment you would have the student send their
    // stable device_id along with the signature.
    final deviceId = endpointId;

    BackendApi.instance
        .submitAttendance(
          sessionId: sessionId,
          deviceId: deviceId,
          challengeBytes: challenge,
          signatureBytes: signatureBytes,
        )
        .then((_) {
          _log("✓ Attendance submitted to backend for $endpointId");
          setState(() {
            connectedStudents[endpointId] = deviceId;
          });
        })
        .catchError((e) {
          _log("✗ Failed to submit attendance for $endpointId: $e");
          // Still show as connected even if backend submission fails
          setState(() {
            connectedStudents[endpointId] = "$deviceId (backend error)";
          });
        });
  }

  void stopSession() async {
    try {
      if (_isAdvertising) {
        await Nearby().stopAdvertising();
        setState(() => _isAdvertising = false);
      }
      await Nearby().stopAllEndpoints();
      setState(() {
        connectedStudents.clear();
        logs.clear();
        _backendSessionId = null;
        _lastChallengeByEndpoint.clear();
      });
      _log("Session Stopped");
    } catch (e) {
      _log("Error stopping session: $e");
      setState(() => _isAdvertising = false);
    }
  }

  void _log(String msg) {
    print(msg);
    setState(() {
      logs.insert(0, msg);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Ping: Instructor")),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: startSession,
                child: Text("Start Session"),
              ),
              ElevatedButton(
                onPressed: stopSession,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text("End"),
              ),
            ],
          ),
          Divider(),
          Text(
            "Attendance Count: ${connectedStudents.length}",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) => ListTile(
                dense: true,
                title: Text(logs[index], style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
