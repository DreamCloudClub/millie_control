import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/robot_api.dart';
import 'top_notification.dart';

/// Full-screen robot control panel - start/stop ROS, view status, save maps
class RobotControlPanel extends StatefulWidget {
  final RobotApi api;
  final VoidCallback? onRosStarted;
  
  const RobotControlPanel({
    super.key, 
    required this.api,
    this.onRosStarted,
  });

  @override
  State<RobotControlPanel> createState() => _RobotControlPanelState();
}

class _RobotControlPanelState extends State<RobotControlPanel> {
  RobotStatus? _status;
  List<MapInfo> _maps = [];
  String? _activeMap;
  bool _loading = false;
  String? _error;
  Timer? _pollTimer;
  
  @override
  void initState() {
    super.initState();
    _refresh();
    // Poll status every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }
  
  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _refresh() async {
    final status = await widget.api.getStatus();
    final mapResult = await widget.api.listMaps();
    
    if (mounted) {
      setState(() {
        _status = status;
        _maps = mapResult.maps;
        _activeMap = mapResult.activeMap;
        _error = status == null ? 'Cannot connect to robot' : null;
      });
    }
  }
  
  Future<void> _startRos(String mode) async {
    setState(() => _loading = true);
    
    final result = await widget.api.startRos(mode: mode);
    
    if (mounted) {
      setState(() => _loading = false);
      
      if (result.success) {
        _showSnackBar('ROS starting in $mode mode...', AppColors.success);
        widget.onRosStarted?.call();
      } else {
        _showSnackBar('Failed: ${result.message}', AppColors.danger);
      }
      
      await _refresh();
    }
  }
  
  Future<void> _stopRos() async {
    setState(() => _loading = true);
    
    final result = await widget.api.stopRos();
    
    if (mounted) {
      setState(() => _loading = false);
      _showSnackBar(result.success ? 'ROS stopped' : 'Failed: ${result.message}',
          result.success ? AppColors.warning : AppColors.danger);
      await _refresh();
    }
  }
  
  Future<void> _saveMap() async {
    final controller = TextEditingController(text: 'millie_map');
    
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Save Map', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Map name',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (name != null && name.isNotEmpty) {
      setState(() => _loading = true);
      final result = await widget.api.saveMap(name);
      setState(() => _loading = false);
      
      _showSnackBar(
        result.success ? 'Map saved: $name' : 'Failed: ${result.message}',
        result.success ? AppColors.success : AppColors.danger,
      );
      
      await _refresh();
    }
  }
  
  Future<void> _selectMap(String name) async {
    setState(() => _loading = true);
    final result = await widget.api.selectMap(name);
    setState(() => _loading = false);
    
    if (result.success) {
      _showSnackBar('Map "$name" selected for navigation', AppColors.success);
    } else {
      _showSnackBar('Failed: ${result.message}', AppColors.danger);
    }
    
    await _refresh();
  }
  
  Future<void> _deleteMap(String name) async {
    // Confirm deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Map?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Are you sure you want to delete "$name"?', 
          style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _loading = true);
    final result = await widget.api.deleteMap(name);
    setState(() => _loading = false);
    
    if (result.success) {
      _showSnackBar('Map "$name" deleted', AppColors.warning);
    } else {
      _showSnackBar('Failed: ${result.message}', AppColors.danger);
    }
    
    await _refresh();
  }
  
