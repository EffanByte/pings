import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'constants.dart'; // Import your constants

class InstructorScreen extends StatefulWidget {
  @override
  _InstructorScreenState createState() => _InstructorScreenState();
}

class _InstructorScreenState extends State<InstructorScreen> {
  final Strategy strategy = Strategy.P2P_STAR; // 1 Instructor, Many Students
  List<String> logs = [];
  Map<String, String> connectedStudents = {}; // endpointId -> Student Name

  @override
  void initState() {
    super.initState();
    _checkPermissions();
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
      bool a = await Nearby().startAdvertising(
        INSTRUCTOR_NAME,
        strategy,
        onConnectionInitiated: (String id, ConnectionInfo info) {
          _log("Connection initiated by ${info.endpointName} ($id)");
          // In a real app, you might verify a token here before accepting
          Nearby().acceptConnection(id, onPayLoadRecieved: (endpointId, payload) {
            _onPayloadReceived(endpointId, payload);
          });
        },
        onConnectionResult: (String id, Status status) {
          _log("Connection status for $id: $status");
          if (status == Status.CONNECTED) {
            // Future integration: Send Falcon-512 Challenge here
            Nearby().sendBytesPayload(id, Uint8List.fromList("CHALLENGE_KEY_123".codeUnits));
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
      _log("Advertising Started: $a");
    } catch (e) {
      _log("Error starting advertising: $e");
    }
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      String data = String.fromCharCodes(payload.bytes!);
      _log("Received Attendance from $endpointId: $data");
      
      // Verification logic goes here (Backend Check)
      setState(() {
         // Assuming student sent their Name/ID
        connectedStudents[endpointId] = data; 
      });
    }
  }

  void stopSession() async {
    await Nearby().stopAdvertising();
    await Nearby().stopAllEndpoints();
    setState(() {
      connectedStudents.clear();
      logs.clear();
    });
    _log("Session Stopped");
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
              ElevatedButton(onPressed: startSession, child: Text("Start Session")),
              ElevatedButton(onPressed: stopSession, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text("End")),
            ],
          ),
          Divider(),
          Text("Attendance Count: ${connectedStudents.length}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Expanded(
            child: ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) => ListTile(
                dense: true,
                title: Text(logs[index], style: TextStyle(fontSize: 12)),
              ),
            ),
          )
        ],
      ),
    );
  }
}