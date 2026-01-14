import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:millie_control/utils/rosbridge.dart';

class ControlPanel extends StatefulWidget {
  const ControlPanel({super.key});

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  late RosBridge rosBridge;

  // Track which button is "armed"
  int? armedIndex;

  @override
  void initState() {
    super.initState();
    // ✅ connect to ROS
    rosBridge = RosBridge("ws://192.168.1.14:9090");
    rosBridge.connect();
  }

  @override
  void dispose() {
    rosBridge.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.only(top: 5, right: 5, bottom: 5),
      color: const Color(0xFF2C2C2C),
      child: Column(
        children: [
          // --- Header Bar ---
          Container(
            height: 48,
            width: double.infinity,
            color: const Color(0xFF2C2C2C),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings,
                        color: Colors.white70, size: 22),
                    onPressed: () {
                      debugPrint("Settings tapped");
                    },
                  ),
                ],
              ),
            ),
          ),

          // --- Control Panel Frame ---
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF2C2C2C),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF1C1C1C),
                ),
                child: Column(
                  children: [
                    // --- Joystick (square, full width) ---
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 10, left: 10, right: 10),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = constraints.maxWidth; // lock to width
                          return SizedBox(
                            width: size,
                            height: size,
                            child: Stack(
                              children: [
                                // --- Inner Frame ---
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFF2C2C2C),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),

                                // --- Touch Joystick ---
                                Joystick(
                                  mode: JoystickMode.all,
                                  base: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  listener: (details) {
                                    rosBridge.publishCmdVel(
                                        details.x, details.y);
                                    debugPrint(
                                        "📤 Joystick: x=${details.x}, y=${details.y}");
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // --- Buttons (take remaining space safely) ---
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Column(
                          children: List.generate(3, (row) {
                            return Expanded(
                              child: Row(
                                children: List.generate(3, (col) {
                                  final index = row * 3 + col;

                                  // --- Icon selection ---
                                  IconData? icon;
                                  if (index == 0) {
                                    icon = Icons.home; // Default
                                  } else if (index == 1) {
                                    icon = Icons.pan_tool; // Greeter
                                  } else if (index == 2) {
                                    icon = Icons.local_bar; // Bartender
                                  } else if (index == 3) {
                                    icon = Icons.tag_faces; // Host
                                  } else if (index == 6) {
                                    icon = Icons.wb_sunny; // Wake
                                  } else if (index == 7) {
                                    icon = Icons.power_settings_new; // Shutdown
                                  } else if (index == 8) {
                                    icon = Icons.bedtime; // Sleep
                                  }

                                  // --- Color logic ---
                                  final isShutdown = index == 7;
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: DoubleTapButton(
                                        index: index,
                                        armedIndex: armedIndex,
                                        onArm: (i) => setState(() => armedIndex = i),
                                        fillColor: isShutdown
                                            ? const Color(0xFFAA4400)
                                            : const Color(0xFF2C2C2C),
                                        highlightColor: isShutdown
                                            ? const Color(0xFFFF6600)
                                            : const Color(0xFF00BFFF),
                                        icon: icon,
                                        onEngage: () {
                                          if (index == 0) {
                                            rosBridge.publishDefaultAgent();
                                            debugPrint("🏠 Default Agent engaged!");
                                          } else if (index == 1) {
                                            rosBridge.publishGreeterAgent();
                                            debugPrint("👋 Greeter Agent engaged!");
                                          } else if (index == 2) {
                                            rosBridge.publishBartenderAgent();
                                            debugPrint("🍸 Bartender Agent engaged!");
                                          } else if (index == 3) {
                                            rosBridge.publishHostAgent();
                                            debugPrint("😄 Host Agent engaged!");
                                          } else if (index == 6) {
                                            rosBridge.publishWake();
                                            debugPrint("🌞 Wake command engaged!");
                                          } else if (index == 7) {
                                            rosBridge.publishShutdown();
                                            debugPrint("⚡ Power command engaged!");
                                          } else if (index == 8) {
                                            rosBridge.publishSleep();
                                            debugPrint("🌙 Sleep command engaged!");
                                          } else {
                                            debugPrint("Button $index engaged");
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Custom Double-Tap Button ---
class DoubleTapButton extends StatefulWidget {
  final int index;
  final int? armedIndex;
  final void Function(int?) onArm; // allow null now
  final Color fillColor;
  final Color highlightColor;
  final VoidCallback onEngage;
  final IconData? icon; // ✅ new

  const DoubleTapButton({
    super.key,
    required this.index,
    required this.armedIndex,
    required this.onArm,
    required this.fillColor,
    required this.highlightColor,
    required this.onEngage,
    this.icon,
  });

  @override
  State<DoubleTapButton> createState() => _DoubleTapButtonState();
}

class _DoubleTapButtonState extends State<DoubleTapButton> {
  bool activated = false;

  void _handleTap() {
    if (widget.armedIndex != widget.index) {
      // Arm this button (exclusive)
      widget.onArm(widget.index);
      setState(() => activated = false);
    } else {
      // Second tap = engage + flash
      widget.onEngage();
      setState(() => activated = true);

      // Auto reset flash + disarm all buttons after 1s
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          widget.onArm(null); // clear armedIndex
          setState(() => activated = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArmed = widget.armedIndex == widget.index;
    final baseColor = widget.fillColor;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: activated ? widget.highlightColor : baseColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            width: 2,
            color: isArmed || activated
                ? widget.highlightColor
                : const Color(0xFF555555),
          ),
        ),
        child: widget.icon != null
            ? Center(
                child: Icon(
                  widget.icon,
                  color: const Color(0xFF1C1C1C), // dark gray icon
                  size: 28,
                ),
              )
            : null,
      ),
    );
  }
}
