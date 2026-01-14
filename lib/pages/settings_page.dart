import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/rosbridge.dart';
import '../utils/robot_api.dart';
import '../widgets/top_notification.dart';

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
                    label: 'AI Agents',
                    isActive: _currentSection == _SettingsSection.aiAgents,
                    onPressed: () => setState(() => _currentSection = _SettingsSection.aiAgents),
                  ),
                  _SectionButton(
                    icon: Icons.videocam,
                    label: 'Camera',
                    isActive: _currentSection == _SettingsSection.camera,
                    onPressed: () => setState(() => _currentSection = _SettingsSection.camera),
                  ),
                  _SectionButton(
                    icon: Icons.gamepad,
                    label: 'Controls',
                    isActive: _currentSection == _SettingsSection.controls,
                    onPressed: () => setState(() => _currentSection = _SettingsSection.controls),
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
      case _SettingsSection.controls:
        return const _ControlsSection();
      case _SettingsSection.camera:
        return const _CameraSection();
      case _SettingsSection.about:
        return const _AboutSection();
    }
  }
}

enum _SettingsSection { robot, aiAgents, camera, controls, profile, about }

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

/// Controls section - quick buttons editor
class _ControlsSection extends StatelessWidget {
  const _ControlsSection();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.xl, bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Quick Buttons'),
          const SizedBox(height: AppSpacing.md),
          
