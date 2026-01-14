import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// The selected view in the main content area
enum MainView { camera, map, locations, tickets, chat, settings }

/// Left icon rail with navigation views
class IconRail extends StatelessWidget {
  final MainView selectedView;
  final ValueChanged<MainView> onViewChanged;
  final bool joystickVisible;
  final VoidCallback onJoystickToggle;
  final VoidCallback onEstop;
  final VoidCallback onShutdown;
  final VoidCallback onReboot;
  final bool rosConnected;
  final VoidCallback? onSettingsSidebarToggle;
  final bool showControls;  // Show bottom controls (joystick, status, power) - false in landscape

  const IconRail({
    super.key,
    required this.selectedView,
    required this.onViewChanged,
    required this.joystickVisible,
    required this.onJoystickToggle,
    required this.onEstop,
    required this.onShutdown,
    required this.onReboot,
    this.rosConnected = false,
    this.onSettingsSidebarToggle,
    this.showControls = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimensions.iconRailWidth,
      color: AppColors.background,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          
          // E-STOP button (top, always visible, prominent)
          _EstopButton(onPressed: onEstop),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Camera view
          _RailButton(
            icon: Icons.videocam,
            label: 'Camera',
            isActive: selectedView == MainView.camera,
            onPressed: () => onViewChanged(MainView.camera),
          ),
          
          const SizedBox(height: AppSpacing.sm),
          
          // Map view
          _RailButton(
            icon: Icons.map,
            label: 'Map',
            isActive: selectedView == MainView.map,
            onPressed: () => onViewChanged(MainView.map),
          ),
          
          const SizedBox(height: AppSpacing.sm),
          
          // Tasks view
          _RailButton(
            icon: Icons.assignment,
            label: 'Tasks',
            isActive: selectedView == MainView.locations,
            onPressed: () => onViewChanged(MainView.locations),
          ),
          
          const SizedBox(height: AppSpacing.sm),
          
          // Tickets view
          _RailButton(
            icon: Icons.receipt_long,
            label: 'Tickets',
            isActive: selectedView == MainView.tickets,
            onPressed: () => onViewChanged(MainView.tickets),
          ),
          
          const SizedBox(height: AppSpacing.sm),
          
          // Chat view
          _RailButton(
            icon: Icons.chat_bubble_outline,
            label: 'Chat',
            isActive: selectedView == MainView.chat,
            onPressed: () => onViewChanged(MainView.chat),
          ),
          
          const SizedBox(height: AppSpacing.sm),
          
          // Settings (with the page buttons)
          _RailButton(
            icon: Icons.settings,
            label: 'Settings',
            isActive: selectedView == MainView.settings,
            onPressed: () {
              if (selectedView == MainView.settings && onSettingsSidebarToggle != null) {
                // Already on settings - toggle sidebar
                onSettingsSidebarToggle!();
              } else {
                // Navigate to settings
                onViewChanged(MainView.settings);
              }
            },
          ),
          
          // Only show bottom controls in portrait mode
          if (showControls) ...[
            const Spacer(),
            
            // Joystick toggle
            _RailButton(
              icon: Icons.gamepad,
              label: 'Drive',
              isActive: joystickVisible,
              onPressed: onJoystickToggle,
            ),
            
            const SizedBox(height: AppSpacing.sm),
            
            // Connection status indicator
            _ConnectionIndicator(connected: rosConnected),
            
            const SizedBox(height: AppSpacing.sm),
            
            // Power (at bottom)
            _PowerButton(onShutdown: onShutdown, onReboot: onReboot),
            
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// Right control rail for landscape mode (Power, Status, Joystick - top aligned)
class ControlRail extends StatelessWidget {
  final bool joystickVisible;
  final VoidCallback onJoystickToggle;
  final VoidCallback onShutdown;
  final VoidCallback onReboot;
  final bool rosConnected;

  const ControlRail({
    super.key,
    required this.joystickVisible,
    required this.onJoystickToggle,
    required this.onShutdown,
    required this.onReboot,
    this.rosConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimensions.iconRailWidth,
      color: AppColors.background,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          
          // Power (top)
          _PowerButton(onShutdown: onShutdown, onReboot: onReboot),
          
          const SizedBox(height: AppSpacing.sm),
          
          // Connection status indicator
          _ConnectionIndicator(connected: rosConnected),
          
          const SizedBox(height: AppSpacing.sm),
          
          // Joystick toggle
          _RailButton(
            icon: Icons.gamepad,
            label: 'Drive',
            isActive: joystickVisible,
            onPressed: onJoystickToggle,
          ),
          
          const Spacer(),
        ],
      ),
    );
  }
}

/// Connection status indicator
class _ConnectionIndicator extends StatelessWidget {
  final bool connected;
  
  const _ConnectionIndicator({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: connected ? 'ROS Connected' : 'ROS Disconnected',
      child: Container(
        width: 48,
        height: 25,
        decoration: BoxDecoration(
          color: (connected ? AppColors.success : AppColors.textMuted).withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: connected ? AppColors.success : AppColors.textMuted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              connected ? 'ON' : 'OFF',
              style: TextStyle(
                color: connected ? AppColors.success : AppColors.textMuted,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// E-STOP button - large, red, always accessible
class _EstopButton extends StatelessWidget {
  final VoidCallback onPressed;
  
  const _EstopButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.dangerBright, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.danger.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.stop_circle,
            color: Colors.white,
            size: 31,
          ),
        ),
      ),
    );
  }
}

/// Standard rail button - always visible rounded square
class _RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _RailButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent.withOpacity(0.2) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: isActive ? AppColors.accent : AppColors.border,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: isActive ? AppColors.accent : AppColors.textSecondary,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

/// Power button with options modal
class _PowerButton extends StatelessWidget {
  final VoidCallback onShutdown;
  final VoidCallback onReboot;
  
  const _PowerButton({required this.onShutdown, required this.onReboot});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Power',
      child: GestureDetector(
        onTap: () => _showPowerOptionsDialog(context),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: const Center(
            child: Icon(
              Icons.power_settings_new,
              color: AppColors.textSecondary,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  void _showPowerOptionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        title: const Text(
          'Power Options',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shutdown button
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _confirmShutdown(context);
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(
                    color: AppColors.danger.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.power_settings_new, color: AppColors.danger, size: 24),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Shutdown',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Reboot button
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _confirmReboot(context);
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(
                    color: AppColors.accent.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restart_alt, color: AppColors.accent, size: 24),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Reboot',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmShutdown(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        title: const Text(
          'Confirm Shutdown',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will safely power off the robot computer.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () {
              Navigator.pop(context);
              onShutdown();
            },
            child: const Text('Shutdown', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmReboot(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        title: const Text(
          'Confirm Reboot',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will restart the robot computer.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
            ),
            onPressed: () {
              Navigator.pop(context);
              onReboot();
            },
            child: const Text('Reboot', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

