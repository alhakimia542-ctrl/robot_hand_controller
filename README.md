# 🤖 robot_hand_controller
A full-stack robotics project integrating a mobile Flutter application, Google MediaPipe for real-time AI hand gesture recognition, and an Arduino-controlled 4-DOF robotic arm with a 4-wheel drive base.

## 🎥 Project Demo
*(سيتم إضافة رابط فيديو اليوتيوب هنا يوضح حركة الروبوت واستجابته للإيماءات)*
[![Watch the video](https://img.youtube.com/vi/YOUR_VIDEO_ID/hqdefault.jpg)](https://www.youtube.com/watch?v=YOUR_VIDEO_ID)

## 📸 Hardware Setup
*(سيتم وضع صورة واضحة للروبوت وتوصيلاته هنا)*
![Robot Setup](link_to_your_image.jpg)

## 🛠️ Tech Stack & Components
* **Software:** Dart, Flutter, Google ML Kit / MediaPipe, C++ (Arduino).
* **Hardware:** Arduino UNO, HC-05 Bluetooth Module, L298N Motor Driver, 4x DC Motors, 4x Servo Motors (Base, Lift, Extend, Grip), 2x 18650 Li-ion Batteries.

## 🧠 System Architecture
1. **Computer Vision:** The `robot_hand_controller` app uses the device's front camera (`YUV420` format for high performance) to stream frames to the `hand_landmarker` AI model.
2. **Gesture Logic:** Custom algorithms calculate the 3D Euclidean distance between finger joints to determine open/closed states and translate them into explicit string commands.
3. **Communication:** Commands are sent every 50ms via Classic Bluetooth (HC-05) to the Arduino firmware.
4. **Hardware Control:** The Arduino parses the serial stream using a `\n` terminator protocol, mapping commands to smooth servo movements and dynamic PWM speed control for the DC motors.

## 📡 Control Protocol (Command Map)
| Gesture | Sent Command | Robot Action |
| :--- | :--- | :--- |
| Closed Fist | `DC_FORWARD` | Moves all wheels forward at a stable speed. |
| Open Palm | `DC_BACKWARD` | Moves backward with increased PWM torque. |
| Index Up | `BASE_RIGHT` / `LEFT` | Rotates the base servo left or right. |
| Two Fingers (Pinch) | `GRIP_OPEN` / `CLOSED`| Opens or closes the mechanical claw. |
| No Hand Detected | `HOLD` | Instant emergency stop for all motors. |