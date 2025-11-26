import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'constants.dart';
import 'crypto/falcon_ffi.dart';

class StudentScreen extends StatefulWidget {
  @override
  _StudentScreenState createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  final Strategy strategy = Strategy.P2P_STAR;
  String userName = "Student_${Random().nextInt(100)}"; // Simulating unique student
  List<String> logs = [];
  String? connectedInstructorId;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
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
    try {
      bool a = await Nearby().startDiscovery(
        userName,
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
            if (endpoint is String) id = endpoint;
            else if (endpoint != null) {
              // common property names across versions
              id = (endpoint.endpointId ?? endpoint.id ?? endpoint.toString()) as String;
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

  void _requestConnection(String endpointId) {
    Nearby().requestConnection(
      userName,
      endpointId,
      onConnectionInitiated: (id, info) {
        _log("Connection initiated. Accepting...");
        Nearby().acceptConnection(id, onPayLoadRecieved: (endpointId, payload) {
           _onPayloadReceived(endpointId, payload);
        });
      },
      onConnectionResult: (id, status) {
        _log("Connection Result: $status");
        if (status == Status.CONNECTED) {
          setState(() {
            connectedInstructorId = id;
          });
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
        FalconCrypto.instance.signChallenge(Uint8List.fromList(bytes)).then((sig) {
          Nearby().sendBytesPayload(endpointId, sig);
          _log("Sent Falcon signature (length: ${sig.length})");
        }).catchError((e) {
          _log("Failed to sign challenge: $e");
        });
      }
    }
  }

  void _sendAttendance(String endpointId) {
    // Future integration: Sign the challenge with Falcon-512 here
    String payload = "$userName - PRESENT - [SignedHash]";
    
    Nearby().sendBytesPayload(
      endpointId, 
      Uint8List.fromList(payload.codeUnits)
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
      appBar: AppBar(title: Text("Ping: Student ($userName)")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: connectedInstructorId == null ? startDiscovery : null,
              child: Text(connectedInstructorId == null ? "Scan for Class" : "Connected"),
              style: ElevatedButton.styleFrom(
                backgroundColor: connectedInstructorId == null ? Colors.blue : Colors.green
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
          )
        ],
      ),
    );
  }
}