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

  // Track modes
  bool _isFollowing = false;
  bool _isWatching = false;
  bool _isWandering = false;
  RobotPose? _goAwayPose;  // Saved position for come_back

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
      // DIRECT MOVEMENT
      {
        'type': 'function',
        'function': {
          'name': 'move_robot',
          'description': 'Move the robot directly. Use for "turn left", "turn right", "go forward", "back up", "spin around".',
          'parameters': {
            'type': 'object',
            'properties': {
              'direction': {
                'type': 'string',
                'enum': ['forward', 'back', 'left', 'right', 'spin_left', 'spin_right', 'stop'],
                'description': 'Direction to move',
              },
            },
            'required': ['direction'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'stop_robot',
          'description': 'Stop the robot immediately. Use when user says "stop", "halt", "freeze".',
          'parameters': {
            'type': 'object',
            'properties': {},
            'required': [],
          },
        },
      },
      // FOLLOW / APPROACH
      {
        'type': 'function',
        'function': {
          'name': 'follow_user',
          'description': 'Robot follows the user, maintaining distance. Use when user says "follow me", "come with me".',
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
          'name': 'stop_following',
          'description': 'Stop following the user. Use when user says "stop following", "stay here", "wait here".',
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
          'name': 'approach_user',
          'description': 'Robot approaches the detected person. Use when user says "come here", "come closer".',
          'parameters': {
            'type': 'object',
            'properties': {},
            'required': [],
          },
        },
      },
      // WATCH (camera tracking)
      {
        'type': 'function',
        'function': {
          'name': 'watch_user',
          'description': 'Camera tracks and centers on the user (robot stays still). Use when user says "watch me", "look at me", "keep me in frame".',
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
          'name': 'stop_watching',
          'description': 'Stop tracking the user with camera. Use when user says "stop watching", "look away".',
          'parameters': {
            'type': 'object',
            'properties': {},
            'required': [],
          },
        },
      },
      // WANDER
      {
        'type': 'function',
        'function': {
          'name': 'go_away',
          'description': 'Robot goes away and wanders. Saves current position to return to later. Use when user says "go away", "leave me alone", "go explore".',
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
          'name': 'come_back',
          'description': 'Robot returns to where it was when told to go away. Use when user says "come back" or "return".',
          'parameters': {
            'type': 'object',
            'properties': {},
            'required': [],
          },
        },
      },
      // SPEAK
      {
        'type': 'function',
        'function': {
          'name': 'say_message',
          'description': 'Make the robot say something out loud through its speakers immediately. Use when user wants the robot to speak a message right now where it is.',
          'parameters': {
            'type': 'object',
            'properties': {
              'message': {
                'type': 'string',
                'description': 'The message for the robot to say',
              },
            },
            'required': ['message'],
          },
        },
      },
      // DELIVER MESSAGE
      {
        'type': 'function',
        'function': {
          'name': 'deliver_message',
          'description': 'Navigate to a location and deliver a message. Use when user wants to send a message to someone at a specific place, like "tell Sarah in the kitchen that dinner is ready" or "go to the office and say the meeting is starting".',
          'parameters': {
            'type': 'object',
            'properties': {
              'destination': {
                'type': 'string',
                'description': 'The waypoint/location to navigate to',
              },
              'message': {
                'type': 'string',
                'description': 'The FULL message to speak when the robot arrives. Include a greeting with the recipient name if mentioned (e.g., "Hi Tom! There is a meeting at 4 o clock."). Make it conversational and complete.',
              },
            },
            'required': ['destination', 'message'],
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

      case 'move_robot':
        return _moveRobot(arguments['direction'] as String);

      case 'stop_robot':
        return _stopRobot();

      case 'follow_user':
        return _followUser();

      case 'stop_following':
        return _stopFollowing();

      case 'approach_user':
        return _approachUser();

      case 'watch_user':
        return _watchUser();

      case 'stop_watching':
        return _stopWatching();

      case 'go_away':
        return _goAway();

      case 'come_back':
        return _comeBack();

      case 'say_message':
        return _sayMessage(arguments['message'] as String);

      case 'deliver_message':
        final dest = arguments['destination'] as String?;
        final msg = arguments['message'] as String?;
        debugPrint('🎯 [deliver_message] CALLED with dest="$dest", msg="$msg"');
        if (dest == null || msg == null) {
          return 'Missing destination or message';
        }
        _deliverMessageAsync(dest, msg);
        return 'Delivering message to $dest...';

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

  String _moveRobot(String direction) {
    rosBridge.publishMove(direction);
    final descriptions = {
      'forward': 'Moving forward',
      'back': 'Backing up',
      'left': 'Turning left',
      'right': 'Turning right',
      'spin_left': 'Spinning left',
      'spin_right': 'Spinning right',
      'stop': 'Stopping',
    };
    return descriptions[direction] ?? 'Moving $direction';
  }

  String _stopRobot() {
    rosBridge.publishEstop();
    return 'Robot stopped.';
  }

  String _followUser() {
    rosBridge.publishEnablePersonFollower();
    _isFollowing = true;
    return 'Following mode enabled. The robot will follow you.';
  }

  String _stopFollowing() {
    rosBridge.publishDisablePersonFollower();
    _isFollowing = false;
    return 'Following mode disabled. The robot will stay here.';
  }

  String _approachUser() {
    // Enable follower briefly to approach, it will stop when close
    rosBridge.publishEnablePersonFollower();
    return 'Approaching. The robot is coming to you.';
  }

  String _watchUser() {
    rosBridge.publishCenterOnHuman(true);
    _isWatching = true;
    return 'Watching mode enabled. The camera will track you.';
  }

  String _stopWatching() {
    rosBridge.publishCenterOnHuman(false);
    _isWatching = false;
    return 'Watching mode disabled.';
  }

  String _goAway() {
    // Save current position for come_back
    _goAwayPose = currentPose;
    rosBridge.publishWanderEnable();
    _isWandering = true;
    return 'Going away to explore. Say "come back" when you want me to return.';
  }

  String _comeBack() {
    rosBridge.publishWanderDisable();
    _isWandering = false;

    if (_goAwayPose != null) {
      // Navigate back to saved position
      rosBridge.publishNavGoal(_goAwayPose!.x, _goAwayPose!.y);
      return 'Coming back to where I was.';
    }
    return 'Stopping wander mode.';
  }

  String _sayMessage(String message) {
    rosBridge.publishSpeak(message);
    return 'Speaking: "$message"';
  }

  Future<void> _deliverMessageAsync(String destination, String message) async {
    try {
      debugPrint('🚀 [deliver_message] Starting: dest="$destination", msg="$message"');
      debugPrint('🚀 [deliver_message] Available waypoints: ${waypoints.map((w) => w.name).toList()}');

      // Find the waypoint (case-insensitive)
      final waypoint = waypoints.firstWhere(
        (w) => w.name.toLowerCase() == destination.toLowerCase(),
        orElse: () => Waypoint(name: '', x: 0, y: 0),
      );

      if (waypoint.name.isEmpty) {
        debugPrint('❌ [deliver_message] Waypoint "$destination" not found!');
        return;
      }

      debugPrint('📍 [deliver_message] Found waypoint: ${waypoint.name}');

      // Create action for the message (same as millie_ai's approach)
      final actionName = 'Message: ${waypoint.name}';
      final action = ActionDefinition(
        name: actionName,
        description: 'Deliver message to ${waypoint.name}',
        openingGreeting: message,
        source: 'controller',
      );

      // Save action first (syncs to ROS and millie_ai)
      rosBridge.publishSaveAction(action);
      debugPrint('📤 [deliver_message] Saved action: $actionName');

      // Wait for action to be saved (same delay as millie_ai)
      await Future.delayed(const Duration(milliseconds: 100));

      // Create workflow: navigate then execute the action
      final steps = [
        {'type': 'navigate', 'value': waypoint.name},
        {'type': 'action', 'value': actionName},
      ];

      rosBridge.publishWorkflow(steps);
      debugPrint('✅ [deliver_message] Published workflow: navigate to ${waypoint.name}, then action');
    } catch (e, stack) {
      debugPrint('❌ [deliver_message] ERROR: $e');
      debugPrint('$stack');
    }
  }

  /// Build system prompt with current context
  String buildSystemPrompt() {
    final waypointList = waypoints.isNotEmpty 
        ? waypoints.map((w) => w.name).join(', ')
        : 'none saved yet';
    
    final routeList = routes.isNotEmpty
        ? routes.map((r) => '${r.name} (${r.waypointNames.join(' → ')})').join('; ')
        : 'none saved yet';
    
    return '''You are Millie, a friendly robot assistant controlled remotely via this chat interface.

AVAILABLE WAYPOINTS: $waypointList
SAVED ROUTES: $routeList

RULES:
1. Act immediately - don't ask clarifying questions. Use the information given.
2. If a location is mentioned, match it to a waypoint (case-insensitive, partial match OK).
3. For deliver_message, craft a complete greeting with the person's name.
4. Be brief in responses. Just confirm what you're doing.

TOOLS:
- navigate_to_waypoint: "Go to tom" → navigates to the "tom" waypoint
- deliver_message: "Tell Tom meeting at 4" → destination: "tom", message: "Hi Tom! Meeting at 4 o'clock."
- say_message: "Say hello" (speaks immediately where robot is)
- follow_user / stop_following: "Follow me" / "Stay here"
- approach_user: "Come here"
- watch_user / stop_watching: "Watch me" / "Look away"
- go_away / come_back: "Go away" / "Come back"
- move_robot: "Turn left", "Go forward", "Back up"
- stop_robot: "Stop"

IMPORTANT: For deliver_message, the destination MUST be one of the AVAILABLE WAYPOINTS listed above. Match the person's name to a waypoint name.''';
  }
}

