import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import '../utils/constants.dart';
import '../utils/rosbridge.dart';
import '../services/button_config_service.dart';

/// Right-side panel with joystick and 9 buttons
/// Top 2 rows (0-5): Control buttons - single tap
///   Row 0: Launch, Start, Wander
///   Row 1: Refresh, Play/Pause, Exit
/// Bottom row (6-8): Navigation buttons - double tap (waypoints/tasks)
class JoystickPanel extends StatefulWidget {
  final RosBridge rosBridge;
  final bool isPortrait;

  const JoystickPanel({super.key, required this.rosBridge, this.isPortrait = false});

  @override
  State<JoystickPanel> createState() => _JoystickPanelState();
}

class _JoystickPanelState extends State<JoystickPanel> {
  // Track which nav button is "armed" (first tap) - only for buttons 3-8
  int? armedIndex;

  // Track if system is paused (for play/pause toggle)
  bool _isPaused = true; // Start paused until launch/play

  // Raw ROS states (what's actually running)
  bool _wanderOn = false;
  bool _followOn = false;

  // Track if tracking/centering mode is active
  bool _trackingActive = false;

  // Derived display states (for button UI)
  // wander && !follow = Wander button ON
  // follow && !wander = Follow button ON
  // wander && follow = Patrol button ON
  bool get _wanderActive => _wanderOn && !_followOn;
  bool get _followingActive => _followOn && !_wanderOn;
  bool get _patrolActive => _wanderOn && _followOn;

  // Button configurations (only used for buttons 3-8)
  List<ButtonConfig> _configs = [];

  @override
  void initState() {
    super.initState();
    _loadConfigs();
    _setupVoiceStateListener();
  }

  void _setupVoiceStateListener() {
    widget.rosBridge.onVoiceStateChange = (state) {
      if (mounted) {
        setState(() {
          // "playing" = not paused, "paused" or "idle" = paused
          _isPaused = (state != 'playing');
        });
      }
    };

    // Listen to wander status from ROS (bool: true = active, false = disabled)
    widget.rosBridge.onWanderStatus = (active) {
      if (mounted && active != _wanderOn) {
        setState(() => _wanderOn = active);
        debugPrint('🚶 Wander: $active -> wanderOn=$_wanderOn (wander=$_wanderActive, patrol=$_patrolActive)');
      }
    };

    // Listen to person follower status from ROS
    widget.rosBridge.onPersonFollowerStatus = (active) {
      if (mounted && active != _followOn) {
        setState(() => _followOn = active);
        debugPrint('👤 Follow: $active -> followOn=$_followOn (follow=$_followingActive, patrol=$_patrolActive)');
      }
    };

    // Listen to center on human status
    widget.rosBridge.onCenterOnHumanStatus = (active) {
      if (mounted) {
        setState(() {
          _trackingActive = active;
        });
      }
    };
  }

  Future<void> _loadConfigs() async {
    final configs = await ButtonConfigService.loadConfigs();
    if (mounted) {
      setState(() => _configs = configs);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPortrait) {
      return _buildPortraitLayout();
    } else {
      return _buildLandscapeLayout();
    }
  }

