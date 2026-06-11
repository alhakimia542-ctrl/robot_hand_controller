import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GestureDisplay extends StatelessWidget {
  final String activeCommand;
  final List<Map<String, dynamic>> commandLogs;
  final Function(String)? onManualCommand;

  const GestureDisplay({
    Key? key,
    required this.activeCommand,
    required this.commandLogs,
    this.onManualCommand,
  }) : super(key: key);

  // Helper to map command strings to their Arabic translation
  String _getArabicLabel(String command) {
    switch (command) {
      case 'DC_FORWARD':
        return 'التحرك للأمام';
      case 'DC_BACKWARD':
        return 'التحرك للخلف';
      case 'LIFT_UP':
        return 'رفع ذراع الرفع';
      case 'LIFT_DOWN':
        return 'خفض ذراع الرفع';
      case 'BASE_RIGHT':
        return 'دوران القاعدة يميناً';
      case 'BASE_LEFT':
        return 'دوران القاعدة يساراً';
      case 'EXTEND':
        return 'تمديد الذراع';
      case 'RETRACT':
        return 'سحب الذراع';
      case 'GRIP_OPEN':
        return 'فتح القابض';
      case 'GRIP_CLOSED':
        return 'إغلاق القابض';
      case 'ROTATE_RIGHT':
        return 'دوران يدوي يميناً';
      case 'ROTATE_LEFT':
        return 'دوران يدوي يساراً';
      case 'HOLD':
      default:
        return 'إيقاف مؤقت (انتظار)';
    }
  }

  // Get matching icon for the gesture
  IconData _getGestureIcon(String command) {
    switch (command) {
      case 'DC_FORWARD':
        return Icons.arrow_upward_rounded;
      case 'DC_BACKWARD':
        return Icons.arrow_downward_rounded;
      case 'LIFT_UP':
        return Icons.keyboard_double_arrow_up_rounded;
      case 'LIFT_DOWN':
        return Icons.keyboard_double_arrow_down_rounded;
      case 'BASE_RIGHT':
        return Icons.subdirectory_arrow_right_rounded;
      case 'BASE_LEFT':
        return Icons.subdirectory_arrow_left_rounded;
      case 'EXTEND':
        return Icons.unfold_more_rounded;
      case 'RETRACT':
        return Icons.unfold_less_rounded;
      case 'GRIP_OPEN':
        return Icons.open_in_full_rounded;
      case 'GRIP_CLOSED':
        return Icons.close_fullscreen_rounded;
      case 'ROTATE_RIGHT':
        return Icons.rotate_right_rounded;
      case 'ROTATE_LEFT':
        return Icons.rotate_left_rounded;
      case 'HOLD':
      default:
        return Icons.motion_photos_paused_rounded;
    }
  }

  // Get matching color theme for the gesture
  Color _getGestureColor(String command) {
    switch (command) {
      case 'DC_FORWARD':
        return const Color(0xFF00E676); // Vibrant Green
      case 'DC_BACKWARD':
        return const Color(0xFFFF3D00); // Vibrant Red-Orange
      case 'LIFT_UP':
      case 'LIFT_DOWN':
        return const Color(0xFF29B6F6); // Cyan/Light Blue
      case 'BASE_RIGHT':
      case 'BASE_LEFT':
        return const Color(0xFFFFC400); // Gold/Amber
      case 'EXTEND':
      case 'RETRACT':
        return const Color(0xFFE040FB); // Neon Purple
      case 'GRIP_OPEN':
      case 'GRIP_CLOSED':
        return const Color(0xFF00E5FF); // Bright Cyan
      case 'ROTATE_RIGHT':
      case 'ROTATE_LEFT':
        return const Color(0xFFFF9100); // Deep Orange
      case 'HOLD':
      default:
        return const Color(0xFF90A4AE); // Cool Blue-Grey
    }
  }

  @override
  Widget build(BuildContext context) {
    final gestureColor = _getGestureColor(activeCommand);
    final arabicLabel = _getArabicLabel(activeCommand);
    final gestureIcon = _getGestureIcon(activeCommand);

    return Column(
      children: [
        // 1. Active Gesture Status Card (Glassmorphic)
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'الإيماءة النشطة حالياً',
                    style: GoogleFonts.tajawal(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Dynamic Glowing Avatar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: gestureColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: gestureColor.withOpacity(0.35),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: gestureColor.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      gestureIcon,
                      size: 48,
                      color: gestureColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Active Gesture Name in Arabic
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: GoogleFonts.tajawal(
                      color: gestureColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    child: Text(arabicLabel),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'كود الحركة: $activeCommand',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Manual Rotation Override Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => onManualCommand?.call('ROTATE_RIGHT'),
                        icon: const Icon(Icons.rotate_right_rounded, size: 20),
                        label: Text(
                          'دوران يمين',
                          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => onManualCommand?.call('ROTATE_LEFT'),
                        icon: const Icon(Icons.rotate_left_rounded, size: 20),
                        label: Text(
                          'دوران يسار',
                          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 2. Live Command History Terminal
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'سجل الحركات الأخير',
                              style: GoogleFonts.tajawal(
                                color: Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'تحديث مباشر (50ms)',
                          style: GoogleFonts.tajawal(
                            color: Colors.white30,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 24),
                    Expanded(
                      child: commandLogs.isEmpty
                          ? Center(
                              child: Text(
                                'لا توجد حركات مسجلة بعد',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white30,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: commandLogs.length,
                              itemBuilder: (context, index) {
                                final log = commandLogs[index];
                                final cmd = log['command'] as String;
                                final timestamp = log['timestamp'] as DateTime;
                                final color = _getGestureColor(cmd);
                                final label = _getArabicLabel(cmd);

                                // Format timestamp: HH:mm:ss.SSS
                                final timeStr =
                                    '${timestamp.hour.toString().padLeft(2, '0')}:'
                                    '${timestamp.minute.toString().padLeft(2, '0')}:'
                                    '${timestamp.second.toString().padLeft(2, '0')}.'
                                    '${(timestamp.millisecond).toString().padLeft(3, '0')}';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      Text(
                                        timeStr,
                                        style: GoogleFonts.spaceMono(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '->',
                                        style: GoogleFonts.spaceMono(
                                          color: Colors.white24,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        label,
                                        style: GoogleFonts.tajawal(
                                          color: color,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        cmd,
                                        style: GoogleFonts.spaceMono(
                                          color: Colors.white54,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
