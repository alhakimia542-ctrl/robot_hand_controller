import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import 'package:camera/camera.dart';

import 'bluetooth/bluetooth_service.dart';
import 'widgets/gesture_display.dart';
import 'services/camera_service.dart';
import 'engine/gesture_engine.dart';

void main() {
  // Lock orientation to portrait for optimal mobile camera control
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((_) {
    runApp(const RobotHandControllerApp());
  });
}

class RobotHandControllerApp extends StatelessWidget {
  const RobotHandControllerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تحكم اليد الروبوتية',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0E15),
        primaryColor: const Color(0xFF6200EE),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6200EE),
          secondary: Color(0xFF03DAC6),
          background: Color(0xFF0D0E15),
          surface: Color(0xFF1E1E2F),
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Camera & Gesture Engine
  final CameraService _cameraService = CameraService();
  final GestureEngine _gestureEngine = GestureEngine();
  StreamSubscription? _gestureSubscription;

  // Services & State
  final BluetoothService _bluetoothService = BluetoothService();
  List<BluetoothDevice> _bondedDevices = [];
  BluetoothDevice? _selectedDevice;
  bool _isBtConnected = false;
  bool _isBtConnecting = false;
  String _activeGesture = 'HOLD';
  final List<Map<String, dynamic>> _commandLogs = [];

  // Manual Override State
  bool _isManualOverride = false;
  Timer? _overrideTimer;

  // Permissions & Loading State
  bool _permissionsGranted = false;
  bool _isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
    _listenToBluetoothState();
    _listenToSentCommands();
  }

  @override
  void dispose() {
    _gestureSubscription?.cancel();
    _cameraService.dispose();
    _gestureEngine.dispose();
    _bluetoothService.dispose();
    super.dispose();
  }

  // 1. Request Camera and Bluetooth permissions
  Future<void> _checkAndRequestPermissions() async {
    setState(() {
      _isLoadingPermissions = true;
    });

    // Request necessary runtime permissions
    final permissions = [
      Permission.camera,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    final allGranted = statuses[Permission.camera]!.isGranted &&
        (statuses[Permission.bluetooth]!.isGranted || statuses[Permission.bluetoothConnect]!.isGranted);

    setState(() {
      _permissionsGranted = allGranted;
      _isLoadingPermissions = false;
    });

    if (allGranted) {
      _loadBondedDevices();
      try {
        await _gestureEngine.initialize();
        await _cameraService.initialize();
        if (mounted) {
          setState(() {});
        }
        _cameraService.startImageStream((image) {
          _gestureEngine.processFrame(image);
        });
      } catch (e) {
        print("Error initializing camera or gesture engine: $e");
      }
      _startGestureStream();
    }
  }

  // Handle manual commands from UI
  void _handleManualCommand(String command) {
    if (mounted) {
      setState(() {
        _activeGesture = command;
      });
    }
    _bluetoothService.updateCommand(command);

    _isManualOverride = true;
    _overrideTimer?.cancel();
    // Block the gesture engine from overriding for 800ms
    _overrideTimer = Timer(const Duration(milliseconds: 800), () {
      _isManualOverride = false;
    });
  }

  // 2. Start listening to the gesture Stream from Dart Engine
  void _startGestureStream() {
    _gestureSubscription?.cancel();
    _gestureSubscription = _gestureEngine.commandStream.listen(
      (gesture) {
        if (_isManualOverride) return; // Skip updating if manual override is active

        if (mounted) {
          setState(() {
            _activeGesture = gesture;
          });
        }
        // Pipe the command directly to the Bluetooth streaming service
        _bluetoothService.updateCommand(_activeGesture);
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _activeGesture = 'HOLD';
          });
        }
        _bluetoothService.updateCommand('HOLD');
      },
    );
  }

  // 3. Load bonded devices from classic Bluetooth adapter
  Future<void> _loadBondedDevices() async {
    final devices = await _bluetoothService.getBondedDevices();
    setState(() {
      _bondedDevices = devices;
      // Proactively select the HC-05 module if found in the list
      _selectedDevice = devices.firstWhere(
        (d) => d.name?.toUpperCase().contains('HC-05') ?? false,
        orElse: () => devices.isNotEmpty ? devices.first : BluetoothDevice(name: 'لا يوجد جهاز', address: ''),
      );
    });
  }

  // 4. Connect / Disconnect from selected BT device
  Future<void> _toggleBluetoothConnection() async {
    if (_selectedDevice == null || _selectedDevice!.address.isEmpty) return;

    if (_isBtConnected) {
      _bluetoothService.disconnect();
    } else {
      setState(() {
        _isBtConnecting = true;
      });

      final success = await _bluetoothService.connect(_selectedDevice!.address);

      setState(() {
        _isBtConnecting = false;
        _isBtConnected = success;
      });

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل الاتصال بـ ${_selectedDevice!.name}. تأكد من تشغيل الجهاز.',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Listen to connection state updates from Bluetooth Service
  void _listenToBluetoothState() {
    _bluetoothService.connectionStateStream.listen((connected) {
      setState(() {
        _isBtConnected = connected;
      });
    });
  }

  // Listen to commands sent to display in the UI history log
  void _listenToSentCommands() {
    _bluetoothService.sentCommandsStream.listen((log) {
      setState(() {
        _commandLogs.insert(0, log);
        // Cap list size to prevent memory inflation
        if (_commandLogs.length > 30) {
          _commandLogs.removeLast();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: _isLoadingPermissions
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6200EE)))
            : !_permissionsGranted
                ? _buildPermissionRequestScreen()
                : _buildDashboardScreen(),
      ),
    );
  }

  // UI for requesting permissions
  Widget _buildPermissionRequestScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F101A), Color(0xFF1B1B2F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.security_rounded,
            size: 80,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 32),
          Text(
            'الصلاحيات المطلوبة',
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'يحتاج التطبيق إلى صلاحيات الكاميرا (للتعرف على الإيماءات) والبلوتوث (لإرسال الأوامر إلى الروبوت HC-05). يرجى السماح بالصلاحيات للمتابعة.',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              color: Colors.white60,
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: _checkAndRequestPermissions,
            icon: const Icon(Icons.check_circle_rounded),
            label: Text(
              'منح الصلاحيات',
              style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6200EE),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: const Color(0xFF6200EE).withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  // Dashboard layout
  Widget _buildDashboardScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF090A10), Color(0xFF141522)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'منظومة التحكم بالإيماءات',
                            style: GoogleFonts.tajawal(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'التعرف التلقائي وبث الأوامر إلى HC-05',
                            style: GoogleFonts.tajawal(
                              fontSize: 13,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Quick Status Circle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isBtConnected
                            ? Colors.green.withOpacity(0.12)
                            : Colors.redAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isBtConnected ? Colors.green : Colors.redAccent,
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        _isBtConnected ? 'متصل' : 'غير متصل',
                        style: GoogleFonts.tajawal(
                          color: _isBtConnected ? Colors.green : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Camera and Bluetooth Layout (Responsive height)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Native Camera Preview Card
                  Expanded(
                    flex: 12,
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF6200EE).withOpacity(0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6200EE).withOpacity(0.15),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: _cameraService.controller != null && _cameraService.controller!.value.isInitialized
                            ? CameraPreview(_cameraService.controller!)
                            : const Center(
                                child: Icon(Icons.videocam_off, color: Colors.white24, size: 40),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 2. Bluetooth Connection control card
                  Expanded(
                    flex: 13,
                    child: Container(
                      height: 180,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'لوحة الاتصال',
                            style: GoogleFonts.tajawal(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<BluetoothDevice>(
                                value: _selectedDevice,
                                dropdownColor: const Color(0xFF1E1E2F),
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                                style: GoogleFonts.tajawal(color: Colors.white, fontSize: 12),
                                items: _bondedDevices.map((device) {
                                  return DropdownMenuItem<BluetoothDevice>(
                                    value: device,
                                    child: Text(
                                      device.name ?? 'جهاز مجهول',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: _isBtConnected ? null : (device) {
                                  setState(() {
                                    _selectedDevice = device;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Connection Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isBtConnecting ? null : _toggleBluetoothConnection,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isBtConnected ? Colors.redAccent : const Color(0xFF6200EE),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isBtConnecting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      _isBtConnected ? 'قطع الاتصال' : 'اتصال بالروبوت',
                                      style: GoogleFonts.tajawal(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Gesture Status Card & Terminal Log (Takes remaining screen height)
              Expanded(
                child: GestureDisplay(
                  activeCommand: _activeGesture,
                  commandLogs: _commandLogs,
                  onManualCommand: _handleManualCommand,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