  void _showSnackBar(String message, Color color) {
    TopNotification.show(context, message: message, backgroundColor: color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: _error != null
          ? _buildErrorState()
          : _status == null
              ? _buildLoadingState()
              : _buildContent(),
    );
  }
  
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: AppColors.danger, size: 64),
          const SizedBox(height: AppSpacing.lg),
          Text(_error!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 18)),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Make sure the robot is powered on\nand connected to the network',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.accent),
          SizedBox(height: AppSpacing.lg),
          Text('Connecting to robot...', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    final status = _status!;
    
    return Row(
      children: [
        // Left side - Controls
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status header
                _StatusHeader(status: status),
                
                const SizedBox(height: AppSpacing.xl),
                
                // Mode buttons
                const Text('Launch Mode', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.md),
                
                _ModeButtonRow(
                  currentMode: status.mode,
                  rosRunning: status.rosRunning,
                  loading: _loading,
                  onStart: _startRos,
                  onStop: _stopRos,
                ),
                
                const SizedBox(height: AppSpacing.xl),
                
                // Map controls (only in mapping mode)
                if (status.mode == 'mapping') ...[
                  const Text('Mapping', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.md),
                  
                  _ActionCard(
                    icon: Icons.save,
                    title: 'Save Map',
                    subtitle: 'Save current SLAM map to disk',
                    color: AppColors.success,
                    onTap: _saveMap,
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                ],
                
                // Saved maps
                Row(
                  children: [
                    const Text('Saved Maps', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (_activeMap != null)
                      Text('Active: $_activeMap', style: const TextStyle(color: AppColors.accent, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                
                if (_maps.isEmpty)
                  const Text('No maps saved yet. Start in Mapping mode to create one!', 
                    style: TextStyle(color: AppColors.textMuted))
                else
                  ..._maps.map((m) => _MapCard(
                    map: m,
                    isActive: m.name == _activeMap,
                    onSelect: () => _selectMap(m.name),
                    onDelete: () => _deleteMap(m.name),
                  )),
              ],
            ),
          ),
        ),
        
        // Right side - System info & logs
        Container(
          width: 280,
          color: AppColors.background,
          child: Column(
            children: [
              // System stats
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _SystemStats(system: status.system),
              ),
              
              const Divider(color: AppColors.border),
              
              // Log viewer
              Expanded(
                child: _LogViewer(logTail: status.logTail),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Status header with connection indicator
class _StatusHeader extends StatelessWidget {
  final RobotStatus status;
  
  const _StatusHeader({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: status.rosRunning ? AppColors.success : AppColors.border,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: status.rosRunning 
                  ? AppColors.success.withOpacity(0.2)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Icon(
              status.rosRunning ? Icons.play_circle : Icons.stop_circle,
              color: status.rosRunning ? AppColors.success : AppColors.textMuted,
              size: 36,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.rosRunning ? 'ROS Running' : 'ROS Stopped',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.rosRunning
                      ? 'Mode: ${status.mode.toUpperCase()} • PID: ${status.pid}'
                      : 'Ready to launch',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (status.rosRunning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: _getModeColor(status.mode).withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppRadius.circular),
              ),
              child: Text(
                status.mode.toUpperCase(),
                style: TextStyle(
                  color: _getModeColor(status.mode),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Color _getModeColor(String mode) {
    switch (mode) {
      case 'mapping': return AppColors.warning;
      case 'nav': return AppColors.success;
      default: return AppColors.accent;
    }
  }
}

/// Row of mode selection buttons
class _ModeButtonRow extends StatelessWidget {
  final String currentMode;
  final bool rosRunning;
  final bool loading;
  final Function(String) onStart;
  final VoidCallback onStop;
  
  const _ModeButtonRow({
    required this.currentMode,
    required this.rosRunning,
    required this.loading,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _ModeButton(
              icon: Icons.gamepad,
              label: 'Manual',
              description: 'Joystick control only',
              mode: 'main',
              isActive: rosRunning && currentMode == 'main',
              loading: loading,
              onTap: () => onStart('main'),
            )),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _ModeButton(
              icon: Icons.explore,
              label: 'Mapping',
              description: 'Create new map with SLAM',
              mode: 'mapping',
              isActive: rosRunning && currentMode == 'mapping',
              loading: loading,
              onTap: () => onStart('mapping'),
            )),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _ModeButton(
              icon: Icons.navigation,
              label: 'Navigate',
              description: 'Autonomous navigation',
              mode: 'nav',
              isActive: rosRunning && currentMode == 'nav',
              loading: loading,
              onTap: () => onStart('nav'),
            )),
          ],
        ),
        
        if (rosRunning) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loading ? null : onStop,
              icon: const Icon(Icons.stop, color: AppColors.danger),
              label: const Text('Stop ROS', style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
                padding: const EdgeInsets.all(AppSpacing.md),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Individual mode button
class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final String mode;
  final bool isActive;
  final bool loading;
  final VoidCallback onTap;
  
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.mode,
    required this.isActive,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withOpacity(0.15) : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: isActive ? AppColors.accent : AppColors.border,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? AppColors.accent : AppColors.textSecondary, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.accent : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Action card (like Save Map)
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}

/// Map card with select and delete actions
class _MapCard extends StatelessWidget {
  final MapInfo map;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  
  const _MapCard({
    required this.map,
    required this.isActive,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withOpacity(0.1) : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(
            color: isActive ? AppColors.accent : AppColors.border,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Checkmark or map icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(
                isActive ? Icons.check : Icons.map,
                color: isActive ? Colors.white : AppColors.textMuted,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(map.name, style: TextStyle(
                        color: isActive ? AppColors.accent : AppColors.textPrimary, 
                        fontWeight: FontWeight.bold,
                      )),
                      if (isActive) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(AppRadius.small),
                          ),
                          child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    _formatDate(map.modifiedDate),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.textMuted,
              onPressed: onDelete,
              tooltip: 'Delete map',
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// System stats panel
class _SystemStats extends StatelessWidget {
  final SystemInfo system;
  
  const _SystemStats({required this.system});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('System', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.md),
        
        _StatRow(
          icon: Icons.thermostat,
          label: 'CPU Temp',
          value: system.cpuTemp != null ? '${system.cpuTemp!.toStringAsFixed(1)}°C' : '--',
          color: _getTempColor(system.cpuTemp),
        ),
        _StatRow(
          icon: Icons.speed,
          label: 'CPU Load',
          value: system.cpuLoad != null ? system.cpuLoad!.toStringAsFixed(2) : '--',
        ),
        _StatRow(
          icon: Icons.memory,
          label: 'Memory',
          value: system.memUsagePercent != null 
              ? '${system.memUsagePercent!.toStringAsFixed(0)}%'
              : '--',
        ),
        _StatRow(
          icon: Icons.timer,
          label: 'Uptime',
          value: system.uptimeHours != null 
              ? '${system.uptimeHours!.toStringAsFixed(1)}h'
              : '--',
        ),
      ],
    );
  }
  
  Color _getTempColor(double? temp) {
    if (temp == null) return AppColors.textMuted;
    if (temp > 70) return AppColors.danger;
    if (temp > 60) return AppColors.warning;
    return AppColors.success;
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const Spacer(),
          Text(value, style: TextStyle(color: color ?? AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Log viewer
class _LogViewer extends StatelessWidget {
  final String logTail;
  
  const _LogViewer({required this.logTail});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: const [
              Icon(Icons.terminal, color: AppColors.textMuted, size: 16),
              SizedBox(width: AppSpacing.sm),
              Text('Logs', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                logTail.isEmpty ? 'No logs yet...' : logTail,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

