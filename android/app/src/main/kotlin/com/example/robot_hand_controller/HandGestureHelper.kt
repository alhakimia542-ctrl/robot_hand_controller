package com.example.robot_hand_controller

import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import kotlin.math.sqrt

object HandGestureHelper {

    // Calculates the Euclidean distance in 3D between two normalized landmarks
    private fun distance(p1: NormalizedLandmark, p2: NormalizedLandmark): Float {
        val dx = p1.x() - p2.x()
        val dy = p1.y() - p2.y()
        val dz = p1.z() - p2.z()
        return sqrt((dx * dx + dy * dy + dz * dz).toDouble()).toFloat()
    }

    fun getGesture(landmarks: List<NormalizedLandmark>): String {
        if (landmarks.size < 21) {
            return "HOLD"
        }

        // 1. Calculate extension status of index, middle, ring, and pinky fingers.
        // A finger is open if the tip is far from the MCP base joint relative to the PIP joint.
        val indexOpen = distance(landmarks[8], landmarks[5]) > distance(landmarks[6], landmarks[5]) * 1.3f
        val middleOpen = distance(landmarks[12], landmarks[9]) > distance(landmarks[10], landmarks[9]) * 1.3f
        val ringOpen = distance(landmarks[16], landmarks[13]) > distance(landmarks[14], landmarks[13]) * 1.3f
        val pinkyOpen = distance(landmarks[20], landmarks[17]) > distance(landmarks[18], landmarks[17]) * 1.3f

        // 2. Calculate extension status of the thumb.
        // Reference palm width is the distance between the index MCP (5) and pinky MCP (17)
        val palmWidth = distance(landmarks[5], landmarks[17])
        // The thumb is open if the tip (4) is far from the middle MCP (9)
        val thumbOpen = distance(landmarks[4], landmarks[9]) > distance(landmarks[2], landmarks[9]) * 1.2f &&
                        distance(landmarks[4], landmarks[5]) > palmWidth * 0.7f

        // 3. Gesture Classification Logic
        
        // Full Fist: All fingers (including thumb) closed
        if (!thumbOpen && !indexOpen && !middleOpen && !ringOpen && !pinkyOpen) {
            return "DC_FORWARD"
        }

        // Open Palm: All 5 fingers open
        if (thumbOpen && indexOpen && middleOpen && ringOpen && pinkyOpen) {
            return "DC_BACKWARD"
        }

        // Fist + Thumbs Up: Only thumb open, pointing upwards (tip Y < MCP Y)
        if (thumbOpen && !indexOpen && !middleOpen && !ringOpen && !pinkyOpen) {
            return if (landmarks[4].y() < landmarks[2].y()) {
                "LIFT_UP"
            } else {
                "LIFT_DOWN"
            }
        }

        // Index pointing Left/Right: Only index finger open.
        // Pointing Right: tip X > MCP X. Pointing Left: tip X < MCP X.
        if (!thumbOpen && indexOpen && !middleOpen && !ringOpen && !pinkyOpen) {
            return if (landmarks[8].x() > landmarks[5].x()) {
                "BASE_RIGHT"
            } else {
                "BASE_LEFT"
            }
        }

        // Index + Middle + Ring open: Extension command
        if (!thumbOpen && indexOpen && middleOpen && ringOpen && !pinkyOpen) {
            return "EXTEND"
        }

        // Middle + Ring + Pinky open: Retraction command
        if (!thumbOpen && !indexOpen && middleOpen && ringOpen && pinkyOpen) {
            return "RETRACT"
        }

        // Index + Middle open: Gripper operations (V sign vs touching)
        if (!thumbOpen && indexOpen && middleOpen && !ringOpen && !pinkyOpen) {
            val handScale = distance(landmarks[0], landmarks[9]) // Wrist to middle MCP
            if (handScale > 0.001f) {
                val tipDist = distance(landmarks[8], landmarks[12])
                val normalizedDist = tipDist / handScale
                return if (normalizedDist > 0.4f) {
                    "GRIP_OPEN" // V Sign
                } else {
                    "GRIP_CLOSED" // Touching
                }
            }
        }

        // Hand is visible but does not match any predefined gesture configuration perfectly
        return "HOLD"
    }
}
