// lib/services/navigation_tools.dart
import 'package:flutter/foundation.dart';
import '../utils/rosbridge.dart';

/// Navigation tools for AI function calling
/// Defines the tools schema and handles execution
class NavigationTools {
  final RosBridge rosBridge;
  
  // Local cache from listener updates
  List<Waypoint> _localWaypoints = [];
  List<SavedSequence> _localRoutes = [];
  RobotPose? _localPose;
  
  // Getters that fall back to ROSBridge central storage
  List<Waypoint> get waypoints => _localWaypoints.isNotEmpty ? _localWaypoints : rosBridge.waypoints;
  List<SavedSequence> get routes => _localRoutes.isNotEmpty ? _localRoutes : rosBridge.sequences;
  RobotPose? get currentPose => _localPose ?? rosBridge.currentPose;
  
  // Track current route for pause/resume
  SavedSequence? _currentRoute;
  int _currentStep = 0;
  bool _isPaused = false;
  
  NavigationTools(this.rosBridge);
  
  /// Update waypoints from listener
  void updateWaypoints(List<Waypoint> newWaypoints) {
    _localWaypoints = newWaypoints;
    debugPrint('🧭 [NavigationTools] Updated with ${newWaypoints.length} waypoints');
  }
  
  /// Update routes from listener
  void updateRoutes(List<SavedSequence> newRoutes) {
    _localRoutes = newRoutes;
    debugPrint('🧭 [NavigationTools] Updated with ${newRoutes.length} routes');
  }
  
  /// Update robot pose from listener
  void updatePose(RobotPose pose) {
    _localPose = pose;
  }
  
