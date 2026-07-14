import 'dart:async';
import 'package:flutter/material.dart';
import '../config/robot_config.dart';
import '../utils/constants.dart';
import '../utils/rosbridge.dart';
import '../utils/robot_api.dart';
import '../widgets/top_notification.dart';
import '../services/button_config_service.dart';
import '../services/local_cache_service.dart';

// Top-level state that persists across orientation changes
_SettingsSection? _persistedSection;

/// Settings page with sections
class SettingsPage extends StatefulWidget {
  final RosBridge rosBridge;
  final RobotApi robotApi;
  final void Function(String mode)? onModeStarted;  // Callback when ROS starts in a mode
  
  const SettingsPage({super.key, required this.rosBridge, required this.robotApi, this.onModeStarted});
  
  // Static sidebar state (accessible from outside)
  static bool _sidebarCollapsed = false;
  
  /// Toggle sidebar visibility (called from IconRail)
  static void toggleSidebar() {
    _sidebarCollapsed = !_sidebarCollapsed;
  }
  
  /// Check if sidebar is collapsed
  static bool get isSidebarCollapsed => _sidebarCollapsed;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Current settings section (uses top-level persisted state)
  _SettingsSection get _currentSection => _persistedSection ?? _SettingsSection.robot;
  set _currentSection(_SettingsSection section) => _persistedSection = section;
  
  // Use parent class static for sidebar state
  bool get _sidebarCollapsed => SettingsPage._sidebarCollapsed;
  set _sidebarCollapsed(bool value) => SettingsPage._sidebarCollapsed = value;
  
  // Sidebar dimensions
  static const double _sidebarExpandedWidth = 160.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Settings navigation (left sidebar)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: _sidebarCollapsed ? 0 : _sidebarExpandedWidth,
            color: const Color(0xFF242424), // Between surface and background
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _sidebarExpandedWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: const Row(
                      children: [
                        Icon(Icons.settings, color: AppColors.accent, size: 24),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          'Settings',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(color: AppColors.border, height: 1),
                  
                  // Section buttons
                  _SectionButton(
                    icon: Icons.smart_toy,
                    label: 'Robot',
                    isActive: _currentSection == _SettingsSection.robot,
                    onPressed: () => setState(() => _currentSection = _SettingsSection.robot),
                  ),
                  _SectionButton(
                    icon: Icons.psychology,
                    label: 'Agents',
                    isActive: _currentSection == _SettingsSection.aiAgents,
                    onPressed: () => setState(() => _currentSection = _SettingsSection.aiAgents),
                  ),
                  _SectionButton(
                    icon: Icons.memory,
                    label: 'Memory',
                    isActive: _currentSection == _SettingsSection.memory,
                    onPressed: () => setState(() => _currentSection = _SettingsSection.memory),
                  ),
                  _SectionButton(
                    icon: Icons.videocam,
                    label: 'Camera',
                    isActive: _currentSection == _SettingsSection.camera,
                    onPressed: () => setState(() => _currentSection = _SettingsSection.camera),
                  ),
                  _SectionButton(
                    icon: Icons.person,
                    label: 'Profile',
                    isActive: _currentSection == _SettingsSection.profile,
                    onPressed: () => setState(() => _currentSection = _SettingsSection.profile),
                  ),
                  
                  const Spacer(),
                  
                  _SectionButton(
                    icon: Icons.info_outline,
                    label: 'About',
                    isActive: _currentSection == _SettingsSection.about,
                    onPressed: () => setState(() => _currentSection = _SettingsSection.about),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
          
          // Settings content - align to top
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: _buildSectionContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (_currentSection) {
      case _SettingsSection.robot:
        return _RobotSection(
          rosBridge: widget.rosBridge,
          robotApi: widget.robotApi,
          onModeStarted: widget.onModeStarted,
        );
      case _SettingsSection.profile:
        return _ProfileSection(rosBridge: widget.rosBridge);
      case _SettingsSection.aiAgents:
        return _AIAgentsSection(rosBridge: widget.rosBridge);
      case _SettingsSection.memory:
        return _MemorySection(rosBridge: widget.rosBridge);
      case _SettingsSection.camera:
        return _CameraSection(rosBridge: widget.rosBridge);
      case _SettingsSection.about:
        return const _AboutSection();
    }
  }
}

enum _SettingsSection { robot, aiAgents, memory, camera, profile, about }

/// Section button in sidebar
class _SectionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _SectionButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withOpacity(0.15) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isActive ? AppColors.accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.accent : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.accent : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Robot section - full robot control with RobotApi
class _RobotSection extends StatefulWidget {
  final RosBridge rosBridge;
  final RobotApi robotApi;
  final void Function(String mode)? onModeStarted;
  
  const _RobotSection({required this.rosBridge, required this.robotApi, this.onModeStarted});

  @override
  State<_RobotSection> createState() => _RobotSectionState();
}

class _RobotSectionState extends State<_RobotSection> {
  RobotStatus? _status;
  List<MapInfo> _maps = [];
  String? _activeMap;
  bool _loading = false;
  String? _error;
  Timer? _pollTimer;
  String? _selectedMode;  // Mode selected but not yet launched
  
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
    final status = await widget.robotApi.getStatus();
    final mapResult = await widget.robotApi.listMaps();
    
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
    
    final result = await widget.robotApi.startRos(mode: mode);
    
    if (mounted) {
      setState(() => _loading = false);
      
      if (result.success) {
        _showSnackBar('Starting in $mode mode...', AppColors.success);
        // Notify parent to switch view based on mode
        widget.onModeStarted?.call(mode);
      } else {
        _showSnackBar('Failed: ${result.message}', AppColors.danger);
      }
      
      await _refresh();
    }
  }
  
  Future<void> _stopRos() async {
    setState(() => _loading = true);
    
    final result = await widget.robotApi.stopRos();
    
    if (mounted) {
      setState(() => _loading = false);
      _showSnackBar(result.success ? 'Robot stopped' : 'Failed: ${result.message}',
          AppColors.danger);
      await _refresh();
    }
  }

  Future<void> _refreshConfig() async {
    setState(() => _loading = true);
    _showSnackBar('Rebuilding config...', AppColors.accent);

    // Call the rebuild endpoint which runs colcon build and restarts ROS
    final result = await widget.robotApi.refreshConfig();

    if (mounted) {
      setState(() => _loading = false);
      _showSnackBar(result.success ? 'Config refreshed!' : 'Failed: ${result.message}',
          result.success ? AppColors.success : AppColors.danger);
      await Future.delayed(const Duration(seconds: 3));
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
      final result = await widget.robotApi.saveMap(name);
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
    final result = await widget.robotApi.selectMap(name);
    setState(() => _loading = false);
    
    if (result.success) {
      _showSnackBar('Map "$name" selected for navigation', AppColors.success);
    } else {
      _showSnackBar('Failed: ${result.message}', AppColors.danger);
    }
    
    await _refresh();
  }
  
  Future<void> _deleteMap(String name) async {
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
    final result = await widget.robotApi.deleteMap(name);
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
    if (_error != null) {
      return _buildErrorState();
    }
    if (_status == null) {
      return _buildLoadingState();
    }
    return _buildContent();
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
    
    return OrientationBuilder(
      builder: (context, orientation) {
        final isPortrait = orientation == Orientation.portrait;
        
        if (isPortrait) {
          return _buildPortraitContent(status);
        } else {
          return _buildLandscapeContent(status);
        }
      },
    );
  }
  
  Widget _buildLandscapeContent(RobotStatus status) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Controls in rounded container
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.xl,
              bottom: AppSpacing.lg,
            ),
            child: _buildMainControlsContainer(status),
          ),
        ),
        
        // Right side - System info & logs in separate rounded containers
        Container(
          width: 220,
          padding: const EdgeInsets.only(
            top: AppSpacing.xl,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
          ),
          child: Column(
            children: [
              // System stats - rounded container
              _buildSystemStatsContainer(status),
              
              const SizedBox(height: AppSpacing.lg),
              
              // Log viewer - rounded container
              Expanded(
                child: _buildLogsContainer(status),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPortraitContent(RobotStatus status) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main controls - full width
          _buildMainControlsContainer(status),
          
          const SizedBox(height: AppSpacing.md),
          
          // System stats - full width
          _buildSystemStatsContainer(status),
          
          const SizedBox(height: AppSpacing.md),
          
          // Logs - full width, fixed height
          SizedBox(
            height: 200,
            child: _buildLogsContainer(status),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMainControlsContainer(RobotStatus status) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header
          const _SectionHeader(title: 'Robot Status'),
          const SizedBox(height: AppSpacing.md),
          _RobotStatusHeader(status: status),
          
          const SizedBox(height: AppSpacing.xl),
          
          // Mode buttons
          const _SectionHeader(title: 'Launch Mode'),
          const SizedBox(height: AppSpacing.md),
          
          _RobotModeButtonRow(
            currentMode: status.mode,
            selectedMode: _selectedMode,
            rosRunning: status.rosRunning,
            loading: _loading,
            onSelect: (mode) => setState(() => _selectedMode = mode),
            onLaunch: () {
              if (_selectedMode != null) {
                _startRos(_selectedMode!);
                setState(() => _selectedMode = null);
              }
            },
            onStop: _stopRos,
            onRestart: () => _startRos(status.mode),
            onRefresh: _refreshConfig,
          ),
          
          const SizedBox(height: AppSpacing.xl),
          
          // Map controls (only in mapping mode)
          if (status.mode == 'mapping') ...[
            const _SectionHeader(title: 'Mapping'),
            const SizedBox(height: AppSpacing.md),
            
            _RobotActionCard(
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
            ..._maps.map((m) => _RobotMapCard(
              map: m,
              isActive: m.name == _activeMap,
              onSelect: () => _selectMap(m.name),
              onDelete: () => _deleteMap(m.name),
            )),
        ],
      ),
    );
  }
  
  Widget _buildSystemStatsContainer(RobotStatus status) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: _RobotSystemStats(system: status.system),
    );
  }
  
  Widget _buildLogsContainer(RobotStatus status) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: _RobotLogViewer(logTail: status.logTail),
    );
  }
}

