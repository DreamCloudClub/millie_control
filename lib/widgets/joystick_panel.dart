import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import '../utils/constants.dart';
import '../utils/rosbridge.dart';

/// Right-side panel with joystick and 9 programmable buttons
class JoystickPanel extends StatefulWidget {
  final RosBridge rosBridge;
  final bool isPortrait;
  
  const JoystickPanel({super.key, required this.rosBridge, this.isPortrait = false});

  @override
  State<JoystickPanel> createState() => _JoystickPanelState();
}

class _JoystickPanelState extends State<JoystickPanel> {
  // Track which button is "armed" (first tap)
  int? armedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.isPortrait) {
      return _buildPortraitLayout();
    } else {
      return _buildLandscapeLayout();
    }
  }

  /// Portrait: Horizontal layout - Joystick on left, button grid on right
  Widget _buildPortraitLayout() {
    return Container(
      height: AppDimensions.controlPanelWidth, // Same size, but now as height
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
              // Calculate joystick size: available height minus any internal adjustments
              final joystickSize = constraints.maxHeight;
              return Row(
                children: [
                  // 9 programmable buttons (3x3 grid on the left)
                  Expanded(
                    child: _buildButtonGrid(),
                  ),
                  
                  const SizedBox(width: AppSpacing.sm),
                  
                  // Joystick area (square, on the right)
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

  /// Landscape: Vertical layout - Joystick on top, button grid below
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
              // Calculate joystick size: available width
              final joystickSize = constraints.maxWidth;
              return Column(
                children: [
                  // Joystick area (square, takes width)
                  SizedBox(
                    width: joystickSize,
                    height: joystickSize,
                    child: _buildJoystick(),
                  ),
                  
                  const SizedBox(height: AppSpacing.sm),
                  
                  // 9 programmable buttons (3x3 grid)
                  Expanded(
                    child: _buildButtonGrid(),
                  ),
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
        // Border frame
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.background,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
        // Touch joystick
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
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: _ProgrammableButton(
                    index: index,
                    armedIndex: armedIndex,
                    onArm: (i) => setState(() => armedIndex = i),
                    onEngage: () => _executeButton(index),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  void _executeButton(int index) {
    // TODO: Load from saved configuration
    // For now, just log
    debugPrint("Button ${index + 1} engaged!");
    
    // Placeholder: navigate to waypoint
    // widget.rosBridge.publishNavGoal(waypoint: "button_$index");
  }
}

/// Double-tap programmable button
class _ProgrammableButton extends StatefulWidget {
  final int index;
  final int? armedIndex;
  final void Function(int?) onArm;
  final VoidCallback onEngage;

  const _ProgrammableButton({
    required this.index,
    required this.armedIndex,
    required this.onArm,
    required this.onEngage,
  });

  @override
  State<_ProgrammableButton> createState() => _ProgrammableButtonState();
}

class _ProgrammableButtonState extends State<_ProgrammableButton> {
  bool activated = false;

  void _handleTap() {
    if (widget.armedIndex != widget.index) {
      // First tap: arm this button
      widget.onArm(widget.index);
      setState(() => activated = false);
    } else {
      // Second tap: engage action
      widget.onEngage();
      setState(() => activated = true);

      // Auto reset after animation
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          widget.onArm(null);
          setState(() => activated = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArmed = widget.armedIndex == widget.index;
    
    // TODO: Load icon/label from configuration
    // For now, show button number
    final buttonNumber = widget.index + 1;

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
          child: Text(
            '$buttonNumber',
            style: TextStyle(
              color: activated ? AppColors.surface : AppColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
