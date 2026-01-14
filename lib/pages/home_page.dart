import 'package:flutter/material.dart';
import '../config/robot_config.dart';
import '../utils/constants.dart';
import '../utils/rosbridge.dart';
import '../utils/robot_api.dart';
import '../widgets/icon_rail.dart';
import '../widgets/video_panel.dart';
import '../widgets/chatbot_panel.dart';
import '../widgets/joystick_panel.dart';
import '../widgets/map_panel.dart';
import '../widgets/top_notification.dart';
import 'settings_page.dart';
import 'locations_page.dart';
import 'tickets_page.dart';

// Top-level state that persists across all rebuilds
// Nullable to prevent hot reload from resetting values
MainView? _persistedView;
bool? _persistedJoystickVisible;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ROS bridge connection
  late RosBridge rosBridge;
  bool _rosbridgeConnected = false;
  
  // Robot API (boot server)
  late RobotApi robotApi;
  
  // Use top-level persisted state with fallback defaults
  MainView get _currentView => _persistedView ?? MainView.camera;
  set _currentView(MainView view) => _persistedView = view;
  
  bool get _joystickVisible => _persistedJoystickVisible ?? true;
  set _joystickVisible(bool visible) => _persistedJoystickVisible = visible;

  @override
  void initState() {
    super.initState();
    robotApi = RobotApi(RobotConfig.apiUrl);
    rosBridge = RosBridge(RobotConfig.rosbridgeUrl);
    
    // Listen for connection changes
    rosBridge.onConnectionChange = (connected) {
      if (mounted) {
        setState(() => _rosbridgeConnected = connected);
      }
    };
    
    // Try to connect to ROSBridge immediately (in case ROS is already running)
    rosBridge.connect();
  }
  
  void _onRosStarted(String mode) {
    // Connect to rosbridge once ROS is running
    Future.delayed(const Duration(seconds: 3), () {
      rosBridge.connect();
    });
    
    // Switch view based on mode
    setState(() {
      if (mode == 'main') {
        // Manual mode -> Camera
        _currentView = MainView.camera;
      } else {
        // Mapping or Nav mode -> Map
        _currentView = MainView.map;
      }
    });
  }

  @override
  void dispose() {
    rosBridge.close();
    super.dispose();
  }

  void _handleEstop() {
    debugPrint("🔴 E-STOP pressed!");
    
    // Stop all motion immediately
    rosBridge.publishEstop();
    
    // Show visual feedback
    TopNotification.show(
      context,
      message: '🛑 E-STOP ACTIVATED',
      backgroundColor: AppColors.danger,
      duration: const Duration(seconds: 3),
    );
  }

  void _handleShutdown() async {
    debugPrint("⚡ Power shutdown confirmed");
    final result = await robotApi.shutdown();
    TopNotification.show(
      context,
      message: result.success ? '🔌 Robot shutting down...' : '❌ Shutdown failed',
      backgroundColor: result.success ? AppColors.warning : AppColors.danger,
    );
  }

  void _handleReboot() async {
    debugPrint("🔄 Reboot confirmed");
    final result = await robotApi.reboot();
    TopNotification.show(
      context,
      message: result.success ? '🔄 Robot rebooting...' : '❌ Reboot failed',
      backgroundColor: result.success ? AppColors.warning : AppColors.danger,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,  // Resize when keyboard appears
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final bool isLandscape = orientation == Orientation.landscape;
            final bool showJoystick = _joystickVisible && 
                _currentView != MainView.locations &&
                _currentView != MainView.tickets &&
                _currentView != MainView.chat && 
                _currentView != MainView.settings;
            
            // Top bar above everything (full width, static)
            // Landscape: LeftRail | Content | Joystick | RightRail
            // Portrait: LeftRail | Content (+ Joystick at bottom)
            return Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Row(
                    children: [
                      // Left rail (navigation views)
                      IconRail(
                        selectedView: _currentView,
                        onViewChanged: (view) => setState(() => _currentView = view),
                        joystickVisible: _joystickVisible,
                        onJoystickToggle: () => setState(() => _joystickVisible = !_joystickVisible),
                        onEstop: _handleEstop,
                        onShutdown: _handleShutdown,
                        onReboot: _handleReboot,
                        rosConnected: _rosbridgeConnected,
                        onSettingsSidebarToggle: () {
                          SettingsPage.toggleSidebar();
                          setState(() {});
                        },
                        showControls: !isLandscape,  // Hide controls in landscape (moved to right rail)
                      ),
                      if (isLandscape) ...[
                        // Landscape: Content | Joystick | RightRail
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.xs,
                              right: AppSpacing.xs,
                              bottom: AppSpacing.xs,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.medium),
                              child: _buildMainContent(),
                            ),
                          ),
                        ),
                        if (showJoystick)
                          JoystickPanel(rosBridge: rosBridge, isPortrait: false),
                        // Right rail (controls: Power, Status, Joystick toggle)
                        ControlRail(
                          joystickVisible: _joystickVisible,
                          onJoystickToggle: () => setState(() => _joystickVisible = !_joystickVisible),
                          onShutdown: _handleShutdown,
                          onReboot: _handleReboot,
                          rosConnected: _rosbridgeConnected,
                        ),
                      ] else ...[
                        // Portrait: Content (top) / Joystick (bottom)
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.only(
                                    left: AppSpacing.xs,
                                    right: AppSpacing.xs,
                                    bottom: AppSpacing.xs,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(AppRadius.medium),
                                    child: _buildMainContent(),
                                  ),
                                ),
                              ),
                              if (showJoystick)
                                JoystickPanel(rosBridge: rosBridge, isPortrait: true),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      color: AppColors.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Millie Bot AI',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small - 2),
              child: Image.asset(
                'assets/icon/logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const Text(
            'Dream Cloud',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_currentView) {
      case MainView.camera:
        return const VideoPanel();
      case MainView.map:
        return MapPanel(rosBridge: rosBridge);
      case MainView.tickets:
        return TicketsPage(
          rosBridge: rosBridge,
          onBack: () {},  // No back action needed in dashboard
        );
      case MainView.locations:
        return LocationsPage(rosBridge: rosBridge);
      case MainView.chat:
        return ChatbotPanel(rosBridge: rosBridge);
      case MainView.settings:
        return SettingsPage(
          rosBridge: rosBridge,
          robotApi: robotApi,
          onModeStarted: _onRosStarted,
        );
    }
  }
}