/// Status header with connection indicator
class _RobotStatusHeader extends StatelessWidget {
  final RobotStatus status;
  
  const _RobotStatusHeader({required this.status});

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
                  status.rosRunning ? 'Robot Running' : 'Robot Ready',
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
                      : 'Select a launch mode below',
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
class _RobotModeButtonRow extends StatelessWidget {
  final String currentMode;
  final String? selectedMode;
  final bool rosRunning;
  final bool loading;
  final Function(String) onSelect;
  final VoidCallback onLaunch;
  final VoidCallback onStop;
  final VoidCallback onRestart;
  final VoidCallback onRefresh;

  const _RobotModeButtonRow({
    required this.currentMode,
    required this.selectedMode,
    required this.rosRunning,
    required this.loading,
    required this.onSelect,
    required this.onLaunch,
    required this.onStop,
    required this.onRestart,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final bool canLaunch = !rosRunning && selectedMode != null;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _RobotModeButton(
              icon: Icons.gamepad,
              label: 'Manual',
              description: 'Joystick control',
              mode: 'main',
              modeColor: AppColors.success,  // Green
              isRunning: rosRunning && currentMode == 'main',
              isSelected: !rosRunning && (selectedMode == 'main' || selectedMode == null),
              isDimmed: (!rosRunning && selectedMode != null && selectedMode != 'main') ||
                        (rosRunning && currentMode != 'main'),
              loading: loading,
              onTap: rosRunning ? null : () => onSelect('main'),
            )),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _RobotModeButton(
              icon: Icons.explore,
              label: 'Mapping',
              description: 'Create new map',
              mode: 'mapping',
              modeColor: AppColors.dangerBright,  // Bright orange
              isRunning: rosRunning && currentMode == 'mapping',
              isSelected: !rosRunning && (selectedMode == 'mapping' || selectedMode == null),
              isDimmed: (!rosRunning && selectedMode != null && selectedMode != 'mapping') ||
                        (rosRunning && currentMode != 'mapping'),
              loading: loading,
              onTap: rosRunning ? null : () => onSelect('mapping'),
            )),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _RobotModeButton(
              icon: Icons.navigation,
              label: 'Navigate',
              description: 'Autonomous mode',
              mode: 'nav',
              modeColor: AppColors.accent,  // Blue
              isRunning: rosRunning && currentMode == 'nav',
              isSelected: !rosRunning && (selectedMode == 'nav' || selectedMode == null),
              isDimmed: (!rosRunning && selectedMode != null && selectedMode != 'nav') ||
                        (rosRunning && currentMode != 'nav'),
              loading: loading,
              onTap: rosRunning ? null : () => onSelect('nav'),
            )),
          ],
        ),
        
        // Launch/Stop button - changes based on ROS state
        const SizedBox(height: AppSpacing.lg),
        GestureDetector(
          onTap: loading ? null : (rosRunning ? onStop : (canLaunch ? onLaunch : null)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: rosRunning 
                  ? AppColors.danger 
                  : (canLaunch ? AppColors.success : AppColors.surface),
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(
                color: rosRunning 
                    ? AppColors.dangerBright 
                    : (canLaunch ? AppColors.success : AppColors.border),
                width: 2,
              ),
              boxShadow: canLaunch || rosRunning ? [
                BoxShadow(
                  color: (rosRunning ? AppColors.danger : AppColors.success).withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  rosRunning ? Icons.stop_circle : Icons.play_circle,
                  color: rosRunning || canLaunch ? Colors.white : AppColors.textMuted,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  rosRunning ? 'STOP' : 'LAUNCH',
                  style: TextStyle(
                    color: rosRunning || canLaunch ? Colors.white : AppColors.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Refresh button - darker blue when idle, grey when ROS is running
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: (loading || rosRunning) ? null : onRefresh,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: rosRunning
                  ? AppColors.surface
                  : AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(
                color: rosRunning
                    ? AppColors.border
                    : AppColors.accent,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.change_circle,
                  color: rosRunning ? AppColors.textMuted : AppColors.accent,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'REFRESH',
                  style: TextStyle(
                    color: rosRunning ? AppColors.textMuted : AppColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

      ],
    );
  }
}

/// Individual mode button - styled like sidebar buttons
class _RobotModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final String mode;
  final Color modeColor;   // Unique color for this mode
  final bool isRunning;    // Currently running in this mode
  final bool isSelected;   // Selected but not launched yet
  final bool isDimmed;     // Another mode is selected, dim this one
  final bool loading;
  final VoidCallback? onTap;
  
  const _RobotModeButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.mode,
    required this.modeColor,
    required this.isRunning,
    required this.isSelected,
    required this.isDimmed,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isHighlighted = isRunning || isSelected;
    
    // Soft colored background by default, slightly more opaque when selected
    final Color bgColor = isDimmed 
        ? AppColors.surface 
        : modeColor.withOpacity(isHighlighted ? 0.20 : 0.10);
    
    final Color borderColor = isDimmed 
        ? AppColors.border.withOpacity(0.3) 
        : modeColor.withOpacity(isHighlighted ? 0.6 : 0.3);
    
    final Color contentColor = isDimmed 
        ? AppColors.textMuted 
        : modeColor;
    
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: borderColor,
            width: isHighlighted ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, 
              color: contentColor, 
              size: 32,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: isDimmed ? AppColors.textMuted : AppColors.textPrimary,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDimmed ? AppColors.textMuted.withOpacity(0.5) : AppColors.textMuted, 
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Action card (like Save Map)
class _RobotActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  
  const _RobotActionCard({
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
class _RobotMapCard extends StatelessWidget {
  final MapInfo map;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  
  const _RobotMapCard({
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
class _RobotSystemStats extends StatelessWidget {
  final SystemInfo system;
  
  const _RobotSystemStats({required this.system});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('System', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.md),
        
        _RobotStatRow(
          icon: Icons.thermostat,
          label: 'CPU Temp',
          value: system.cpuTemp != null ? '${system.cpuTemp!.toStringAsFixed(1)}°C' : '--',
          color: _getTempColor(system.cpuTemp),
        ),
        _RobotStatRow(
          icon: Icons.speed,
          label: 'CPU',
          value: system.cpuPercent != null ? '${system.cpuPercent!.toStringAsFixed(0)}%' : '--',
          color: _getCpuColor(system.cpuPercent),
        ),
        _RobotStatRow(
          icon: Icons.memory,
          label: 'Memory',
          value: system.memUsagePercent != null 
              ? '${system.memUsagePercent!.toStringAsFixed(0)}%'
              : '--',
        ),
        _RobotStatRow(
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
  
  Color _getCpuColor(double? percent) {
    if (percent == null) return AppColors.textMuted;
    if (percent > 80) return AppColors.danger;
    if (percent > 50) return AppColors.warning;
    return AppColors.success;
  }
}

class _RobotStatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  
  const _RobotStatRow({
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
class _RobotLogViewer extends StatelessWidget {
  final String logTail;
  
  const _RobotLogViewer({required this.logTail});

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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
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

/// Camera section
class _CameraSection extends StatefulWidget {
  final RosBridge rosBridge;

  const _CameraSection({required this.rosBridge});

  @override
  State<_CameraSection> createState() => _CameraSectionState();
}

class _CameraSectionState extends State<_CameraSection> {
  bool _showDetectionOverlay = true;  // Default on (matches launch file)
  bool _lowBandwidthMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final overlay = await LocalCacheService.loadDetectionOverlay();
    final lowBandwidth = await LocalCacheService.loadLowBandwidthMode();
    if (mounted) {
      setState(() {
        _showDetectionOverlay = overlay;
        _lowBandwidthMode = lowBandwidth;
      });
      // Publish current settings to robot on load
      widget.rosBridge.publishDetectionOverlay(overlay);
      widget.rosBridge.publishLowBandwidthMode(lowBandwidth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.xl, bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Camera Settings'),
          const SizedBox(height: AppSpacing.md),

          _SettingsCard(
            children: [
              _ToggleRow(
                label: 'Show Detection Overlay',
                value: _showDetectionOverlay,
                onChanged: (v) {
                  setState(() => _showDetectionOverlay = v);
                  widget.rosBridge.publishDetectionOverlay(v);
                  LocalCacheService.saveDetectionOverlay(v);
                },
              ),
              const Divider(color: AppColors.border),
              _ToggleRow(
                label: 'Low Bandwidth Mode',
                value: _lowBandwidthMode,
                onChanged: (v) {
                  setState(() => _lowBandwidthMode = v);
                  widget.rosBridge.publishLowBandwidthMode(v);
                  LocalCacheService.saveLowBandwidthMode(v);
                },
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          const _SectionHeader(title: 'Stream URL'),
          const SizedBox(height: AppSpacing.md),
          
          _SettingsCard(
            children: [
              const Text(
                'Video stream endpoint:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  'http://${RobotConfig.robotIP}:${RobotConfig.videoPort}/stream',
                  style: const TextStyle(color: AppColors.textMuted, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Profile section - User profile synced from robot
class _ProfileSection extends StatefulWidget {
  final RosBridge rosBridge;

  const _ProfileSection({required this.rosBridge});

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  UserProfile? _userProfile;
  bool _isEditing = false;

  final _usernameController = TextEditingController();
  final _pronounsController = TextEditingController();
  final _bioController = TextEditingController();

  late final void Function(UserProfile) _userProfileListener;

  @override
  void initState() {
    super.initState();
    _setupListener();
    widget.rosBridge.requestUserProfile();
  }

  void _setupListener() {
    _userProfileListener = (profile) {
      if (mounted && !_isEditing) {
        setState(() {
          _userProfile = profile;
          _usernameController.text = profile.username;
          _pronounsController.text = profile.pronouns;
          _bioController.text = profile.bio;
        });
      }
    };
    widget.rosBridge.addUserProfileListener(_userProfileListener);
  }

  @override
  void dispose() {
    widget.rosBridge.removeUserProfileListener(_userProfileListener);
    _usernameController.dispose();
    _pronounsController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _enterEditMode() {
    setState(() => _isEditing = true);
  }

  void _save() {
    final profile = UserProfile(
      username: _usernameController.text.trim(),
      pronouns: _pronounsController.text.trim(),
      bio: _bioController.text.trim(),
    );
    widget.rosBridge.publishSaveUserProfile(profile);
    setState(() {
      _userProfile = profile;
      _isEditing = false;
    });
    TopNotification.show(context, message: 'Profile saved', backgroundColor: AppColors.success);
  }

  void _cancel() {
    if (_userProfile != null) {
      _usernameController.text = _userProfile!.username;
      _pronounsController.text = _userProfile!.pronouns;
      _bioController.text = _userProfile!.bio;
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.person, color: AppColors.accent, size: 24),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'Profile',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (!_isEditing)
                GestureDetector(
                  onTap: _enterEditMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      border: Border.all(color: AppColors.accent),
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Profile card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField('Username', _usernameController, _isEditing),
                const SizedBox(height: AppSpacing.lg),
                _buildField('Pronouns', _pronounsController, _isEditing),
                const SizedBox(height: AppSpacing.lg),
                _buildField('Bio', _bioController, _isEditing, maxLines: 3),

                if (_isEditing) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _cancel,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(AppRadius.small),
                              border: Border.all(color: AppColors.dangerBright),
                            ),
                            child: const Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppColors.dangerBright,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: GestureDetector(
                          onTap: _save,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(AppRadius.small),
                              border: Border.all(color: AppColors.accent),
                            ),
                            child: const Center(
                              child: Text(
                                'Save',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, bool editable, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (editable)
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.all(AppSpacing.md),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.small),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.small),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.small),
                borderSide: const BorderSide(color: AppColors.accent, width: 2),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              controller.text.isEmpty ? '-' : controller.text,
              style: TextStyle(
                color: controller.text.isEmpty ? AppColors.textMuted : AppColors.textPrimary,
              ),
            ),
          ),
      ],
    );
  }
}


/// Agents section - Reusable agent configurations
class _AIAgentsSection extends StatefulWidget {
  final RosBridge rosBridge;
  
  const _AIAgentsSection({required this.rosBridge});

  @override
  State<_AIAgentsSection> createState() => _AIAgentsSectionState();
}

class _AIAgentsSectionState extends State<_AIAgentsSection> {
  List<AgentDefinition> _agents = [];
  int? _editingIndex; // null = list view, -1 = new agent, >= 0 = editing existing

  final _nameController = TextEditingController();
  final _personalityController = TextEditingController();
  final _introMessageController = TextEditingController();
  String _selectedFaceId = '';
  String _selectedVoice = 'nova';
  String _voiceMode = 'turn_taking';
  String _faceType = 'robot'; // 'robot' or 'animal'

  // Available faces and voices
  static const List<String> animalFaces = ['cat', 'dog', 'bear', 'bee', 'bird', 'crocodile', 'elephant', 'fish', 'lion', 'lobster', 'reptile', 'tiger'];
  static const List<String> turnTakingVoices = ['alloy', 'echo', 'fable', 'nova', 'onyx', 'shimmer'];
  static const List<String> realtimeVoices = ['alloy', 'ash', 'ballad', 'coral', 'echo', 'sage', 'shimmer', 'verse'];

  // Get voice options based on current voice mode
  List<String> get voiceOptions => _voiceMode == 'realtime' ? realtimeVoices : turnTakingVoices;

  // Multi-listener callback (for cleanup)
  late final void Function(List<AgentDefinition>) _agentListener;

  @override
  void initState() {
    super.initState();
    _setupRosCallback();
    _requestAgents();
  }
  
  void _setupRosCallback() {
    // Multi-listener pattern
    _agentListener = (agents) {
      if (mounted) {
        // Sort so default agent appears first
        agents.sort((a, b) {
          if (a.isDefault && !b.isDefault) return -1;
          if (!a.isDefault && b.isDefault) return 1;
          return a.name.compareTo(b.name);
        });
        setState(() => _agents = agents);
      }
    };
    widget.rosBridge.addAgentListener(_agentListener);
  }
  
  void _requestAgents() {
    widget.rosBridge.requestAgents();
  }

  @override
  void dispose() {
    widget.rosBridge.removeAgentListener(_agentListener);  // Multi-listener cleanup
    _nameController.dispose();
    _personalityController.dispose();
    _introMessageController.dispose();
    super.dispose();
  }
  
  void _startNewAgent() {
    _nameController.clear();
    _personalityController.clear();
    _introMessageController.clear();
    _selectedFaceId = 'cat';
    _faceType = 'animal';
    _selectedVoice = 'nova';
    _voiceMode = 'turn_taking';
    setState(() => _editingIndex = -1);
  }
  
  void _editAgent(int index) {
    final agent = _agents[index];
    _nameController.text = agent.name;
    _personalityController.text = agent.personality;
    _introMessageController.text = agent.introMessage;
    _selectedFaceId = agent.faceId;
    _faceType = animalFaces.contains(agent.faceId) ? 'animal' : 'robot';
    _selectedVoice = agent.voice.isNotEmpty ? agent.voice : 'nova';
    _voiceMode = agent.voiceMode;
    setState(() => _editingIndex = index);
  }
  
  void _saveAgent() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      TopNotification.show(context, message: 'Agent name is required', backgroundColor: AppColors.danger);
      return;
    }

    // Preserve isDefault from existing agent if editing
    final existingIsDefault = _editingIndex != null && _editingIndex! >= 0 && _editingIndex! < _agents.length
        ? _agents[_editingIndex!].isDefault
        : false;

    final agent = AgentDefinition(
      name: name,
      faceId: _faceType == 'animal' ? _selectedFaceId : '',
      voice: _selectedVoice,
      voiceMode: _voiceMode,
      personality: _personalityController.text.trim(),
      introMessage: _introMessageController.text.trim(),
      isDefault: existingIsDefault,
    );

    widget.rosBridge.publishSaveAgent(agent);
    setState(() => _editingIndex = null);

    TopNotification.show(context, message: 'Agent "$name" saved', backgroundColor: AppColors.success);
  }
  
  void _deleteAgent() {
    if (_editingIndex == null || _editingIndex! < 0) return;
    
    final name = _agents[_editingIndex!].name;
    widget.rosBridge.publishDeleteAgent(name);
    setState(() => _editingIndex = null);
    
    TopNotification.show(context, message: 'Agent "$name" deleted', backgroundColor: AppColors.warning);
  }
  
  void _cancelEdit() {
    setState(() => _editingIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    return _editingIndex != null ? _buildEditorView() : _buildListView();
  }
  
  Widget _buildListView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.psychology, color: AppColors.accent, size: 24),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'Agents',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _startNewAgent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(color: AppColors.accent),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: AppColors.accent, size: 18),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        'New Agent',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // List or empty state
          if (_agents.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      size: 48,
                      color: AppColors.textMuted.withOpacity(0.5),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'No agents configured',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Create agents to define reusable AI personas and behaviors',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ..._agents.asMap().entries.map((entry) => _buildAgentCard(entry.key, entry.value)),
        ],
      ),
    );
  }
  
  void _activateAgent(AgentDefinition agent) {
    // Save the agent with isDefault = true
    final updatedAgent = agent.copyWith(isDefault: true);
    widget.rosBridge.publishSaveAgent(updatedAgent);
    TopNotification.show(context, message: '${agent.name} is now default', backgroundColor: AppColors.success);
  }

  Widget _buildAgentCard(int index, AgentDefinition agent) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: agent.isDefault ? AppColors.success : AppColors.border,
          width: agent.isDefault ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Face preview
          animalFaces.contains(agent.faceId)
              ? Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    child: Image.asset(
                      'assets/faces/${agent.faceId}.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildRobotFacePreview(80),
                    ),
                  ),
                )
              : _buildRobotFacePreview(80),
          const SizedBox(width: AppSpacing.lg),
          // Agent Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Voice: ${agent.voice.isNotEmpty ? agent.voice[0].toUpperCase() + agent.voice.substring(1) : "Nova"}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Mode: ${agent.voiceMode == "realtime" ? "Realtime" : "Turn-taking"}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Default status badge or Set Default button
          agent.isDefault
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () => _activateAgent(agent),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBright.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      border: Border.all(color: AppColors.dangerBright),
                    ),
                    child: const Text(
                      'Activate',
                      style: TextStyle(
                        color: AppColors.dangerBright,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
          const SizedBox(width: AppSpacing.md),
          // Edit button
          GestureDetector(
            onTap: () => _editAgent(index),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.small),
                border: Border.all(color: AppColors.accent),
              ),
              child: const Text(
                'Edit',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEditorView() {
    final isNew = _editingIndex == -1;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.psychology, color: AppColors.accent, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(
                isNew ? 'New Agent' : 'Edit Agent',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _cancelEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(color: AppColors.dangerBright),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.dangerBright,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Form
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Face preview (large, centered) - AT THE TOP
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.medium - 1),
                      child: _faceType == 'animal' && _selectedFaceId.isNotEmpty
                          ? Image.asset(
                              'assets/faces/$_selectedFaceId.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildRobotFacePreview(120),
                            )
                          : _buildRobotFacePreview(120),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Face Type toggle
                const Text(
                  'Face Type',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _faceType = 'robot';
                          _selectedFaceId = '';
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: _faceType == 'robot' ? AppColors.accent : AppColors.background,
                            borderRadius: BorderRadius.circular(AppRadius.small),
                            border: Border.all(
                              color: _faceType == 'robot' ? AppColors.accent : AppColors.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Robot',
                              style: TextStyle(
                                color: _faceType == 'robot' ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _faceType = 'animal';
                          if (_selectedFaceId.isEmpty) _selectedFaceId = 'cat';
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: _faceType == 'animal' ? AppColors.accent : AppColors.background,
                            borderRadius: BorderRadius.circular(AppRadius.small),
                            border: Border.all(
                              color: _faceType == 'animal' ? AppColors.accent : AppColors.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Animal',
                              style: TextStyle(
                                color: _faceType == 'animal' ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Animal faces grid (only shown when Animal is selected)
                if (_faceType == 'animal') ...[
                  const SizedBox(height: AppSpacing.md),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                    ),
                    itemCount: animalFaces.length,
                    itemBuilder: (context, index) {
                      final faceId = animalFaces[index];
                      final isSelected = _selectedFaceId == faceId;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFaceId = faceId),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.small),
                            border: Border.all(
                              color: isSelected ? AppColors.accent : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.small - 1),
                            child: Image.asset(
                              'assets/faces/$faceId.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(faceId[0].toUpperCase(), style: const TextStyle(color: AppColors.textMuted)),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                // Agent Name
                _buildTextField(
                  controller: _nameController,
                  label: 'Agent Name',
                  hint: 'e.g., Millie, Greeter, Tour Guide',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildTextField(
                  controller: _personalityController,
                  label: 'Personality',
                  hint: 'Describe how this agent should behave and speak',
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildTextField(
                  controller: _introMessageController,
                  label: 'Intro Message',
                  hint: 'What the agent says when starting a conversation',
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Voice dropdown
                _buildDropdownField(
                  label: 'Voice',
                  value: _selectedVoice,
                  items: voiceOptions,
                  onChanged: (value) => setState(() => _selectedVoice = value ?? 'nova'),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Voice Mode dropdown
                _buildDropdownField(
                  label: 'Voice Mode',
                  value: _voiceMode,
                  items: const ['turn_taking', 'realtime'],
                  itemLabels: const {'turn_taking': 'Turn Taking', 'realtime': 'Realtime'},
                  onChanged: (value) {
                    setState(() {
                      _voiceMode = value ?? 'turn_taking';
                      // Switch to valid voice if current isn't available in new mode
                      final newVoices = _voiceMode == 'realtime' ? realtimeVoices : turnTakingVoices;
                      if (!newVoices.contains(_selectedVoice)) {
                        _selectedVoice = 'alloy';
                      }
                    });
                  },
                ),

                const SizedBox(height: AppSpacing.xl),

                // Save button
                GestureDetector(
                  onTap: _saveAgent,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      border: Border.all(color: AppColors.accent),
                    ),
                    child: const Center(
                      child: Text(
                        'Save',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Delete button (only for existing agents)
                if (!isNew) ...[
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: _deleteAgent,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                        border: Border.all(color: AppColors.dangerBright),
                      ),
                      child: const Center(
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: AppColors.dangerBright,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int? maxLines = 1,
    int minLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: minLines,
          textCapitalization: textCapitalization,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5)),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.all(AppSpacing.md),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
              borderSide: const BorderSide(color: AppColors.accent, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    Map<String, String>? itemLabels,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.background,
              style: const TextStyle(color: AppColors.textPrimary),
              items: items.map((item) => DropdownMenuItem(
                value: item,
                child: Text(itemLabels?[item] ?? item),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  /// Build robot face preview (like millie_mini)
  Widget _buildRobotFacePreview(double size) {
    final eyeWidth = size * 0.24;
    final eyeHeight = size * 0.32;
    final eyeGap = size * 0.08;
    final mouthWidth = size * 0.32;
    final mouthHeight = size * 0.04;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(size * 0.08),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Eyes - rounded corner rectangles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: eyeWidth,
                height: eyeHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(eyeWidth * 0.1),
                ),
              ),
              SizedBox(width: eyeGap),
              Container(
                width: eyeWidth,
                height: eyeHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(eyeWidth * 0.1),
                ),
              ),
            ],
          ),
          SizedBox(height: size * 0.12),
          // Mouth
          Container(
            width: mouthWidth,
            height: mouthHeight,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(mouthHeight / 2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Memory section - view and edit robot memory
class _MemorySection extends StatefulWidget {
  final RosBridge rosBridge;

  const _MemorySection({required this.rosBridge});

  @override
  State<_MemorySection> createState() => _MemorySectionState();
}

class _MemorySectionState extends State<_MemorySection> {
  MemoryData _memories = MemoryData();
  bool _isEditing = false;
  String _editingType = ''; // 'owner_note', 'person', 'note'
  int? _editingIndex;

  // Person editing controllers
  final _personNameController = TextEditingController();
  final _personRelationshipController = TextEditingController();
  final _personInterestsController = TextEditingController();
  final _personNotesController = TextEditingController();

  // Note editing controller
  final _noteContentController = TextEditingController();
  String _noteCategory = 'general';

  late final void Function(MemoryData) _memoryListener;

  @override
  void initState() {
    super.initState();
    _setupMemoryListener();
    widget.rosBridge.requestMemories();
  }

  void _setupMemoryListener() {
    _memoryListener = (memories) {
      if (mounted) {
        setState(() => _memories = memories);
      }
    };
    widget.rosBridge.addMemoryListener(_memoryListener);
  }

  @override
  void dispose() {
    widget.rosBridge.removeMemoryListener(_memoryListener);
    _personNameController.dispose();
    _personRelationshipController.dispose();
    _personInterestsController.dispose();
    _personNotesController.dispose();
    _noteContentController.dispose();
    super.dispose();
  }

  void _addPerson() {
    _personNameController.clear();
    _personRelationshipController.clear();
    _personInterestsController.clear();
    _personNotesController.clear();
    setState(() {
      _isEditing = true;
      _editingType = 'person';
      _editingIndex = null;
    });
  }

  void _editPerson(int index) {
    final person = _memories.people[index];
    _personNameController.text = person.name;
    _personRelationshipController.text = person.relationship;
    _personInterestsController.text = person.interests ?? '';
    _personNotesController.text = person.notes.join(', ');
    setState(() {
      _isEditing = true;
      _editingType = 'person';
      _editingIndex = index;
    });
  }

  void _savePerson() {
    final name = _personNameController.text.trim();
    if (name.isEmpty) {
      TopNotification.show(context, message: 'Name is required', backgroundColor: AppColors.danger);
      return;
    }

    final notes = _personNotesController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final person = KnownPerson(
      name: name,
      relationship: _personRelationshipController.text.trim(),
      interests: _personInterestsController.text.trim().isEmpty ? null : _personInterestsController.text.trim(),
      notes: notes,
      lastSeen: DateTime.now(),
    );

    List<KnownPerson> updatedPeople;
    if (_editingIndex != null) {
      updatedPeople = List.from(_memories.people);
      updatedPeople[_editingIndex!] = person;
    } else {
      updatedPeople = [..._memories.people, person];
    }

    final updatedMemories = _memories.copyWith(people: updatedPeople);
    widget.rosBridge.publishSaveMemories(updatedMemories);

    setState(() {
      _isEditing = false;
      _editingType = '';
      _editingIndex = null;
    });

    TopNotification.show(context, message: 'Person saved', backgroundColor: AppColors.success);
  }

  void _deletePerson(int index) {
    final updatedPeople = List<KnownPerson>.from(_memories.people);
    final name = updatedPeople[index].name;
    updatedPeople.removeAt(index);

    final updatedMemories = _memories.copyWith(people: updatedPeople);
    widget.rosBridge.publishSaveMemories(updatedMemories);

    TopNotification.show(context, message: '$name removed', backgroundColor: AppColors.warning);
  }

  void _addNote() {
    _noteContentController.clear();
    _noteCategory = 'general';
    setState(() {
      _isEditing = true;
      _editingType = 'note';
      _editingIndex = null;
    });
  }

  void _saveNote() {
    final content = _noteContentController.text.trim();
    if (content.isEmpty) {
      TopNotification.show(context, message: 'Note content is required', backgroundColor: AppColors.danger);
      return;
    }

    final note = MemoryNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      category: _noteCategory,
    );

    final updatedNotes = [..._memories.notes, note];
    final updatedMemories = _memories.copyWith(notes: updatedNotes);
    widget.rosBridge.publishSaveMemories(updatedMemories);

    setState(() {
      _isEditing = false;
      _editingType = '';
    });

    TopNotification.show(context, message: 'Note added', backgroundColor: AppColors.success);
  }

  void _deleteNote(int index) {
    final updatedNotes = List<MemoryNote>.from(_memories.notes);
    updatedNotes.removeAt(index);

    final updatedMemories = _memories.copyWith(notes: updatedNotes);
    widget.rosBridge.publishSaveMemories(updatedMemories);

    TopNotification.show(context, message: 'Note deleted', backgroundColor: AppColors.warning);
  }

  void _addOwnerNote() {
    _noteContentController.clear();
    setState(() {
      _isEditing = true;
      _editingType = 'owner_note';
    });
  }

  void _saveOwnerNote() {
    final content = _noteContentController.text.trim();
    if (content.isEmpty) return;

    final updatedNotes = [..._memories.owner.notes, content];
    final updatedOwner = _memories.owner.copyWith(notes: updatedNotes);
    final updatedMemories = _memories.copyWith(owner: updatedOwner);
    widget.rosBridge.publishSaveMemories(updatedMemories);

    _noteContentController.clear();
    setState(() {
      _isEditing = false;
      _editingType = '';
    });
  }

  void _deleteOwnerNote(int index) {
    final updatedNotes = List<String>.from(_memories.owner.notes);
    updatedNotes.removeAt(index);
    final updatedOwner = _memories.owner.copyWith(notes: updatedNotes);
    final updatedMemories = _memories.copyWith(owner: updatedOwner);
    widget.rosBridge.publishSaveMemories(updatedMemories);
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _editingType = '';
      _editingIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return _buildEditView();
    }
    return _buildListView();
  }

  Widget _buildListView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.memory, color: AppColors.accent, size: 24),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Robot Memory',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'What the robot knows and remembers. The AI can update this during conversations.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Owner Notes Section
          _buildSectionHeader('Owner Notes', Icons.person, onAdd: _addOwnerNote),
          const SizedBox(height: AppSpacing.md),
          if (_memories.owner.notes.isEmpty)
            _buildEmptyState('No owner notes yet', 'Things the robot learns about you')
          else
            ..._memories.owner.notes.asMap().entries.map((e) => _buildOwnerNoteCard(e.key, e.value)),

          const SizedBox(height: AppSpacing.xl),

          // People Section
          _buildSectionHeader('People', Icons.people, onAdd: _addPerson),
          const SizedBox(height: AppSpacing.md),
          if (_memories.people.isEmpty)
            _buildEmptyState('No people remembered yet', 'The robot will learn names as it meets people')
          else
            ..._memories.people.asMap().entries.map((e) => _buildPersonCard(e.key, e.value)),

          const SizedBox(height: AppSpacing.xl),

          // Notes Section
          _buildSectionHeader('Notes', Icons.note, onAdd: _addNote),
          const SizedBox(height: AppSpacing.md),
          if (_memories.notes.isEmpty)
            _buildEmptyState('No notes yet', 'The robot will save observations and facts here')
          else
            ..._memories.notes.asMap().entries.map((e) => _buildNoteCard(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {VoidCallback? onAdd, String addLabel = 'Add'}) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (onAdd != null)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.small),
                border: Border.all(color: AppColors.accent),
              ),
              child: Text(
                addLabel,
                style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildOwnerNoteCard(int index, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              content,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
          GestureDetector(
            onTap: () => _deleteOwnerNote(index),
            child: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonCard(int index, KnownPerson person) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      person.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (person.relationship.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: Text(
                          person.relationship,
                          style: const TextStyle(color: AppColors.accent, fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
                if (person.notes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    person.notes.join('; '),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _editPerson(index),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Icon(Icons.edit, color: AppColors.textMuted, size: 18),
            ),
          ),
          GestureDetector(
            onTap: () => _deletePerson(index),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Icon(Icons.delete, color: AppColors.danger, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(int index, MemoryNote note) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.content,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${note.category} • ${_formatDate(note.createdAt)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _deleteNote(index),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: Icon(Icons.delete, color: AppColors.danger, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  Widget _buildEditView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button
          Row(
            children: [
              GestureDetector(
                onTap: _cancelEdit,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                _editingType == 'person'
                    ? (_editingIndex == null ? 'Add Person' : 'Edit Person')
                    : _editingType == 'note'
                        ? 'Add Note'
                        : 'Add Owner Note',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Form based on editing type
          if (_editingType == 'person') _buildPersonForm(),
          if (_editingType == 'note') _buildNoteForm(),
          if (_editingType == 'owner_note') _buildOwnerNoteForm(),
        ],
      ),
    );
  }

  Widget _buildPersonForm() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormField('Name', _personNameController, 'Person\'s name'),
          const SizedBox(height: AppSpacing.md),
          _buildFormField('Relationship', _personRelationshipController, 'e.g., friend, coworker'),
          const SizedBox(height: AppSpacing.md),
          _buildFormField('Interests', _personInterestsController, 'Their interests'),
          const SizedBox(height: AppSpacing.md),
          _buildFormField('Notes', _personNotesController, 'Comma-separated notes'),
          const SizedBox(height: AppSpacing.xl),
          _buildSaveButton(_savePerson),
        ],
      ),
    );
  }

  Widget _buildNoteForm() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormField('Note', _noteContentController, 'What should the robot remember?', maxLines: 3),
          const SizedBox(height: AppSpacing.md),
          const Text('Category', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: ['general', 'observation', 'preference', 'fact', 'event'].map((cat) {
              final isSelected = _noteCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => _noteCategory = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accent.withOpacity(0.15) : AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? AppColors.accent : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildSaveButton(_saveNote),
        ],
      ),
    );
  }

  Widget _buildOwnerNoteForm() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormField('Note about owner', _noteContentController, 'Something the robot should know about you'),
          const SizedBox(height: AppSpacing.xl),
          _buildSaveButton(_saveOwnerNote),
        ],
      ),
    );
  }

  Widget _buildFormField(String label, TextEditingController controller, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(VoidCallback onSave) {
    return GestureDetector(
      onTap: onSave,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(color: AppColors.accent),
        ),
        child: const Center(
          child: Text(
            'Save',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// About section
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.xl, bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'About Millie Control'),
          const SizedBox(height: AppSpacing.md),
          
          _SettingsCard(
            children: [
              const Center(
                child: Icon(Icons.smart_toy, color: AppColors.accent, size: 48),
              ),
              const SizedBox(height: AppSpacing.md),
              const Center(
                child: Text(
                  'Millie Control',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'v1.0.0',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(color: AppColors.border),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'A tablet control interface for the Millie robot. '
                'Built with Flutter and ROS2.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============ Helper Widgets ============

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final Color statusColor;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Text(status, style: TextStyle(color: statusColor, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool isActive;
  final VoidCallback onPressed;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.accent : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? AppColors.accent : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(color: AppColors.textSecondary)),
              const Spacer(),
              Text(
                '${(value * 100).toInt()}%',
                style: const TextStyle(color: AppColors.accent),
              ),
            ],
          ),
          Slider(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accent,
            inactiveColor: AppColors.border,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _WaypointRow extends StatelessWidget {
  final String name;
  final double x;
  final double y;
  final VoidCallback onGo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WaypointRow({
    required this.name,
    required this.x,
    required this.y,
    required this.onGo,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.place, color: AppColors.accent, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppColors.textPrimary)),
                Text(
                  '(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.navigation, size: 18),
            color: AppColors.success,
            onPressed: onGo,
            tooltip: 'Go',
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            color: AppColors.textSecondary,
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18),
            color: AppColors.dangerBright,
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}

class _QuickButtonPreview extends StatelessWidget {
  final ButtonConfig config;
  final VoidCallback onEdit;

  const _QuickButtonPreview({required this.config, required this.onEdit});

  IconData _getIcon() {
    switch (config.actionType) {
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
    switch (config.actionType) {
      case 'waypoint':
        return config.value ?? '';
      case 'task':
        return config.value ?? '';
      case 'none':
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured = config.actionType != 'none';
    final label = _getLabel();

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: isConfigured
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getIcon(),
                      color: AppColors.textSecondary,
                      size: 24,
                    ),
                    if (label.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add,
                      color: AppColors.textMuted.withOpacity(0.5),
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap to edit',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 9),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Edit button dialog
class _EditButtonDialog extends StatefulWidget {
  final int buttonIndex;
  final RosBridge rosBridge;

  const _EditButtonDialog({required this.buttonIndex, required this.rosBridge});

  @override
  State<_EditButtonDialog> createState() => _EditButtonDialogState();
}

class _EditButtonDialogState extends State<_EditButtonDialog> {
  String _actionType = 'none';
  String? _selectedValue;
  List<Waypoint> _waypoints = [];
  List<SavedSequence> _sequences = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Load waypoints and sequences from rosBridge
    _waypoints = widget.rosBridge.waypoints;
    _sequences = widget.rosBridge.sequences;

    // Listen for updates
    widget.rosBridge.addWaypointListener(_onWaypointsUpdate);
    widget.rosBridge.addSequenceListener(_onSequencesUpdate);

    // Load saved config for this button
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await ButtonConfigService.getConfig(widget.buttonIndex);
    if (mounted) {
      setState(() {
        _actionType = config.actionType;
        _selectedValue = config.value;
        _loading = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    final config = ButtonConfig(
      actionType: _actionType,
      value: _selectedValue,
    );
    await ButtonConfigService.saveConfig(widget.buttonIndex, config);
  }

  @override
  void dispose() {
    widget.rosBridge.removeWaypointListener(_onWaypointsUpdate);
    widget.rosBridge.removeSequenceListener(_onSequencesUpdate);
    super.dispose();
  }

  void _onWaypointsUpdate(List<Waypoint> waypoints) {
    if (mounted) setState(() => _waypoints = waypoints);
  }

  void _onSequencesUpdate(List<SavedSequence> sequences) {
    if (mounted) setState(() => _sequences = sequences);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      title: Text(
        'Edit Button ${widget.buttonIndex + 1}',
        style: const TextStyle(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Action Type:', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),

              // Action type selector
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _ActionChip(
                    label: 'None',
                    isSelected: _actionType == 'none',
                    onSelected: () => setState(() {
                      _actionType = 'none';
                      _selectedValue = null;
                    }),
                  ),
                  _ActionChip(
                    label: 'Waypoint',
                    isSelected: _actionType == 'waypoint',
                    onSelected: () => setState(() {
                      _actionType = 'waypoint';
                      _selectedValue = null;
                    }),
                  ),
                  _ActionChip(
                    label: 'Task',
                    isSelected: _actionType == 'task',
                    onSelected: () => setState(() {
                      _actionType = 'task';
                      _selectedValue = null;
                    }),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Waypoint selection
              if (_actionType == 'waypoint') ...[
                const Text('Select Waypoint:', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.sm),
                if (_waypoints.isEmpty)
                  const Text('No waypoints saved yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 12))
                else
                  ..._waypoints.map((wp) => _WaypointOption(
                    name: wp.name,
                    isSelected: _selectedValue == wp.name,
                    onSelected: () => setState(() => _selectedValue = wp.name),
                  )),
              ],

              // Task/Sequence selection
              if (_actionType == 'task') ...[
                const Text('Select Task:', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.sm),
                if (_sequences.isEmpty)
                  const Text('No tasks saved yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 12))
                else
                  ..._sequences.map((seq) => _WaypointOption(
                    name: seq.name,
                    isSelected: _selectedValue == seq.name,
                    onSelected: () => setState(() => _selectedValue = seq.name),
                  )),
              ],

            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: () async {
            await _saveConfig();
            debugPrint("Saved button ${widget.buttonIndex + 1}: $_actionType -> $_selectedValue");
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _ActionChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.circular),
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _WaypointOption extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onSelected;

  const _WaypointOption({
    required this.name,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.accent : AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(name, style: const TextStyle(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

