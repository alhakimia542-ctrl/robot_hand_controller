import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

class GestureEngine {
  final StreamController<String> _commandController = StreamController<String>.broadcast();
  Stream<String> get commandStream => _commandController.stream;

  HandLandmarkerPlugin? _handLandmarker;
  bool _isProcessing = false;
  bool _isInitialized = false;

  Future<void> initialize() async {
    try {
      _handLandmarker = HandLandmarkerPlugin.create(
        numHands: 1,
        minHandDetectionConfidence: 0.5,
        delegate: HandLandmarkerDelegate.gpu,
      );
      _isInitialized = true;
    } catch (e) {
      // Ignored for UI flow continuity
    }
  }

  void processFrame(CameraImage image) {
    if (!_isInitialized || _isProcessing || _handLandmarker == null) return;
    _isProcessing = true;

    try {
      final hands = _handLandmarker!.detect(image, 0);

      // Rule 11 fallback check for no hands
      if (hands.isEmpty) {
        _commandController.add('HOLD');
        return;
      }

      // Allow Both Hands: Process the first detected hand without handedness restriction
      final landmarks = hands.first.landmarks;

      final command = _mapLandmarksToCommand(landmarks);
      _commandController.add(command);
    } catch (e) {
      _commandController.add('HOLD');
    } finally {
      _isProcessing = false;
    }
  }

  /// Calculates the 3D Euclidean distance between two landmarks
  double _euclideanDistance(Landmark p1, Landmark p2) {
    final dx = p1.x - p2.x;
    final dy = p1.y - p2.y;
    final dz = p1.z - p2.z;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Determines if a standard finger is open using rotation-invariant distance from the Wrist (0)
  /// Includes a 0.02 tolerance margin for anti-jitter stability.
  bool _isFingerOpen(List<Landmark> landmarks, int tipIndex, int pipIndex) {
    final wrist = landmarks[0];
    final tipDist = _euclideanDistance(wrist, landmarks[tipIndex]);
    final pipDist = _euclideanDistance(wrist, landmarks[pipIndex]);
    return tipDist > pipDist + 0.02;
  }

  /// Thumb opens laterally, so we measure distance from thumb tip/IP to the pinky base
  /// Includes a 0.02 tolerance margin for anti-jitter stability.
  bool _isThumbOpen(List<Landmark> landmarks) {
    final tipDist = _euclideanDistance(landmarks[4], landmarks[17]);
    final ipDist = _euclideanDistance(landmarks[3], landmarks[17]);
    return tipDist > ipDist + 0.02;
  }

  // Note: Previous geometric checking for thumb up/down was removed in favor of 
  // relaxed relative Joint (Tip vs IP) Y-coordinate logic to fix thumb lateral extension issues.

  String _mapLandmarksToCommand(List<Landmark> landmarks) {
    Set<int> openFingers = {};

    // Evaluate Thumb (4)
    if (_isThumbOpen(landmarks)) openFingers.add(4);
    // Evaluate Index (Tip 8, PIP 6)
    if (_isFingerOpen(landmarks, 8, 6)) openFingers.add(8);
    // Evaluate Middle (Tip 12, PIP 10)
    if (_isFingerOpen(landmarks, 12, 10)) openFingers.add(12);
    // Evaluate Ring (Tip 16, PIP 14)
    if (_isFingerOpen(landmarks, 16, 14)) openFingers.add(16);
    // Evaluate Pinky (Tip 20, PIP 18)
    if (_isFingerOpen(landmarks, 20, 18)) openFingers.add(20);

    // Rule 1 - DC_FORWARD: Complete fist
    if (openFingers.isEmpty) {
      return 'DC_FORWARD';
    }

    // Rule 2 - DC_BACKWARD: All fingers open (full palm)
    if (openFingers.length == 5) {
      return 'DC_BACKWARD';
    }

    // Rule 3 & Rule 4 - LIFT_UP & LIFT_DOWN (Relaxed Relative IP Y Check)
    if (openFingers.length == 1 && openFingers.contains(4)) {
      if (landmarks[4].y < landmarks[3].y - 0.015) {
        return 'LIFT_UP';
      } else if (landmarks[4].y > landmarks[3].y + 0.015) {
        return 'LIFT_DOWN';
      }
    }

    // Rule 5 & Rule 6 - BASE_RIGHT & BASE_LEFT (Relative to MCP joint 5 with 0.03 dead-zone buffer)
    if (openFingers.length == 1 && openFingers.contains(8)) {
      if (landmarks[8].x < landmarks[5].x - 0.03) {
        return 'BASE_RIGHT';
      } else if (landmarks[8].x > landmarks[5].x + 0.03) {
        return 'BASE_LEFT';
      }
    }

    // Rule 7 - EXTEND
    if (openFingers.length == 3 && openFingers.containsAll([8, 12, 16])) {
      return 'EXTEND';
    }

    // Rule 8 - RETRACT
    if (openFingers.length == 3 && openFingers.containsAll([12, 16, 20])) {
      return 'RETRACT';
    }

    // Rule 9 & Rule 10 - GRIP_OPEN & GRIP_CLOSED (No dead-zone)
    if (openFingers.length == 2 && openFingers.containsAll([8, 12])) {
      final dist = _euclideanDistance(landmarks[8], landmarks[12]);
      if (dist >= 0.07) {
        return 'GRIP_OPEN';
      } else {
        return 'GRIP_CLOSED';
      }
    }

    // Rule 11 - HOLD: Fallback if no rules matched
    return 'HOLD';
  }

  void dispose() {
    _commandController.close();
    _handLandmarker?.dispose();
  }
}
