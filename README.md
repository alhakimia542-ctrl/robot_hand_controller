# Robot Hand and Mobile Base Controller: Computer Vision to Physical Actuation

## Project Overview
This repository contains the source code and documentation for a comprehensive cyber-physical system. The project demonstrates the successful integration of real-time Computer Vision (CV) algorithms with embedded electronics to remotely control a differential-drive mobile robot equipped with a 4 Degree-of-Freedom (DOF) robotic arm. The entire system is driven by human hand gestures, eliminating the need for traditional mechanical controllers or physical interfaces.

## 🎥 Watch the Demo
**See the robot in action!** Watch the full video demonstration of controlling the mobile base and the robotic arm via real-time hand gestures on YouTube:
▶️ **[تحكم بروبوت متحرك وذراع آلية بإيماءات اليد | Hand Gesture Robot Control](https://youtu.be/E1I6UvdjfzE?si=7N_h8rOKjhbLzfZs)**

---

## Visual Showcase

### Hardware Setup
<p align="center">
  <img src="images/robot-full-view.jpg" width="400" alt="Full System Overview">
  <img src="images/robotic-arm-gripper.jpg" width="400" alt="Robotic Arm and Gripper Mechanism">
  <br>
  <img src="images/hardware-wiring-setup.jpg" width="400" alt="Arduino and L298N Wiring Setup">
  <img src="images/mobile-base-chassis.jpg" width="400" alt="Mobile Chassis and DC Motors">
</p>

### Application and Gesture Recognition
<p align="center">
  <img src="images/app-gesture-open-hand.png" width="250" alt="Open Hand Detection">
  <img src="images/app-gesture-three-fingers.png" width="250" alt="Three Fingers Detection">
  <img src="images/app-gesture-open-gripper.png" width="250" alt="Pinch/Gripper Gesture Detection">
</p>

## Technical Architecture

The system architecture is strictly divided into three main layers: Perception, Communication, and Actuation.

### 1. Perception Layer (Flutter & MediaPipe)
The frontend is developed using the Flutter framework, ensuring cross-platform compatibility and high-performance camera frame rendering via CameraX. At the core of the perception layer is the Google MediaPipe Hand Landmarker AI model. 
- The deep learning model extracts 21 3D spatial landmarks from the hand in real-time.
- Custom algorithms analyze the Euclidean distances and specific geometric angles between joints (e.g., the distance between the thumb tip and index tip) to classify the current gesture.
- A state management logic is implemented to prevent signal bouncing, ensuring stable and explicit command generation.

### 2. Communication Layer (Bluetooth Serial)
To maintain a continuous and low-latency data stream, the system utilizes the Classic Bluetooth protocol via the HC-05 module. 
- The Flutter application transmits parsed string commands terminated by a newline character (`\n`).
- The transmission rate and buffer management are optimized to prevent serial buffer overflow on the microcontroller side while maintaining highly responsive control.

### 3. Actuation Layer (Arduino & Motor Control)
The microcontroller (Arduino UNO) parses the incoming serial data and manages the hardware execution.
- **Mobile Base (Differential Drive):** Utilizes an L298N motor driver connected to analog pins (configured as digital outputs) for direction, and PWM-enabled pins for precise speed control. Dynamic torque adjustment is programmed into the firmware, providing higher PWM signals during backward movement to safely overcome mechanical resistance without stalling.
- **Robotic Arm:** Controls 4 independent servo motors (Base, Lift, Extend, Grip). To achieve industrial-like smooth motion, the firmware completely avoids blocking `delay()` functions for major movements. Instead, it increments servo angles step-by-step within the main loop state machine, providing fluid kinematic movement and preventing mechanical strain on the gears. The gripper, however, uses direct angular mapping for instantaneous and firm grasping.

## Command Mapping Protocol

| Detected Gesture | Serial Command | Hardware Execution |
| :--- | :--- | :--- |
| Open Hand | `DC_BACKWARD` | Applies high-torque PWM to reverse the chassis. |
| Closed Fist | `DC_FORWARD` | Moves the differential drive base forward at a stabilized speed. |
| Index Finger Up | `ROTATE_RIGHT` / `ROTATE_LEFT` | Executes a tank-turn maneuver using opposing wheel directions. |
| Three Fingers | `BASE_RIGHT` / `LIFT_UP` | Initiates continuous smooth interpolation for the arm servos. |
| Pinch | `GRIP_CLOSED` / `GRIP_OPEN` | Snaps the gripper servo to predefined bounding angles (10 deg / 45 deg). |
| No Hand Detected | `HOLD` | Failsafe mechanism; halts all PWM signals immediately to prevent collisions. |

## Installation and Setup Instructions

### Prerequisites
- Flutter SDK (v3.10.4 or higher)
- Arduino IDE
- Physical Android Device (Emulators do not support the required Bluetooth/Camera hardware APIs)

### Hardware Assembly
1. Connect the HC-05 TX/RX to the Arduino (SoftwareSerial pins 12, 13).
2. Wire the L298N motor driver IN1-IN4 to Arduino pins A0-A3, and ENA/ENB to PWM pins 3 and 5.
3. Connect the 4 Servo motors to pins 10, 11, 4, and 9.
4. Ensure the entire system is powered by an isolated and adequate power supply (e.g., 8.4V Li-ion battery pack) to prevent voltage drops and logic resets during simultaneous motor actuation.

### Software Deployment
1. Clone this repository to your local machine.
2. Navigate to the Arduino directory and flash the firmware to the UNO board.
3. Navigate to the Flutter directory and run `flutter pub get` to fetch dependencies.
4. Build and install the APK on your Android device using `flutter run --release`.
5. Pair the HC-05 module with your smartphone in the Android Bluetooth settings prior to launching the application.

## License
This project is open-source and available for educational, academic, and developmental purposes.