          // Quick button grid editor
          _SettingsCard(
            children: [
              const Text(
                'Configure the 9 programmable buttons on the control panel.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              
              // 3x3 preview grid
              SizedBox(
                height: 200,
                child: Column(
                  children: List.generate(3, (row) {
                    return Expanded(
                      child: Row(
                        children: List.generate(3, (col) {
                          final index = row * 3 + col;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              child: _QuickButtonPreview(
                                index: index,
                                onEdit: () => _showEditButtonDialog(context, index),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.xl),
          const _SectionHeader(title: 'Joystick Settings'),
          const SizedBox(height: AppSpacing.md),
          
          _SettingsCard(
            children: [
              _SliderRow(
                label: 'Max Speed',
                value: 0.5,
                onChanged: (v) {},
              ),
              const Divider(color: AppColors.border),
              _SliderRow(
                label: 'Rotation Speed',
                value: 0.7,
                onChanged: (v) {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditButtonDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => _EditButtonDialog(buttonIndex: index),
    );
  }
}

/// Camera section
class _CameraSection extends StatelessWidget {
  const _CameraSection();

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
                label: 'Show Depth Overlay',
                value: false,
                onChanged: (v) {},
              ),
              const Divider(color: AppColors.border),
              _ToggleRow(
                label: 'Low Bandwidth Mode',
                value: false,
                onChanged: (v) {},
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
                child: const Text(
                  'http://192.168.1.14:8080/stream',
                  style: TextStyle(color: AppColors.textMuted, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Company Info section - Business details
// Daily hours for a single day
class DailyHours {
  final String day;
  TimeOfDay? openTime;
  TimeOfDay? closeTime;
  bool isClosed;
  
  DailyHours({
    required this.day,
    this.openTime,
    this.closeTime,
    this.isClosed = false,
  });
  
  String get displayText {
    if (isClosed) return 'Closed';
    if (openTime == null || closeTime == null) return 'Not set';
    return '${_formatTime(openTime!)} - ${_formatTime(closeTime!)}';
  }
  
  static String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
  
  DailyHours copy() => DailyHours(
    day: day,
    openTime: openTime,
    closeTime: closeTime,
    isClosed: isClosed,
  );
}

// Company policy
class CompanyPolicy {
  String title;
  String description;
  
  CompanyPolicy({
    this.title = '',
    this.description = '',
  });
  
  CompanyPolicy copy() => CompanyPolicy(title: title, description: description);
}

// Persisted company info data
class CompanyInfo {
  // Robot identity
  String robotName;
  String robotIdentity;
  String basePersonality;
  String baseSystemInstructions;
  String voice;
  
  // Business info
  String companyName;
  String address;
  String phone;
  List<DailyHours> hours;
  List<CompanyPolicy> policies;
  
  CompanyInfo({
    this.robotName = '',
    String? robotIdentity,
    String? basePersonality,
    String? baseSystemInstructions,
    this.voice = 'nova',
    this.companyName = '',
    this.address = '',
    this.phone = '',
    List<DailyHours>? hours,
    List<CompanyPolicy>? policies,
  }) : robotIdentity = robotIdentity ?? _defaultRobotIdentity,
       basePersonality = basePersonality ?? _defaultBasePersonality,
       baseSystemInstructions = baseSystemInstructions ?? _defaultBaseSystemInstructions,
       hours = hours ?? _defaultHours(),
       policies = policies ?? [];
  
  // Default robot identity context
  static const String _defaultRobotIdentity = '''You are a friendly service robot. You are a physical robot with wheels, not a chatbot or language model. You can navigate physical spaces and interact with people through voice conversation. You cannot browse the internet or access external systems beyond your local knowledge.''';
  
  // Default personality
  static const String _defaultBasePersonality = '''You are friendly, helpful, and professional. You speak clearly and concisely. You maintain a warm but efficient tone. You are patient and understanding with customers.''';
  
  // Default system instructions  
  static const String _defaultBaseSystemInstructions = '''Keep responses brief and conversational - aim for 1-2 sentences when possible. If you don't know something, say so honestly and offer alternatives. Always be polite and respectful. If a request is beyond your capabilities, offer to get a human staff member.''';
  
  static List<DailyHours> _defaultHours() => [
    DailyHours(day: 'Sunday'),
    DailyHours(day: 'Monday'),
    DailyHours(day: 'Tuesday'),
    DailyHours(day: 'Wednesday'),
    DailyHours(day: 'Thursday'),
    DailyHours(day: 'Friday'),
    DailyHours(day: 'Saturday'),
  ];
  
  bool get isEmpty => robotName.isEmpty && companyName.isEmpty && address.isEmpty && phone.isEmpty && 
    hours.every((h) => h.openTime == null && h.closeTime == null && !h.isClosed) &&
    policies.isEmpty;
    
  bool get hasHours => hours.any((h) => h.openTime != null || h.closeTime != null || h.isClosed);
  
  // Voice options for OpenAI TTS
  static const List<String> voiceOptions = ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'];
}

CompanyInfo _savedCompanyInfo = CompanyInfo();

class _ProfileSection extends StatefulWidget {
  final RosBridge rosBridge;
  
  const _ProfileSection({required this.rosBridge});

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  bool _isEditing = false;
  int? _editingPolicyIndex; // null = not editing, -1 = adding new
  
  final _robotNameController = TextEditingController();
  final _robotIdentityController = TextEditingController();
  final _basePersonalityController = TextEditingController();
  final _baseSystemInstructionsController = TextEditingController();
  String _selectedVoice = 'nova';
  
  final _companyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _policyTitleController = TextEditingController();
  final _policyDescController = TextEditingController();
  
  List<DailyHours> _editingHours = [];
  List<CompanyPolicy> _editingPolicies = [];
  
  // Multi-listener callback (for cleanup)
  late final void Function(CompanyInfoData) _companyInfoListener;

  @override
  void initState() {
    super.initState();
    _setupRosCallback();
    _requestCompanyInfo();
    _loadSavedData();
  }
  
  @override
  void dispose() {
    widget.rosBridge.removeCompanyInfoListener(_companyInfoListener);
    _robotNameController.dispose();
    _robotIdentityController.dispose();
    _basePersonalityController.dispose();
    _baseSystemInstructionsController.dispose();
    _companyNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _policyTitleController.dispose();
    _policyDescController.dispose();
    super.dispose();
  }
  
  void _setupRosCallback() {
    // Multi-listener pattern
    _companyInfoListener = (info) {
      // Convert from ROS format to local format
      _savedCompanyInfo = CompanyInfo(
        robotName: info.robotName,
        robotIdentity: info.robotIdentity.isNotEmpty ? info.robotIdentity : null,
        basePersonality: info.basePersonality.isNotEmpty ? info.basePersonality : null,
        baseSystemInstructions: info.baseSystemInstructions.isNotEmpty ? info.baseSystemInstructions : null,
        voice: info.voice,
        companyName: info.companyName,
        address: info.address,
        phone: info.phone,
        hours: info.hours.map((h) => DailyHours(
          day: h.day,
          openTime: _parseTimeString(h.openTime),
          closeTime: _parseTimeString(h.closeTime),
          isClosed: h.isClosed,
        )).toList(),
        policies: info.policies.map((p) => CompanyPolicy(
          title: p.title,
          description: p.description,
        )).toList(),
      );
      if (mounted && !_isEditing) {
        setState(() {});
      }
    };
    widget.rosBridge.addCompanyInfoListener(_companyInfoListener);
  }
  
  TimeOfDay? _parseTimeString(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      // Parse time like "9:00 AM" or "5:30 PM"
      final parts = timeStr.split(' ');
      if (parts.length != 2) return null;
      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return null;
      var hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPM = parts[1].toUpperCase() == 'PM';
      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }
  
  void _requestCompanyInfo() {
    widget.rosBridge.requestCompanyInfo();
  }
  
  void _loadSavedData() {
    // Robot identity
    _robotNameController.text = _savedCompanyInfo.robotName;
    _robotIdentityController.text = _savedCompanyInfo.robotIdentity;
    _basePersonalityController.text = _savedCompanyInfo.basePersonality;
    _baseSystemInstructionsController.text = _savedCompanyInfo.baseSystemInstructions;
    _selectedVoice = _savedCompanyInfo.voice;
    
    // Business info
    _companyNameController.text = _savedCompanyInfo.companyName;
    _addressController.text = _savedCompanyInfo.address;
    _phoneController.text = _savedCompanyInfo.phone;
    // Use saved hours if available, otherwise use default 7-day schedule
    _editingHours = _savedCompanyInfo.hours.isNotEmpty 
        ? _savedCompanyInfo.hours.map((h) => h.copy()).toList()
        : CompanyInfo._defaultHours();
    _editingPolicies = _savedCompanyInfo.policies.map((p) => p.copy()).toList();
  }

  void _enterEditMode() {
    _loadSavedData();
    setState(() {
      _isEditing = true;
      _editingPolicyIndex = null;
    });
  }

  void _save() {
    // Save to persistent state
    _savedCompanyInfo = CompanyInfo(
      robotName: _robotNameController.text,
      robotIdentity: _robotIdentityController.text,
      basePersonality: _basePersonalityController.text,
      baseSystemInstructions: _baseSystemInstructionsController.text,
      voice: _selectedVoice,
      companyName: _companyNameController.text,
      address: _addressController.text,
      phone: _phoneController.text,
      hours: _editingHours.map((h) => h.copy()).toList(),
      policies: _editingPolicies.map((p) => p.copy()).toList(),
    );
    
    // Save to robot via ROS
    print("💾 Saving profile info to robot...");
    final rosInfo = CompanyInfoData(
      robotName: _savedCompanyInfo.robotName,
      robotIdentity: _savedCompanyInfo.robotIdentity,
      basePersonality: _savedCompanyInfo.basePersonality,
      baseSystemInstructions: _savedCompanyInfo.baseSystemInstructions,
      voice: _savedCompanyInfo.voice,
      companyName: _savedCompanyInfo.companyName,
      address: _savedCompanyInfo.address,
      phone: _savedCompanyInfo.phone,
      hours: _savedCompanyInfo.hours.map((h) => DailyHoursData(
        day: h.day,
        openTime: h.openTime != null ? DailyHours._formatTime(h.openTime!) : null,
        closeTime: h.closeTime != null ? DailyHours._formatTime(h.closeTime!) : null,
        isClosed: h.isClosed,
      )).toList(),
      policies: _savedCompanyInfo.policies.map((p) => PolicyData(
        title: p.title,
        description: p.description,
      )).toList(),
    );
    widget.rosBridge.publishSaveCompanyInfo(rosInfo);
    
    setState(() => _isEditing = false);
    TopNotification.show(context, message: 'Profile saved', backgroundColor: AppColors.success);
  }
  
  Future<void> _pickTime(DailyHours day, bool isOpen) async {
    final initial = isOpen ? (day.openTime ?? const TimeOfDay(hour: 9, minute: 0))
                           : (day.closeTime ?? const TimeOfDay(hour: 17, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accent,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isOpen) {
          day.openTime = picked;
        } else {
          day.closeTime = picked;
        }
        day.isClosed = false;
      });
    }
  }
  
  void _toggleClosed(DailyHours day) {
    setState(() {
      day.isClosed = !day.isClosed;
      if (day.isClosed) {
        day.openTime = null;
        day.closeTime = null;
      }
    });
  }
  
  void _startEditingPolicy(int index) {
    final policy = _editingPolicies[index];
    _policyTitleController.text = policy.title;
    _policyDescController.text = policy.description;
    setState(() => _editingPolicyIndex = index);
  }
  
  void _startAddingPolicy() {
    _policyTitleController.clear();
    _policyDescController.clear();
    setState(() => _editingPolicyIndex = -1);
  }
  
  void _savePolicy() {
    final title = _policyTitleController.text.trim();
    final desc = _policyDescController.text.trim();
    if (title.isEmpty) return;
    
    setState(() {
      if (_editingPolicyIndex == -1) {
        // Adding new
        _editingPolicies.add(CompanyPolicy(title: title, description: desc));
      } else if (_editingPolicyIndex != null) {
        // Editing existing
        _editingPolicies[_editingPolicyIndex!] = CompanyPolicy(title: title, description: desc);
      }
      _editingPolicyIndex = null;
    });
  }
  
  void _deletePolicy() {
    if (_editingPolicyIndex != null && _editingPolicyIndex! >= 0) {
      setState(() {
        _editingPolicies.removeAt(_editingPolicyIndex!);
        _editingPolicyIndex = null;
      });
    }
  }
  
  void _cancelPolicyEdit() {
    setState(() => _editingPolicyIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    return _isEditing ? _buildEditView() : _buildDisplayView();
  }
  
  Widget _buildDisplayView() {
    final info = _savedCompanyInfo;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with edit button
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
          
          // Display saved info
          if (info.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text(
                  'No profile saved yet.\nTap Edit to add your robot and business details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else ...[
            // Robot section container
            _buildSectionHeader('Robot', Icons.smart_toy),
            const SizedBox(height: AppSpacing.sm),
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
                  if (info.robotName.isNotEmpty) ...[
                    _buildDisplayField('Robot Name', info.robotName),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _buildDisplayField('Voice', '${info.voice.substring(0, 1).toUpperCase()}${info.voice.substring(1)} - ${_getVoiceDescription(info.voice)}'),
                  const SizedBox(height: AppSpacing.lg),
                  _buildDisplayFieldTruncated('Robot Identity', info.robotIdentity),
                  const SizedBox(height: AppSpacing.lg),
                  _buildDisplayFieldTruncated('Base Personality', info.basePersonality),
                  const SizedBox(height: AppSpacing.lg),
                  _buildDisplayFieldTruncated('Base Instructions', info.baseSystemInstructions),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            // Business section container
            _buildSectionHeader('Business', Icons.business),
            const SizedBox(height: AppSpacing.sm),
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
                  if (info.companyName.isNotEmpty) ...[
                    _buildDisplayField('Company Name', info.companyName),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (info.address.isNotEmpty) ...[
                    _buildDisplayField('Address', info.address),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (info.phone.isNotEmpty) ...[
                    _buildDisplayField('Phone', info.phone),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (info.hasHours) ...[
                    _buildHoursDisplay(info.hours),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (info.policies.isNotEmpty)
                    _buildPoliciesDisplay(info.policies),
                  if (info.companyName.isEmpty && info.address.isEmpty && info.phone.isEmpty && !info.hasHours && info.policies.isEmpty)
                    Text(
                      'No business info added yet.',
                      style: TextStyle(color: AppColors.textMuted.withOpacity(0.7), fontSize: 14),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildDisplayFieldTruncated(String label, String value, {int maxLength = 80}) {
    final truncated = value.length > maxLength 
        ? '${value.substring(0, maxLength).trim()}...' 
        : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          truncated,
          style: TextStyle(
            color: AppColors.textPrimary.withOpacity(0.8),
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildDisplayField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
  
  Widget _buildHoursDisplay(List<DailyHours> hours) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hours of Operation',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...hours.where((h) => h.openTime != null || h.closeTime != null || h.isClosed).map((h) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  h.day,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                ),
              ),
              Text(
                h.displayText,
                style: TextStyle(
                  color: h.isClosed ? AppColors.textMuted : AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
  
  Widget _buildPoliciesDisplay(List<CompanyPolicy> policies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'General Policies',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...policies.map((p) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (p.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  p.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        )),
      ],
    );
  }
  
  Widget _buildEditView() {
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
                'Edit Profile',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Cancel button
              GestureDetector(
                onTap: () => setState(() => _isEditing = false),
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
          
          // Robot Info section
          _buildSectionHeader('Robot', Icons.smart_toy),
          const SizedBox(height: AppSpacing.sm),
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
                _buildTextField(
                  controller: _robotNameController,
                  label: 'Robot Name',
                  hint: 'Enter robot name (e.g., Millie)',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.lg),
                // Voice selector
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Voice',
                      style: TextStyle(
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
                          value: _selectedVoice,
                          isExpanded: true,
                          dropdownColor: AppColors.surface,
                          items: CompanyInfo.voiceOptions.map((voice) => DropdownMenuItem(
                            value: voice,
                            child: Text(
                              voice.substring(0, 1).toUpperCase() + voice.substring(1),
                              style: const TextStyle(color: AppColors.textPrimary),
                            ),
                          )).toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _selectedVoice = value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _getVoiceDescription(_selectedVoice),
                      style: TextStyle(color: AppColors.textMuted.withOpacity(0.7), fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildTextField(
                  controller: _robotIdentityController,
                  label: 'Robot Identity',
                  hint: 'Core identity context (e.g., "You are a physical robot...")',
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildTextField(
                  controller: _basePersonalityController,
                  label: 'Base Personality & Tone',
                  hint: 'Foundational personality traits',
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildTextField(
                  controller: _baseSystemInstructionsController,
                  label: 'Base System Instructions',
                  hint: 'Core behavioral rules',
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Business Info section
          _buildSectionHeader('Business', Icons.business),
          const SizedBox(height: AppSpacing.sm),
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
                _buildTextField(
                  controller: _companyNameController,
                  label: 'Company Name',
                  hint: 'Enter company name',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildTextField(
                  controller: _addressController,
                  label: 'Address',
                  hint: 'Enter address',
                  maxLines: 2,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone',
                  hint: 'Enter phone number',
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Hours section
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
                const Text(
                  'Hours of Operation',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ..._editingHours.map((day) => _buildDayRow(day)),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.lg),
          
          // Policies section
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
                Row(
                  children: [
                    const Text(
                      'General Policies',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_editingPolicyIndex == null)
                      GestureDetector(
                        onTap: _startAddingPolicy,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(AppRadius.small),
                            border: Border.all(color: AppColors.accent),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: AppColors.accent, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Add',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                
                // Policy editor or list
                if (_editingPolicyIndex != null)
                  _buildPolicyEditor()
                else
                  ..._editingPolicies.asMap().entries.map((e) => _buildPolicyItem(e.key, e.value)),
                  
                if (_editingPolicies.isEmpty && _editingPolicyIndex == null)
                  const Center(
                    child: Text(
                      'No policies added yet',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.xl),
          
          // Full-width Save button
          GestureDetector(
            onTap: _save,
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
        ],
      ),
    );
  }
  
  Widget _buildDayRow(DailyHours day) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              day.day,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
          // Open time
          Expanded(
            child: GestureDetector(
              onTap: day.isClosed ? null : () => _pickTime(day, true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: day.isClosed ? AppColors.background.withOpacity(0.5) : AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  day.openTime != null ? DailyHours._formatTime(day.openTime!) : 'Open',
                  style: TextStyle(
                    color: day.isClosed ? AppColors.textMuted : 
                           (day.openTime != null ? AppColors.textPrimary : AppColors.textMuted),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text('-', style: TextStyle(color: AppColors.textMuted)),
          ),
          // Close time
          Expanded(
            child: GestureDetector(
              onTap: day.isClosed ? null : () => _pickTime(day, false),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: day.isClosed ? AppColors.background.withOpacity(0.5) : AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  day.closeTime != null ? DailyHours._formatTime(day.closeTime!) : 'Close',
                  style: TextStyle(
                    color: day.isClosed ? AppColors.textMuted : 
                           (day.closeTime != null ? AppColors.textPrimary : AppColors.textMuted),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Closed toggle
          GestureDetector(
            onTap: () => _toggleClosed(day),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: day.isClosed ? AppColors.danger.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.small),
                border: Border.all(
                  color: day.isClosed ? AppColors.danger : AppColors.border,
                ),
              ),
              child: Text(
                'Closed',
                style: TextStyle(
                  color: day.isClosed ? AppColors.danger : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: day.isClosed ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPolicyItem(int index, CompanyPolicy policy) {
    return GestureDetector(
      onTap: () => _startEditingPolicy(index),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    policy.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (policy.description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      policy.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.edit, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPolicyEditor() {
    final isNew = _editingPolicyIndex == -1;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: AppColors.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _policyTitleController,
            label: 'Policy Title',
            hint: 'Enter policy title',
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTextField(
            controller: _policyDescController,
            label: 'Policy Description',
            hint: 'Describe this policy',
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Save button
          GestureDetector(
            onTap: _savePolicy,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
          
          // Delete button (only for existing policies)
          if (!isNew) ...[
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: _deletePolicy,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: AppSpacing.sm),
          // Cancel link
          Center(
            child: GestureDetector(
              onTap: _cancelPolicyEdit,
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getVoiceDescription(String voice) {
    switch (voice) {
      case 'alloy': return 'Neutral, balanced';
      case 'echo': return 'Warm, conversational';
      case 'fable': return 'British, storyteller';
      case 'onyx': return 'Deep, authoritative';
      case 'nova': return 'Energetic, bright';
      case 'shimmer': return 'Soft, gentle';
      default: return '';
    }
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType? keyboardType,
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
          textCapitalization: textCapitalization,
          keyboardType: keyboardType,
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
}

/// AI Agents section - Reusable agent configurations
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
  final _descriptionController = TextEditingController();
  final _systemInstructionsController = TextEditingController();
  final _personalityController = TextEditingController();
  final _voiceStyleController = TextEditingController();
  final _knowledgeFocusController = TextEditingController();
  
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
    _descriptionController.dispose();
    _systemInstructionsController.dispose();
    _personalityController.dispose();
    _voiceStyleController.dispose();
    _knowledgeFocusController.dispose();
    super.dispose();
  }
  
  void _startNewAgent() {
    _nameController.clear();
    _descriptionController.clear();
    _systemInstructionsController.clear();
    _personalityController.clear();
    _voiceStyleController.clear();
    _knowledgeFocusController.clear();
    setState(() => _editingIndex = -1);
  }
  
  void _editAgent(int index) {
    final agent = _agents[index];
    _nameController.text = agent.name;
    _descriptionController.text = agent.description;
    _systemInstructionsController.text = agent.systemInstructions;
    _personalityController.text = agent.personality;
    _voiceStyleController.text = agent.voiceStyle;
    _knowledgeFocusController.text = agent.knowledgeFocus;
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
      description: _descriptionController.text.trim(),
      systemInstructions: _systemInstructionsController.text.trim(),
      personality: _personalityController.text.trim(),
      voiceStyle: _voiceStyleController.text.trim(),
      knowledgeFocus: _knowledgeFocusController.text.trim(),
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
                'AI Agents',
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
                      'No AI Agents configured',
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
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: const Icon(Icons.psychology, color: AppColors.accent, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (agent.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    agent.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
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
                    'Default',
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
                      'Set Default',
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
                _buildTextField(
                  controller: _nameController,
                  label: 'Agent Name',
                  hint: 'e.g., Greeter, Bartender, Tour Guide',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Brief description of what this agent does',
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildTextField(
                  controller: _personalityController,
                  label: 'Additional Personality & Tone',
                  hint: 'Added on top of base personality from Profile',
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildTextField(
                  controller: _systemInstructionsController,
                  label: 'Additional System Instructions',
                  hint: 'Added on top of base instructions from Profile',
                  maxLines: null,
                  minLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildTextField(
                  controller: _knowledgeFocusController,
                  label: 'Knowledge Focus',
                  hint: 'What topics should this agent know about?',
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildTextField(
                  controller: _voiceStyleController,
                  label: 'Voice Style (Optional)',
                  hint: 'e.g., Upbeat, Calm, Energetic',
                  textCapitalization: TextCapitalization.words,
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
  final int index;
  final VoidCallback onEdit;

  const _QuickButtonPreview({required this.index, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${index + 1}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 18),
              ),
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
  
  const _EditButtonDialog({required this.buttonIndex});

  @override
  State<_EditButtonDialog> createState() => _EditButtonDialogState();
}

class _EditButtonDialogState extends State<_EditButtonDialog> {
  String _actionType = 'waypoint';
  String? _selectedWaypoint;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Action Type:', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            
            // Action type selector
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                _ActionChip(
                  label: 'Waypoint',
                  isSelected: _actionType == 'waypoint',
                  onSelected: () => setState(() => _actionType = 'waypoint'),
                ),
                _ActionChip(
                  label: 'Workflow',
                  isSelected: _actionType == 'workflow',
                  onSelected: () => setState(() => _actionType = 'workflow'),
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            if (_actionType == 'waypoint') ...[
              const Text('Select Waypoint:', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              // Demo waypoint list
              _WaypointOption(
                name: 'Home',
                isSelected: _selectedWaypoint == 'Home',
                onSelected: () => setState(() => _selectedWaypoint = 'Home'),
              ),
              _WaypointOption(
                name: 'Kitchen',
                isSelected: _selectedWaypoint == 'Kitchen',
                onSelected: () => setState(() => _selectedWaypoint = 'Kitchen'),
              ),
              _WaypointOption(
                name: 'Office',
                isSelected: _selectedWaypoint == 'Office',
                onSelected: () => setState(() => _selectedWaypoint = 'Office'),
              ),
            ],
            
            if (_actionType == 'workflow') ...[
              const Text(
                'Create multi-step workflows in the Workflows section.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: () {
            debugPrint("Saved button ${widget.buttonIndex + 1}: $_actionType -> $_selectedWaypoint");
            Navigator.pop(context);
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

