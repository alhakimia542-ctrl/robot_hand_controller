import 'dart:async';
import 'dart:convert';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService {
  BluetoothConnection? _connection;
  Timer? _streamTimer;
  String _activeCommand = 'HOLD';
  bool _isConnected = false;

  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  bool get isConnected => _isConnected;

  // Controller to stream sent commands to the UI for the history log
  final StreamController<Map<String, dynamic>> _sentCommandsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get sentCommandsStream => _sentCommandsController.stream;

  // Retrieve a list of paired (bonded) Bluetooth devices
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      return [];
    }
  }

  // Connect to the HC-05 Bluetooth module using its MAC address
  Future<bool> connect(String address) async {
    try {
      // Close any existing connection first
      await _connection?.close();
      
      _connection = await BluetoothConnection.toAddress(address);
      _isConnected = true;
      _connectionStateController.add(true);

      // Listen for connection drops
      _connection!.input!.listen((data) {
        // Handle incoming serial data if necessary
      }, onDone: () {
        disconnect();
      });

      // Start stream timer if we have an active motion command
      if (_activeCommand != 'HOLD') {
        _startStreaming();
      }

      return true;
    } catch (e) {
      disconnect();
      return false;
    }
  }

  // Disconnect and clean up resources
  void disconnect() {
    _streamTimer?.cancel();
    _streamTimer = null;
    _connection?.close();
    _connection = null;
    _isConnected = false;
    _connectionStateController.add(false);
  }

  // Update the active command sent from the vision analyzer
  void updateCommand(String command) {
    if (_activeCommand == command) return;

    _activeCommand = command;

    if (command == 'HOLD') {
      // Stop continuous transmission immediately and send HOLD once
      _streamTimer?.cancel();
      _streamTimer = null;
      _sendData('HOLD');
    } else {
      // Send the new movement command immediately for low latency
      _sendData(command);

      // Start streaming this command every 50 milliseconds
      _startStreaming();
    }
  }

  // Starts the periodic timer to stream the command
  void _startStreaming() {
    _streamTimer?.cancel();
    _streamTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_isConnected && _activeCommand != 'HOLD') {
        _sendData(_activeCommand);
      } else if (_activeCommand == 'HOLD') {
        timer.cancel();
        _streamTimer = null;
      }
    });
  }

  // Transmit command over serial
  void _sendData(String data) {
    if (_connection != null && _connection!.isConnected) {
      try {
        final formattedData = '$data\n';
        _connection!.output.add(utf8.encode(formattedData));
        _connection!.output.allSent.then((_) {
          // Add to local history log
          _sentCommandsController.add({
            'command': data,
            'timestamp': DateTime.now(),
          });
        });
      } catch (e) {
        disconnect();
      }
    }
  }

  void dispose() {
    disconnect();
    _connectionStateController.close();
    _sentCommandsController.close();
  }
}