  /// Get tool definitions for OpenAI function calling
  List<Map<String, dynamic>> getToolDefinitions() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'navigate_to_waypoint',
          'description': 'Navigate the robot to a saved waypoint/location by name. Use this when the user wants to go to a specific place like "kitchen", "desk", "home", etc.',
          'parameters': {
            'type': 'object',
            'properties': {
              'waypoint_name': {
                'type': 'string',
                'description': 'The name of the waypoint to navigate to',
              },
            },
            'required': ['waypoint_name'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'execute_route',
          'description': 'Execute a saved navigation route (sequence of waypoints). Use this when the user wants to run a patrol, delivery route, or multi-stop journey.',
          'parameters': {
            'type': 'object',
            'properties': {
              'route_name': {
                'type': 'string',
                'description': 'The name of the saved route to execute',
              },
            },
            'required': ['route_name'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'pause_navigation',
          'description': 'Pause the current route/navigation. The robot will stop but remember where it was. Use when user says "pause", "wait", "hold on".',
          'parameters': {
            'type': 'object',
            'properties': {},
            'required': [],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'resume_navigation',
          'description': 'Resume a paused route from where it left off. Use when user says "resume", "continue", "keep going".',
          'parameters': {
            'type': 'object',
            'properties': {},
            'required': [],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'restart_navigation',
          'description': 'Restart the current route from the beginning. Use when user says "restart", "start over", "from the top".',
          'parameters': {
            'type': 'object',
            'properties': {},
            'required': [],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'stop_navigation',
          'description': 'Completely stop and cancel the current route. Use when user says "stop", "cancel", "abort", or wants to end navigation entirely.',
          'parameters': {
            'type': 'object',
            'properties': {},
            'required': [],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'get_available_locations',
          'description': 'Get a list of all available waypoints/locations the robot can navigate to. Use when the user asks "where can you go?" or "what locations do you know?"',
          'parameters': {
            'type': 'object',
            'properties': {},
            'required': [],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'get_available_routes',
          'description': 'Get a list of all saved routes/sequences. Use when the user asks about available routes or patrols.',
          'parameters': {
            'type': 'object',
            'properties': {},
            'required': [],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'get_robot_status',
          'description': 'Get the current robot position and status. Use when the user asks "where are you?" or wants to know the robot\'s current location.',
          'parameters': {
            'type': 'object',
            'properties': {},
            'required': [],
          },
        },
      },
    ];
  }
  
  /// Execute a tool call and return the result
  String executeTool(String toolName, Map<String, dynamic> arguments) {
    debugPrint('NavigationTools: Executing $toolName with $arguments');
    
    switch (toolName) {
      case 'navigate_to_waypoint':
        return _navigateToWaypoint(arguments['waypoint_name'] as String);
        
      case 'execute_route':
        return _executeRoute(arguments['route_name'] as String);
        
      case 'pause_navigation':
        return _pauseNavigation();
        
      case 'resume_navigation':
        return _resumeNavigation();
        
      case 'restart_navigation':
        return _restartNavigation();
        
      case 'stop_navigation':
        return _stopNavigation();
        
      case 'get_available_locations':
        return _getAvailableLocations();
        
      case 'get_available_routes':
        return _getAvailableRoutes();
        
      case 'get_robot_status':
        return _getRobotStatus();
        
      default:
        return 'Unknown tool: $toolName';
    }
  }
  
  String _navigateToWaypoint(String waypointName) {
    // Find the waypoint (case-insensitive)
    final waypoint = waypoints.firstWhere(
      (w) => w.name.toLowerCase() == waypointName.toLowerCase(),
      orElse: () => Waypoint(name: '', x: 0, y: 0),
    );
    
    if (waypoint.name.isEmpty) {
      final available = waypoints.map((w) => w.name).join(', ');
      return 'Waypoint "$waypointName" not found. Available waypoints: $available';
    }
    
    // Send navigation command
    rosBridge.publishGoToWaypoint(waypoint.name);
    return 'Navigating to ${waypoint.name}. The robot is now moving to this location.';
  }
  
  String _executeRoute(String routeName) {
    // Find the route (case-insensitive)
    final route = routes.firstWhere(
      (r) => r.name.toLowerCase() == routeName.toLowerCase(),
      orElse: () => SavedSequence(name: '', waypointNames: []),
    );
    
    if (route.name.isEmpty) {
      if (routes.isEmpty) {
        return 'No routes have been saved yet. Create routes in the Navigation Planner.';
      }
      final available = routes.map((r) => r.name).join(', ');
      return 'Route "$routeName" not found. Available routes: $available';
    }
    
    // Track current route for pause/resume
    _currentRoute = route;
    _currentStep = 0;
    _isPaused = false;
    
    // Execute as workflow (same format as Locations page)
    final steps = route.waypointNames.map((name) => <String, String>{
      'type': 'navigate',
      'value': name,
    }).toList();
    
    rosBridge.publishWorkflow(steps);
    return 'Executing route "${route.name}" with ${route.waypointNames.length} stops: ${route.waypointNames.join(' → ')}';
  }
  
  String _pauseNavigation() {
    if (_currentRoute == null) {
      return 'No route is currently running.';
    }
    
    rosBridge.publishWorkflowCancel();
    _isPaused = true;
    return 'Route paused. Say "resume" to continue or "stop" to cancel.';
  }
  
  String _resumeNavigation() {
    if (_currentRoute == null) {
      return 'No route to resume. Start a route first.';
    }
    if (!_isPaused) {
      return 'Route is already running.';
    }
    
    // Resume from current step
    final remainingWaypoints = _currentRoute!.waypointNames.skip(_currentStep).toList();
    if (remainingWaypoints.isEmpty) {
      _currentRoute = null;
      return 'Route already completed.';
    }
    
    final steps = remainingWaypoints.map((name) => <String, String>{
      'type': 'navigate',
      'value': name,
    }).toList();
    
    rosBridge.publishWorkflow(steps);
    _isPaused = false;
    return 'Resuming route from ${remainingWaypoints.first}. ${remainingWaypoints.length} stops remaining.';
  }
  
  String _restartNavigation() {
    if (_currentRoute == null) {
      return 'No route to restart. Start a route first.';
    }
    
    _currentStep = 0;
    _isPaused = false;
    
    final steps = _currentRoute!.waypointNames.map((name) => <String, String>{
      'type': 'navigate',
      'value': name,
    }).toList();
    
    rosBridge.publishWorkflow(steps);
    return 'Restarting route "${_currentRoute!.name}" from the beginning.';
  }
  
  String _stopNavigation() {
    rosBridge.publishWorkflowCancel();
    rosBridge.publishEstop();
    final routeName = _currentRoute?.name;
    _currentRoute = null;
    _currentStep = 0;
    _isPaused = false;
    
    if (routeName != null) {
      return 'Route "$routeName" cancelled. The robot has stopped.';
    }
    return 'Navigation stopped.';
  }
  
  String _getAvailableLocations() {
    if (waypoints.isEmpty) {
      return 'No waypoints have been saved yet. Save some locations first using the Locations page.';
    }
    
    final names = waypoints.map((w) => w.name).join(', ');
    return 'Available locations: $names';
  }
  
  String _getAvailableRoutes() {
    if (routes.isEmpty) {
      return 'No routes have been saved yet. Create routes in the Navigation Planner.';
    }
    
    final descriptions = routes.map((r) => 
      '• ${r.name}: ${r.waypointNames.join(' → ')}'
    ).join('\n');
    return 'Available routes:\n$descriptions';
  }
  
  String _getRobotStatus() {
    if (currentPose == null) {
      return 'Robot position unknown. The robot may still be localizing.';
    }
    
    // Find nearest waypoint
    String nearestWaypoint = 'unknown location';
    double minDist = double.infinity;
    
    for (final wp in waypoints) {
      final dx = wp.x - currentPose!.x;
      final dy = wp.y - currentPose!.y;
      final dist = (dx * dx + dy * dy);
      if (dist < minDist) {
        minDist = dist;
        nearestWaypoint = wp.name;
      }
    }
    
    final distMeters = minDist < 0.5 ? 'at' : '${(minDist * 10).round() / 10}m from';
    return 'The robot is $distMeters $nearestWaypoint. Position: (${currentPose!.x.toStringAsFixed(2)}, ${currentPose!.y.toStringAsFixed(2)})';
  }
  
  /// Build system prompt with current context
  String buildSystemPrompt() {
    final waypointList = waypoints.isNotEmpty 
        ? waypoints.map((w) => w.name).join(', ')
        : 'none saved yet';
    
    final routeList = routes.isNotEmpty
        ? routes.map((r) => '${r.name} (${r.waypointNames.join(' → ')})').join('; ')
        : 'none saved yet';
    
    return '''You are Millie, a friendly robot assistant that can navigate around the house.
You help users by understanding their requests and navigating to locations or executing routes.

AVAILABLE WAYPOINTS: $waypointList
SAVED ROUTES: $routeList

When users ask you to go somewhere or do a route, use the appropriate navigation tools.
Be conversational and friendly. Confirm what you're doing.
Keep responses brief and natural - you're a helpful robot companion.

Examples:
- "Go to the kitchen" → use navigate_to_waypoint with "kitchen"
- "Do the full cycle" → use execute_route with the route name
- "Pause" / "Wait" → use pause_navigation
- "Resume" / "Continue" → use resume_navigation  
- "Restart" / "Start over" → use restart_navigation
- "Stop" / "Cancel" → use stop_navigation
- "Where can you go?" → use get_available_locations''';
  }
}

