import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'backend_api.dart';
import 'constants.dart';
import 'crypto/falcon_ffi.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  _StudentScreenState createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  final Strategy strategy = Strategy.P2P_STAR;
  String? studentName;
  String? deviceId;
  List<String> logs = [];
  String? connectedInstructorId;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _initializeStudent();
  }

  Future<void> _initializeStudent() async {
    try {
      final name = await BackendApi.getStudentName();
      final id = await BackendApi.getDeviceId();
      if (name == null || id == null) {
        _log("Error: Student not initialized. Please sign up first.");
        setState(() => _isInitializing = false);
        return;
      }
      setState(() {
        studentName = name;
        deviceId = id;
        _isInitializing = false;
      });
      _log("Initialized student: $studentName");
    } catch (e) {
      _log("Error initializing student: $e");
      setState(() => _isInitializing = false);
    }
  }

  void _checkPermissions() async {
    await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();
  }

  void startDiscovery() async {
    if (deviceId == null) {
      _log("Error: Device ID not initialized. Cannot start discovery.");
      return;
    }
    try {
      bool a = await Nearby().startDiscovery(
        deviceId!,
        strategy,
        onEndpointFound: (String id, String name, String serviceId) {
          if (serviceId == SERVICE_ID) {
            _log("Found Instructor: $name ($id)");
            // Auto-request connection when Instructor is found
            _requestConnection(id);
          }
        },
        // ignore: argument_type_not_assignable
        onEndpointLost: (dynamic endpoint) {
          String id = 'unknown';
          try {
            if (endpoint is String) {
              id = endpoint;
            } else if (endpoint != null) {
              // common property names across versions
              id =
                  (endpoint.endpointId ?? endpoint.id ?? endpoint.toString())
                      as String;
            }
          } catch (_) {
            id = endpoint?.toString() ?? 'unknown';
          }
          _log("Lost endpoint: $id");
        },
        serviceId: SERVICE_ID,
      );
      _log("Discovery Started: $a");
    } catch (e) {
      _log("Error discovering: $e");
    }
  }

  void stopDiscovery() async {
    try {
      await Nearby().stopDiscovery();
      _log("Discovery stopped.");
    } catch (e) {
      _log("Error stopping discovery: $e");
    }
  }

  void _requestConnection(String endpointId) {
    Nearby().requestConnection(
      deviceId ?? 'Student',
      endpointId,
      onConnectionInitiated: (id, info) {
        _log("Connection initiated. Accepting...");
        Nearby().acceptConnection(
          id,
          onPayLoadRecieved: (endpointId, payload) {
            _onPayloadReceived(endpointId, payload);
          },
        );
      },
      onConnectionResult: (id, status) {
        _log("Connection Result: $status");
        if (status == Status.CONNECTED) {
          setState(() {
            connectedInstructorId = id;
          });
          // Send our registered device id/name to the instructor so the
          // instructor can correlate Nearby endpoint -> registered student.
          try {
            final info = jsonEncode({
              'device_id': deviceId,
              'name': studentName,
            });
            Nearby().sendBytesPayload(id, Uint8List.fromList(info.codeUnits));
            _log('Sent device identifier to instructor');
          } catch (e) {
            _log('Failed to send device identifier: $e');
          }
        }
      },
      onDisconnected: (id) {
        _log("Disconnected from Instructor");
        setState(() {
          connectedInstructorId = null;
        });
      },
    );
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      final bytes = payload.bytes!;
      String msg = String.fromCharCodes(bytes);
      _log("Received from Instructor: $msg");

      if (msg.contains("CHALLENGE_KEY")) {
        // sign the raw challenge bytes using native Falcon via FFI
        _log("Signing challenge with Falcon-512...");
        FalconCrypto.instance
            .signChallenge(Uint8List.fromList(bytes))
            .then((sig) {
              Nearby().sendBytesPayload(endpointId, sig);
              _log("Sent Falcon signature (length: ${sig.length})");
            })
            .catchError((e) {
              _log("Failed to sign challenge: $e");
            });
      }
    }
  }

  void _sendAttendance(String endpointId) {
    // Future integration: Sign the challenge with Falcon-512 here
    String payload = "$studentName - PRESENT - [SignedHash]";

    Nearby().sendBytesPayload(
      endpointId,
      Uint8List.fromList(payload.codeUnits),
    );
    _log("Sent Attendance Payload");
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
      appBar: AppBar(title: Text("Ping: Student (${studentName ?? 'Not initialized'})")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: connectedInstructorId == null ? startDiscovery : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: connectedInstructorId == null
                    ? Colors.blue
                    : Colors.green,
              ),
              child: Text(
                connectedInstructorId == null ? "Scan for Class" : "Connected",
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(logs[index], style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