  Widget _buildPortraitLayout() {
    return Container(
      height: AppDimensions.controlPanelWidth,
      padding: const EdgeInsets.only(left: AppSpacing.xs, right: AppSpacing.xs, bottom: AppSpacing.xs),
      color: AppColors.background,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: AppColors.background, width: 2),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final joystickSize = constraints.maxHeight;
              return Row(
                children: [
                  Expanded(child: _buildButtonGrid()),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: joystickSize,
                    height: joystickSize,
                    child: _buildJoystick(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Container(
      width: AppDimensions.controlPanelWidth,
      padding: const EdgeInsets.only(right: AppSpacing.xs, bottom: AppSpacing.xs),
      color: AppColors.background,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: AppColors.background, width: 2),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final joystickSize = constraints.maxWidth;
              return Column(
                children: [
                  SizedBox(
                    width: joystickSize,
                    height: joystickSize,
                    child: _buildJoystick(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(child: _buildButtonGrid()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildJoystick() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.background, width: 2),
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
        Joystick(
          mode: JoystickMode.all,
          base: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.circular),
            ),
          ),
          stick: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          listener: (details) {
            widget.rosBridge.publishCmdVel(details.x, details.y);
          },
        ),
      ],
    );
  }

  Widget _buildButtonGrid() {
    return Column(
      children: List.generate(3, (row) {
        return Expanded(
          child: Row(
            children: List.generate(3, (col) {
              final index = row * 3 + col;

              // All buttons are now control buttons
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: _buildControlButton(index),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildControlButton(int index) {
    switch (index) {
      case 0: // Launch - green (full startup sequence)
        return _ControlButton(
          icon: Icons.rocket_launch,
          label: 'Launch',
          color: Colors.green,
          onTap: () {
            widget.rosBridge.publishLaunch();
          },
        );
      case 1: // Start - blue (quick face transition, no AI)
        return _ControlButton(
          icon: Icons.face,
          label: 'Start',
          color: AppColors.accent,
          onTap: () {
            widget.rosBridge.publishStart();
          },
        );
      case 2: // Wander - orange/red toggle (wander only, no person detection)
        return _ControlButton(
          // Display: only show ON when wander alone (not patrol)
          icon: _wanderActive ? Icons.explore_off : Icons.explore,
          label: _wanderActive ? 'Stop' : 'Wander',
          color: _wanderActive ? Colors.red : AppColors.dangerBright,
          onTap: () {
            // Action: use direct state so it always works on first tap
            debugPrint('🔘 Wander tap: _wanderOn=$_wanderOn');
            if (_wanderOn) {
              widget.rosBridge.deactivateWanderMode();
            } else {
              widget.rosBridge.publishCenterOnHuman(false);
              widget.rosBridge.activateWanderMode();
            }
          },
        );
      case 3: // Refresh - green
        return _ControlButton(
          icon: Icons.refresh,
          label: 'Refresh',
          color: Colors.green,
          onTap: () {
            widget.rosBridge.publishRefresh();
          },
        );
      case 4: // Play/Pause - blue (AI conversation control)
        return _ControlButton(
          icon: _isPaused ? Icons.play_arrow : Icons.pause,
          label: _isPaused ? 'Play' : 'Pause',
          color: AppColors.accent,
          onTap: () {
            if (_isPaused) {
              widget.rosBridge.publishPlay();
            } else {
              widget.rosBridge.publishPause();
            }
            setState(() => _isPaused = !_isPaused);
          },
        );
      case 5: // Exit - orange
        return _ControlButton(
          icon: Icons.close,
          label: 'Exit',
          color: AppColors.dangerBright,
          onTap: () {
            widget.rosBridge.publishExit();
          },
        );
      case 6: // Following - green toggle
        return _ControlButton(
          // Display: only show ON when follow alone (not patrol)
          icon: _followingActive ? Icons.person_off : Icons.person,
          label: _followingActive ? 'Stop' : 'Follow',
          color: _followingActive ? Colors.red : Colors.green,
          onTap: () {
            // Action: use direct state so it always works on first tap
            debugPrint('🔘 Follow tap: _followOn=$_followOn');
            if (_followOn) {
              widget.rosBridge.deactivateFollowMode();
            } else {
              widget.rosBridge.publishCenterOnHuman(false);
              widget.rosBridge.activateFollowMode();
            }
          },
        );
      case 7: // Tracking/Centering - blue toggle (mutually exclusive)
        return _ControlButton(
          icon: _trackingActive ? Icons.center_focus_weak : Icons.center_focus_strong,
          label: _trackingActive ? 'Stop' : 'Track',
          color: _trackingActive ? Colors.red : AppColors.accent,
          onTap: () {
            debugPrint('🔘 Track tap: _trackingActive=$_trackingActive');
            if (_trackingActive) {
              widget.rosBridge.publishCenterOnHuman(false);
            } else {
              // Stop other modes first
              widget.rosBridge.deactivateAllModes();
              widget.rosBridge.publishCenterOnHuman(true);
            }
          },
        );
      case 8: // Patrol - orange toggle (wander + person detection)
        return _ControlButton(
          // Display: show ON when both wander and follow are running
          icon: _patrolActive ? Icons.search_off : Icons.search,
          label: _patrolActive ? 'Stop' : 'Patrol',
          color: _patrolActive ? Colors.red : AppColors.dangerBright,
          onTap: () {
            // Action: stop if either is running, start if neither
            final eitherOn = _wanderOn || _followOn;
            debugPrint('🔘 Patrol tap: _patrolActive=$_patrolActive (wander=$_wanderOn, follow=$_followOn)');
            if (eitherOn) {
              widget.rosBridge.deactivatePatrolMode();
            } else {
              widget.rosBridge.publishCenterOnHuman(false);
              widget.rosBridge.activatePatrolMode();
            }
          },
        );
      default:
        return const SizedBox();
    }
  }

  void _executeNavButton(ButtonConfig config) {
    debugPrint("Nav button engaged: ${config.actionType} -> ${config.value}");

    switch (config.actionType) {
      case 'waypoint':
        if (config.value != null) {
          widget.rosBridge.publishGoToWaypoint(config.value!);
        }
        break;
      case 'task':
        if (config.value != null) {
          final sequence = widget.rosBridge.sequences.firstWhere(
            (s) => s.name == config.value,
            orElse: () => SavedSequence(name: '', waypointNames: []),
          );
          if (sequence.waypointNames.isNotEmpty) {
            widget.rosBridge.publishNavigateSequence(sequence.waypointNames);
          }
        }
        break;
      case 'none':
      default:
        break;
    }
  }
}

/// Control button - single tap, colored background
class _ControlButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(_pressed ? 0.3 : 0.15),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: widget.color,
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: widget.color, size: 22),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.color,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navigation button - double tap to activate
class _NavButton extends StatefulWidget {
  final int index;
  final ButtonConfig config;
  final int? armedIndex;
  final void Function(int?) onArm;
  final VoidCallback onEngage;

  const _NavButton({
    required this.index,
    required this.config,
    required this.armedIndex,
    required this.onArm,
    required this.onEngage,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool activated = false;

  void _handleTap() {
    if (widget.armedIndex != widget.index) {
      widget.onArm(widget.index);
      setState(() => activated = false);
    } else {
      widget.onEngage();
      setState(() => activated = true);

      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          widget.onArm(null);
          setState(() => activated = false);
        }
      });
    }
  }

  IconData _getIcon() {
    switch (widget.config.actionType) {
      case 'waypoint':
        return Icons.location_on;
      case 'task':
        return Icons.playlist_play;
      case 'none':
      default:
        return Icons.add;
    }
  }

  String _getLabel() {
    switch (widget.config.actionType) {
      case 'waypoint':
      case 'task':
        return widget.config.value ?? '';
      case 'none':
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArmed = widget.armedIndex == widget.index;
    final isConfigured = widget.config.actionType != 'none';
    final label = _getLabel();

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: activated ? AppColors.accent : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            width: 2,
            color: isArmed || activated ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Center(
          child: isConfigured
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getIcon(),
                      color: activated ? AppColors.surface : AppColors.textSecondary,
                      size: 20,
                    ),
                    if (label.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          color: activated ? AppColors.surface : AppColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                )
              : Icon(
                  Icons.add,
                  color: AppColors.textMuted.withOpacity(0.3),
                  size: 20,
                ),
        ),
      ),
    );
  }
}
