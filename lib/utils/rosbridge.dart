// lib/utils/rosbridge.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/ticket.dart';

/// Robot pose in map coordinates
class RobotPose {
  final double x;
  final double y;
  final double theta; // yaw in radians
  
  RobotPose({required this.x, required this.y, required this.theta});
}

/// Waypoint with name and pose
class Waypoint {
  final String name;
  final double x;
  final double y;
  final double theta;
  final bool isDefault;  // Default waypoint = home location
  
  Waypoint({
    required this.name,
    required this.x,
    required this.y,
    this.theta = 0.0,
    this.isDefault = false,
  });
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'x': x,
    'y': y,
    'theta': theta,
    'is_default': isDefault,
  };
  
  factory Waypoint.fromJson(Map<String, dynamic> json) => Waypoint(
    name: json['name'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    theta: (json['theta'] as num?)?.toDouble() ?? 0.0,
    isDefault: json['is_default'] as bool? ?? false,
  );
  
  Waypoint copyWith({
    String? name,
    double? x,
    double? y,
    double? theta,
    bool? isDefault,
  }) => Waypoint(
    name: name ?? this.name,
    x: x ?? this.x,
    y: y ?? this.y,
    theta: theta ?? this.theta,
    isDefault: isDefault ?? this.isDefault,
  );
}

/// Navigation status
enum NavStatus {
  idle,       // No active goal
  executing,  // Goal in progress
  succeeded,  // Goal reached!
  canceled,   // Goal was canceled
  failed,     // Goal failed
}

/// Laser scan data
class LaserScan {
  final double angleMin;
  final double angleMax;
  final double angleIncrement;
  final List<double> ranges;
  
  LaserScan({
    required this.angleMin,
    required this.angleMax,
    required this.angleIncrement,
    required this.ranges,
  });
}

/// Occupancy grid map data
class MapData {
  final int width;
  final int height;
  final double resolution;  // meters per pixel
  final double originX;     // world X of map origin
  final double originY;     // world Y of map origin
  final List<int> data;     // -1 = unknown, 0 = free, 100 = occupied
  
  MapData({
    required this.width,
    required this.height,
    required this.resolution,
    required this.originX,
    required this.originY,
    required this.data,
  });
}

/// Saved navigation sequence
class SavedSequence {
  final String name;
  final List<String> waypointNames;
  
  SavedSequence({required this.name, required this.waypointNames});
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'waypoints': waypointNames,
  };
  
  factory SavedSequence.fromJson(Map<String, dynamic> json) => SavedSequence(
    name: json['name'] as String,
    waypointNames: List<String>.from(json['waypoints'] as List),
  );
}

/// A single step in a conversation flow
class ConversationStep {
  final String type;     // 'question', 'statement'
  final String content;  // The text to say/ask
  final bool required;   // Must this step happen?
  
  ConversationStep({
    required this.type,
    required this.content,
    this.required = true,
  });
  
  Map<String, dynamic> toJson() => {
    'type': type,
    'content': content,
    'required': required,
  };
  
  factory ConversationStep.fromJson(Map<String, dynamic> json) => ConversationStep(
    type: json['type'] as String? ?? 'question',
    content: json['content'] as String? ?? '',
    required: json['required'] as bool? ?? true,
  );
  
  ConversationStep copyWith({String? type, String? content, bool? required}) =>
    ConversationStep(
      type: type ?? this.type,
      content: content ?? this.content,
      required: required ?? this.required,
    );
}

/// Action definition (prompt configuration for AI conversations)
class ActionDefinition {
  final String name;
  final String description;
  final String agentName;          // Reference to AI Agent template
  final String context;            // Additional context for this action
  final String systemInstructions; // AI behavior rules
  final String openingGreeting;    // What the robot says first
  final List<ConversationStep> steps;  // Follow-up questions/statements
  final String confirmation;       // Closing/confirmation statement
  final bool isDefault;            // Default action for wake word / play button
  
  ActionDefinition({
    required this.name,
    this.description = '',
    this.agentName = '',
    this.context = '',
    this.systemInstructions = '',
    this.openingGreeting = '',
    this.steps = const [],
    this.confirmation = '',
    this.isDefault = false,
  });
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'agent_name': agentName,
    'context': context,
    'system_instructions': systemInstructions,
    'opening_greeting': openingGreeting,
    'steps': steps.map((s) => s.toJson()).toList(),
    'confirmation': confirmation,
    'is_default': isDefault,
  };
  
  factory ActionDefinition.fromJson(Map<String, dynamic> json) => ActionDefinition(
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    agentName: json['agent_name'] as String? ?? '',
    context: json['context'] as String? ?? '',
    systemInstructions: json['system_instructions'] as String? ?? json['opening_prompt'] as String? ?? '',
    openingGreeting: json['opening_greeting'] as String? ?? '',
    steps: (json['steps'] as List<dynamic>?)
        ?.map((s) => ConversationStep.fromJson(s as Map<String, dynamic>))
        .toList() ?? [],
    confirmation: json['confirmation'] as String? ?? '',
    isDefault: json['is_default'] as bool? ?? false,
  );
  
  ActionDefinition copyWith({
    String? name,
    String? description,
    String? agentName,
    String? context,
    String? systemInstructions,
    String? openingGreeting,
    List<ConversationStep>? steps,
    String? confirmation,
    bool? isDefault,
  }) => ActionDefinition(
    name: name ?? this.name,
    description: description ?? this.description,
    agentName: agentName ?? this.agentName,
    context: context ?? this.context,
    systemInstructions: systemInstructions ?? this.systemInstructions,
    openingGreeting: openingGreeting ?? this.openingGreeting,
    steps: steps ?? this.steps,
    confirmation: confirmation ?? this.confirmation,
    isDefault: isDefault ?? this.isDefault,
  );
}

/// Daily hours for company info
class DailyHoursData {
  final String day;
  final String? openTime;
  final String? closeTime;
  final bool isClosed;
  
  DailyHoursData({
    required this.day,
    this.openTime,
    this.closeTime,
    this.isClosed = false,
  });
  
  Map<String, dynamic> toJson() => {
    'day': day,
    'open_time': openTime,
    'close_time': closeTime,
    'is_closed': isClosed,
  };
  
  factory DailyHoursData.fromJson(Map<String, dynamic> json) => DailyHoursData(
    day: json['day'] as String,
    openTime: json['open_time'] as String?,
    closeTime: json['close_time'] as String?,
    isClosed: json['is_closed'] as bool? ?? false,
  );
}

/// Company policy
class PolicyData {
  final String title;
  final String description;
  
  PolicyData({
    required this.title,
    this.description = '',
  });
  
  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
  };
  
  factory PolicyData.fromJson(Map<String, dynamic> json) => PolicyData(
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
  );
}

/// AI Agent definition (reusable persona template)
class AgentDefinition {
  final String name;
  final String description;
  final String systemInstructions;
  final String personality;
  final String voiceStyle;
  final String knowledgeFocus;
  final bool isDefault;
  
  AgentDefinition({
    required this.name,
    this.description = '',
    this.systemInstructions = '',
    this.personality = '',
    this.voiceStyle = '',
    this.knowledgeFocus = '',
    this.isDefault = false,
  });
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'system_instructions': systemInstructions,
    'personality': personality,
    'voice_style': voiceStyle,
    'knowledge_focus': knowledgeFocus,
    'is_default': isDefault,
  };
  
  factory AgentDefinition.fromJson(Map<String, dynamic> json) => AgentDefinition(
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    systemInstructions: json['system_instructions'] as String? ?? '',
    personality: json['personality'] as String? ?? '',
    voiceStyle: json['voice_style'] as String? ?? '',
    knowledgeFocus: json['knowledge_focus'] as String? ?? '',
    isDefault: json['is_default'] as bool? ?? false,
  );
  
  AgentDefinition copyWith({
    String? name,
    String? description,
    String? systemInstructions,
    String? personality,
    String? voiceStyle,
    String? knowledgeFocus,
    bool? isDefault,
  }) => AgentDefinition(
    name: name ?? this.name,
    description: description ?? this.description,
    systemInstructions: systemInstructions ?? this.systemInstructions,
    personality: personality ?? this.personality,
    voiceStyle: voiceStyle ?? this.voiceStyle,
    knowledgeFocus: knowledgeFocus ?? this.knowledgeFocus,
    isDefault: isDefault ?? this.isDefault,
  );
}

/// Company info data from robot
class CompanyInfoData {
  // Robot identity
  final String robotName;
  final String robotIdentity;
  final String basePersonality;
  final String baseSystemInstructions;
  final String voice;
  
  // Business info
  final String companyName;
  final String address;
  final String phone;
  final List<DailyHoursData> hours;
  final List<PolicyData> policies;
  
  CompanyInfoData({
    this.robotName = '',
    this.robotIdentity = '',
    this.basePersonality = '',
    this.baseSystemInstructions = '',
    this.voice = 'nova',
    this.companyName = '',
    this.address = '',
    this.phone = '',
    this.hours = const [],
    this.policies = const [],
  });
  
  bool get isEmpty => robotName.isEmpty && companyName.isEmpty && address.isEmpty && phone.isEmpty && 
      hours.isEmpty && policies.isEmpty;
  
  Map<String, dynamic> toJson() => {
    'robot_name': robotName,
    'robot_identity': robotIdentity,
    'base_personality': basePersonality,
    'base_system_instructions': baseSystemInstructions,
    'voice': voice,
    'company_name': companyName,
    'address': address,
    'phone': phone,
    'hours': hours.map((h) => h.toJson()).toList(),
    'policies': policies.map((p) => p.toJson()).toList(),
  };
  
  factory CompanyInfoData.fromJson(Map<String, dynamic> json) => CompanyInfoData(
    robotName: json['robot_name'] as String? ?? '',
    robotIdentity: json['robot_identity'] as String? ?? '',
    basePersonality: json['base_personality'] as String? ?? '',
    baseSystemInstructions: json['base_system_instructions'] as String? ?? '',
    voice: json['voice'] as String? ?? 'nova',
    companyName: json['company_name'] as String? ?? '',
    address: json['address'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    hours: (json['hours'] as List<dynamic>?)
        ?.map((h) => DailyHoursData.fromJson(h as Map<String, dynamic>))
        .toList() ?? [],
    policies: (json['policies'] as List<dynamic>?)
        ?.map((p) => PolicyData.fromJson(p as Map<String, dynamic>))
        .toList() ?? [],
  );
}

class RosBridge {
  final String url;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  
  // ============================================================
  // CENTRAL DATA STORAGE (Source of Truth)
  // ============================================================
  List<Waypoint> waypoints = [];
  List<SavedSequence> sequences = [];
  List<ActionDefinition> actions = [];
  List<AgentDefinition> agents = [];
  CompanyInfoData? companyInfo;
  RobotPose? currentPose;
  
  // ============================================================
  // MULTI-LISTENER PATTERN (New - supports multiple consumers)
  // ============================================================
  final List<void Function(List<Waypoint>)> _waypointListeners = [];
  final List<void Function(List<SavedSequence>)> _sequenceListeners = [];
  final List<void Function(List<ActionDefinition>)> _actionListeners = [];
  final List<void Function(List<AgentDefinition>)> _agentListeners = [];
  final List<void Function(RobotPose)> _poseListeners = [];
  final List<void Function(MapData)> _mapListeners = [];
  final List<void Function(NavStatus)> _navStatusListeners = [];
  final List<void Function(LaserScan)> _laserScanListeners = [];
  final List<void Function(List<Map<String, dynamic>>)> _ticketListeners = [];
  LaserScan? _currentLaserScan;
  final List<void Function(CompanyInfoData)> _companyInfoListeners = [];
  final List<void Function(String, int, int, List<Map<String, dynamic>>?)> _workflowStatusListeners = [];
  
  /// Add a waypoint listener. Receives current data immediately if available.
  void addWaypointListener(void Function(List<Waypoint>) callback) {
    _waypointListeners.add(callback);
    if (waypoints.isNotEmpty) {
      print('📍 [MultiListener] New waypoint listener, sending ${waypoints.length} cached waypoints');
      callback(waypoints);
    }
  }
  
  void removeWaypointListener(void Function(List<Waypoint>) callback) {
    _waypointListeners.remove(callback);
  }
  
  /// Add a sequence listener. Receives current data immediately if available.
  void addSequenceListener(void Function(List<SavedSequence>) callback) {
    _sequenceListeners.add(callback);
    if (sequences.isNotEmpty) {
      print('📍 [MultiListener] New sequence listener, sending ${sequences.length} cached sequences');
      callback(sequences);
    }
  }
  
  void removeSequenceListener(void Function(List<SavedSequence>) callback) {
    _sequenceListeners.remove(callback);
  }
  
  /// Add an action listener. Receives current data immediately if available.
  void addActionListener(void Function(List<ActionDefinition>) callback) {
    _actionListeners.add(callback);
    if (actions.isNotEmpty) {
      print('📍 [MultiListener] New action listener, sending ${actions.length} cached actions');
      callback(actions);
    }
  }
  
  void removeActionListener(void Function(List<ActionDefinition>) callback) {
    _actionListeners.remove(callback);
  }
  
  /// Add an agent listener. Receives current data immediately if available.
  void addAgentListener(void Function(List<AgentDefinition>) callback) {
    _agentListeners.add(callback);
    if (agents.isNotEmpty) {
      print('📍 [MultiListener] New agent listener, sending ${agents.length} cached agents');
      callback(agents);
    }
  }
  
  void removeAgentListener(void Function(List<AgentDefinition>) callback) {
    _agentListeners.remove(callback);
  }
  
  /// Add a pose listener. Receives current pose immediately if available.
  void addPoseListener(void Function(RobotPose) callback) {
    _poseListeners.add(callback);
    if (currentPose != null) {
      callback(currentPose!);
    }
  }
  
  void removePoseListener(void Function(RobotPose) callback) {
    _poseListeners.remove(callback);
  }
  
  /// Add a map listener. Receives cached map immediately if available.
  void addMapListener(void Function(MapData) callback) {
    _mapListeners.add(callback);
    if (_cachedMapData != null) {
      print('📍 [MultiListener] New map listener, sending cached map ${_cachedMapData!.width}x${_cachedMapData!.height}');
      callback(_cachedMapData!);
    }
  }
  
  void removeMapListener(void Function(MapData) callback) {
    _mapListeners.remove(callback);
  }
  
  /// Direct access to cached map data
  MapData? get mapData => _cachedMapData;
  
  /// Add a nav status listener.
  void addNavStatusListener(void Function(NavStatus) callback) {
    _navStatusListeners.add(callback);
  }
  
  void removeNavStatusListener(void Function(NavStatus) callback) {
    _navStatusListeners.remove(callback);
  }
  
  /// Add a ticket listener.
  void addTicketListener(void Function(List<Map<String, dynamic>>) callback) {
    _ticketListeners.add(callback);
  }
  
  void removeTicketListener(void Function(List<Map<String, dynamic>>) callback) {
    _ticketListeners.remove(callback);
  }
  
  /// Direct access to current nav status
  NavStatus get currentNavStatus => _lastNavStatus;
  
  /// Add a laser scan listener.
  void addLaserScanListener(void Function(LaserScan) callback) {
    _laserScanListeners.add(callback);
    if (_currentLaserScan != null) {
      callback(_currentLaserScan!);
    }
  }
  
  void removeLaserScanListener(void Function(LaserScan) callback) {
    _laserScanListeners.remove(callback);
  }
  
  /// Direct access to current laser scan
  LaserScan? get laserScan => _currentLaserScan;
  
  /// Add a company info listener. Receives current data immediately if available.
  void addCompanyInfoListener(void Function(CompanyInfoData) callback) {
    _companyInfoListeners.add(callback);
    if (companyInfo != null) {
      print('📍 [MultiListener] New company info listener, sending cached data');
      callback(companyInfo!);
    }
  }
  
  void removeCompanyInfoListener(void Function(CompanyInfoData) callback) {
    _companyInfoListeners.remove(callback);
  }
  
  /// Add a workflow status listener.
  void addWorkflowStatusListener(void Function(String, int, int, List<Map<String, dynamic>>?) callback) {
    _workflowStatusListeners.add(callback);
  }
  
  void removeWorkflowStatusListener(void Function(String, int, int, List<Map<String, dynamic>>?) callback) {
    _workflowStatusListeners.remove(callback);
  }
  
  // ============================================================
  // LEGACY SINGLE CALLBACKS (Still work - for backward compatibility)
  // ============================================================
  void Function(RobotPose)? onPoseUpdate;
  void Function(List<Waypoint>)? onWaypointsUpdate;
  void Function(bool)? onConnectionChange;
  void Function(NavStatus)? onNavStatusUpdate;
  void Function(String status, int step, int total, List<Map<String, dynamic>>? steps)? onWorkflowStatus;
  void Function(LaserScan)? onLaserScanUpdate;
  void Function(List<SavedSequence>)? onSequencesUpdate;
  void Function(List<ActionDefinition>)? onActionsUpdate;
  void Function(CompanyInfoData)? onCompanyInfoUpdate;
  void Function(List<AgentDefinition>)? onAgentsUpdate;
  
  // Map callback with caching (map is latched, only sent once)
  MapData? _cachedMapData;
  void Function(MapData)? _onMapUpdate;
  
  set onMapUpdate(void Function(MapData)? callback) {
    _onMapUpdate = callback;
    // If we already have cached map data, send it immediately
    if (callback != null && _cachedMapData != null) {
      print("📦 Sending cached map data to new listener");
      callback(_cachedMapData!);
    }
  }
  
  void Function(MapData)? get onMapUpdate => _onMapUpdate;
  
  bool _connected = false;
  bool get isConnected => _connected;

  RosBridge(this.url);

  void connect() {
    // Cancel any existing reconnect timer
    _reconnectTimer?.cancel();
    
    // Close existing connection if any
    _subscription?.cancel();
    try { _channel?.sink.close(); } catch (_) {}
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      print("✅ Connected to ROSBridge at $url");
      _connected = true;
      onConnectionChange?.call(true);
      
      // Listen for incoming messages
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (e) {
          print("❌ ROSBridge error: $e");
          _handleDisconnect();
        },
        onDone: () {
          print("👋 ROSBridge connection closed");
          _handleDisconnect();
        },
      );
      
      // Subscribe to robot pose (slam_toolbox publishes to /pose)
      _subscribe('/pose', 'geometry_msgs/msg/PoseWithCovarianceStamped');
      
      // Subscribe to waypoints list
      _subscribe('/millie/waypoints', 'std_msgs/msg/String');
      
      // Subscribe to sequences list
      _subscribe('/millie/sequences', 'std_msgs/msg/String');
      
      // Subscribe to actions list
      _subscribe('/millie/actions', 'std_msgs/msg/String');
      
      // Subscribe to tickets list
      _subscribe('/millie/tickets', 'std_msgs/msg/String');
      
      // Subscribe to company info
      _subscribe('/millie/company_info', 'std_msgs/msg/String');
      
      // Subscribe to AI agents
      _subscribe('/millie/agents', 'std_msgs/msg/String');
      
      // Subscribe to workflow status
      _subscribe('/millie/workflow/status', 'std_msgs/msg/String');
      
      // Subscribe to map with TRANSIENT_LOCAL QoS to receive latched map
      _subscribeWithQos('/map', 'nav_msgs/msg/OccupancyGrid', durability: 'transient_local');
      
      // Subscribe to Nav2 action status for navigation complete notifications
      _subscribe('/navigate_to_pose/_action/status', 'action_msgs/msg/GoalStatusArray');
      
      // Laser scan disabled - needs TF sync for proper display
      // _subscribeThrottled('/scan_filtered', 'sensor_msgs/msg/LaserScan', 500);
      
    } catch (e) {
      print("❌ Failed to connect to ROSBridge: $e");
      _handleDisconnect();
    }
  }
  
  void _handleDisconnect() {
    if (!_connected) return; // Already disconnected
    _connected = false;
    onConnectionChange?.call(false);
    _scheduleReconnect();
  }
  
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      print("🔄 Attempting to reconnect to ROSBridge...");
      connect();
    });
  }
  
  void _subscribe(String topic, String type) {
    if (_channel == null) return;
    
    final msg = {
      "op": "subscribe",
      "topic": topic,
      "type": type,
    };
    _channel!.sink.add(jsonEncode(msg));
    print("📡 Subscribed to $topic");
  }
  
  void _subscribeThrottled(String topic, String type, int throttleRateMs) {
    if (_channel == null) return;
    
    final msg = {
      "op": "subscribe",
      "topic": topic,
      "type": type,
      "throttle_rate": throttleRateMs,  // Limit message rate
    };
    _channel!.sink.add(jsonEncode(msg));
    print("📡 Subscribed to $topic (throttled: ${throttleRateMs}ms)");
  }
  
  void _subscribeWithQos(String topic, String type, {String? durability, int? throttleRateMs}) {
    if (_channel == null) return;
    
    final msg = <String, dynamic>{
      "op": "subscribe",
      "topic": topic,
      "type": type,
    };
    
    // Add QoS settings if specified
    if (durability != null) {
      msg["qos"] = {"durability": durability};
    }
    
    if (throttleRateMs != null) {
      msg["throttle_rate"] = throttleRateMs;
    }
    
    _channel!.sink.add(jsonEncode(msg));
    print("📡 Subscribed to $topic (durability: $durability)");
  }
  
  void _handleMessage(dynamic data) {
    try {
      final msg = jsonDecode(data);
      
      if (msg['op'] == 'publish') {
        final topic = msg['topic'];
        
        if (topic == '/pose') {
          _handlePoseMessage(msg['msg']);
        } else if (topic == '/millie/waypoints') {
          _handleWaypointsMessage(msg['msg']);
        } else if (topic == '/millie/sequences') {
          _handleSequencesMessage(msg['msg']);
        } else if (topic == '/millie/actions') {
          _handleActionsMessage(msg['msg']);
        } else if (topic == '/millie/tickets') {
          _handleTicketsMessage(msg['msg']);
        } else if (topic == '/millie/company_info') {
          _handleCompanyInfoMessage(msg['msg']);
        } else if (topic == '/millie/agents') {
          _handleAgentsMessage(msg['msg']);
        } else if (topic == '/millie/workflow/status') {
          _handleWorkflowStatusMessage(msg['msg']);
        } else if (topic == '/map') {
          _handleMapMessage(msg['msg']);
        } else if (topic == '/navigate_to_pose/_action/status') {
          _handleNavStatusMessage(msg['msg']);
        } else if (topic == '/scan_filtered') {
          _handleLaserScanMessage(msg['msg']);
        }
      }
    } catch (e) {
      print("⚠️ Error parsing message: $e");
    }
  }
  
  void _handlePoseMessage(Map<String, dynamic> msg) {
    try {
      final pose = msg['pose']['pose'];
      final position = pose['position'];
      final orientation = pose['orientation'];
      
      // Convert quaternion to yaw
      final double qz = orientation['z'];
      final double qw = orientation['w'];
      final double theta = 2.0 * _atan2(qz, qw);
      
      final robotPose = RobotPose(
        x: position['x'].toDouble(),
        y: position['y'].toDouble(),
        theta: theta,
      );
      
      // Store in central storage
      currentPose = robotPose;
      
      // Notify multi-listeners
      for (final listener in _poseListeners) {
        listener(robotPose);
      }
      
      // Legacy callback (backward compatibility)
      onPoseUpdate?.call(robotPose);
    } catch (e) {
      print("⚠️ Error parsing pose: $e");
    }
  }
  
  double _atan2(double y, double x) {
    // Simple atan2 implementation
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.14159;
    if (x < 0 && y < 0) return _atan(y / x) - 3.14159;
    if (x == 0 && y > 0) return 3.14159 / 2;
    if (x == 0 && y < 0) return -3.14159 / 2;
    return 0;
  }
  
  double _atan(double x) {
    // Taylor series approximation for small values
    return x - (x * x * x) / 3 + (x * x * x * x * x) / 5;
  }
  
  void _handleWorkflowStatusMessage(Map<String, dynamic> msg) {
    try {
      final data = jsonDecode(msg['data']);
      final status = data['status'] as String? ?? 'unknown';
      final step = data['step'] as int? ?? 0;
      final total = data['total'] as int? ?? 0;
      
      // Parse workflow steps if included (sent when status is 'started')
      List<Map<String, dynamic>>? steps;
      if (data['steps'] != null) {
        steps = (data['steps'] as List).map((s) => Map<String, dynamic>.from(s)).toList();
      }
      
      print('📋 [RosBridge] Workflow status: $status ($step/$total), notifying ${_workflowStatusListeners.length} listeners');
      
      // Notify multi-listeners
      for (final listener in _workflowStatusListeners) {
        listener(status, step, total, steps);
      }
      
      // Legacy callback (backward compatibility)
      onWorkflowStatus?.call(status, step, total, steps);
    } catch (e) {
      print("⚠️ Error parsing workflow status: $e");
    }
  }

  void _handleWaypointsMessage(Map<String, dynamic> msg) {
    try {
      final data = jsonDecode(msg['data']);
      final parsedWaypoints = (data['waypoints'] as List)
          .map((w) => Waypoint.fromJson(w as Map<String, dynamic>))
          .toList();
      
      // Sort so default waypoint appears first
      parsedWaypoints.sort((a, b) {
        if (a.isDefault && !b.isDefault) return -1;
        if (!a.isDefault && b.isDefault) return 1;
        return 0;
      });
      
      // Store in central storage
      waypoints = parsedWaypoints;
      
      print('📍 [RosBridge] Waypoints updated: ${waypoints.length} points, notifying ${_waypointListeners.length} listeners');
      
      // Notify multi-listeners
      for (final listener in _waypointListeners) {
        listener(waypoints);
      }
      
      // Legacy callback (backward compatibility)
      onWaypointsUpdate?.call(waypoints);
    } catch (e) {
      print("⚠️ Error parsing waypoints: $e");
    }
  }
  
  void _handleSequencesMessage(Map<String, dynamic> msg) {
    try {
      final data = jsonDecode(msg['data']);
      final parsedSequences = (data['sequences'] as List).map((s) => SavedSequence(
        name: s['name'] as String,
        waypointNames: List<String>.from(s['waypoints'] as List),
      )).toList();
      
      // Store in central storage
      sequences = parsedSequences;
      print('📍 [RosBridge] Sequences updated: ${sequences.length} tasks, notifying ${_sequenceListeners.length} listeners');
      
      // Notify multi-listeners
      for (final listener in _sequenceListeners) {
        listener(sequences);
      }
      
      // Legacy callback (backward compatibility)
      onSequencesUpdate?.call(sequences);
    } catch (e) {
      print("⚠️ Error parsing sequences: $e");
    }
  }
  
  void _handleActionsMessage(Map<String, dynamic> msg) {
    try {
      final data = jsonDecode(msg['data']);
      final parsedActions = (data['actions'] as List)
          .map((a) => ActionDefinition.fromJson(a as Map<String, dynamic>))
          .toList();
      
      // Store in central storage
      actions = parsedActions;
      print('📍 [RosBridge] Actions updated: ${actions.length} actions, notifying ${_actionListeners.length} listeners');
      
      // Notify multi-listeners
      for (final listener in _actionListeners) {
        listener(actions);
      }
      
      // Legacy callback (backward compatibility)
      onActionsUpdate?.call(actions);
    } catch (e) {
      print("⚠️ Error parsing actions: $e");
    }
  }
  
  void _handleTicketsMessage(Map<String, dynamic> msg) {
    try {
      final data = jsonDecode(msg['data']);
      final tickets = (data['tickets'] as List)
          .map((t) => t as Map<String, dynamic>)
          .toList();
      
      // Notify all ticket listeners
      for (final listener in _ticketListeners) {
        listener(tickets);
      }
    } catch (e) {
      print("⚠️ Error parsing tickets: $e");
    }
  }
  
  void _handleCompanyInfoMessage(Map<String, dynamic> msg) {
    try {
      final data = jsonDecode(msg['data']);
      final info = data['company_info'] as Map<String, dynamic>?;
      if (info != null) {
        // Store in central storage
        companyInfo = CompanyInfoData.fromJson(info);
        print('📍 [RosBridge] Company info updated: ${companyInfo?.companyName}, notifying ${_companyInfoListeners.length} listeners');
        
        // Notify multi-listeners
        for (final listener in _companyInfoListeners) {
          listener(companyInfo!);
        }
        
        // Legacy callback (backward compatibility)
        onCompanyInfoUpdate?.call(companyInfo!);
      }
    } catch (e) {
      print("⚠️ Error parsing company info: $e");
    }
  }
  
  void _handleAgentsMessage(Map<String, dynamic> msg) {
    try {
      final data = jsonDecode(msg['data']);
      final parsedAgents = (data['agents'] as List)
          .map((a) => AgentDefinition.fromJson(a as Map<String, dynamic>))
          .toList();
      
      // Store in central storage
      agents = parsedAgents;
      print('📍 [RosBridge] Agents updated: ${agents.length} agents');
      
      // Notify multi-listeners (if we add them later)
      for (final listener in _agentListeners) {
        listener(agents);
      }
      
      // Legacy callback (backward compatibility)
      onAgentsUpdate?.call(agents);
    } catch (e) {
      print("⚠️ Error parsing agents: $e");
    }
  }
  
  void _handleLaserScanMessage(Map<String, dynamic> msg) {
    try {
      final angleMin = (msg['angle_min'] as num?)?.toDouble() ?? -3.14;
      final angleMax = (msg['angle_max'] as num?)?.toDouble() ?? 3.14;
      final angleIncrement = (msg['angle_increment'] as num?)?.toDouble() ?? 0.01;
      final rawRanges = msg['ranges'] as List?;
      
      if (rawRanges == null || rawRanges.isEmpty) return;
      
      final ranges = <double>[];
      for (final r in rawRanges) {
        if (r == null) {
          ranges.add(0.0);
        } else {
          final val = (r as num).toDouble();
          // Filter out inf/nan values
          if (val.isInfinite || val.isNaN || val > 10.0) {
            ranges.add(0.0);
          } else {
            ranges.add(val);
          }
        }
      }
      
      final scan = LaserScan(
        angleMin: angleMin,
        angleMax: angleMax,
        angleIncrement: angleIncrement,
        ranges: ranges,
      );
      
      // Store in central storage
      _currentLaserScan = scan;
      
      // Notify multi-listeners
      for (final listener in _laserScanListeners) {
        listener(scan);
      }
      
      // Legacy callback (backward compatibility)
      onLaserScanUpdate?.call(scan);
    } catch (e) {
      print("⚠️ Laser scan parse error: $e");
    }
  }

  void _handleMapMessage(Map<String, dynamic> msg) {
    try {
      final info = msg['info'];
      if (info == null) return;
      
      final width = info['width'] as int;
      final height = info['height'] as int;
      final resolution = (info['resolution'] as num).toDouble();
      final origin = info['origin']['position'];
      final originX = (origin['x'] as num).toDouble();
      final originY = (origin['y'] as num).toDouble();
      
      final rawData = msg['data'] as List?;
      if (rawData == null) return;
      
      final data = rawData.map((e) => (e as num).toInt()).toList();
      
      final mapData = MapData(
        width: width,
        height: height,
        resolution: resolution,
        originX: originX,
        originY: originY,
        data: data,
      );
      
      // Store in central storage
      _cachedMapData = mapData;
      
      print("🗺️ Map received: ${width}x${height}, notifying ${_mapListeners.length} listeners");
      
      // Notify multi-listeners
      for (final listener in _mapListeners) {
        listener(mapData);
      }
      
      // Legacy callback (backward compatibility)
      _onMapUpdate?.call(mapData);
    } catch (e) {
      print("⚠️ Error parsing map: $e");
    }
  }
  
  // Track last known status to only fire on changes
  NavStatus _lastNavStatus = NavStatus.idle;
  
  void _handleNavStatusMessage(Map<String, dynamic> msg) {
    try {
      final statusList = msg['status_list'] as List?;
      if (statusList == null || statusList.isEmpty) {
        // No active goals = idle
        if (_lastNavStatus != NavStatus.idle) {
          _lastNavStatus = NavStatus.idle;
          // Don't notify on becoming idle (that's just cleanup)
        }
        return;
      }
      
      // Get the most recent goal status (last in list)
      final latestGoal = statusList.last as Map<String, dynamic>;
      final statusCode = latestGoal['status'] as int;
      
      // Nav2 GoalStatus codes:
      // 1 = ACCEPTED, 2 = EXECUTING, 4 = SUCCEEDED, 5 = CANCELED, 6 = ABORTED
      NavStatus newStatus;
      switch (statusCode) {
        case 1:
        case 2:
          newStatus = NavStatus.executing;
          break;
        case 4:
          newStatus = NavStatus.succeeded;
          break;
        case 5:
          newStatus = NavStatus.canceled;
          break;
        case 6:
          newStatus = NavStatus.failed;
          break;
        default:
          newStatus = NavStatus.idle;
      }
      
      // Only notify on meaningful state changes
      if (newStatus != _lastNavStatus && newStatus != NavStatus.executing) {
        print("🎯 Nav status: $newStatus (code: $statusCode), notifying ${_navStatusListeners.length} listeners");
        
        // Notify multi-listeners
        for (final listener in _navStatusListeners) {
          listener(newStatus);
        }
        
        // Legacy callback (backward compatibility)
        onNavStatusUpdate?.call(newStatus);
      }
      _lastNavStatus = newStatus;
    } catch (e) {
      print("⚠️ Error parsing nav status: $e");
    }
  }

  void publishCmdVel(double x, double y) {
    if (_channel == null || !_connected) {
      return; // Silent - joystick sends many messages
    }

    const double maxLin = 0.60;
    const double maxAng = 0.7;

    final double linear = -y * maxLin;
    final double angular = -x * maxAng;

    final msg = {
      "op": "publish",
      "topic": "/cmd_vel",
      "msg": {
        "linear": {"x": linear, "y": 0.0, "z": 0.0},
        "angular": {"x": 0.0, "y": 0.0, "z": angular}
      }
    };

    _channel!.sink.add(jsonEncode(msg));
  }
  
  /// Send a navigation goal to Nav2
  void publishNavGoal(double x, double y, {double theta = 0.0}) {
    if (!_connected || _channel == null) {
      print("⚠️ Not connected to ROSBridge, skipping nav goal");
      return;
    }
    
    // Convert theta to quaternion (rotation around Z axis only)
    final double qz = _sin(theta / 2);
    final double qw = _cos(theta / 2);
    
    final msg = {
      "op": "publish",
      "topic": "/goal_pose",
      "msg": {
        "header": {
          "frame_id": "map",
        },
        "pose": {
          "position": {"x": x, "y": y, "z": 0.0},
          "orientation": {"x": 0.0, "y": 0.0, "z": qz, "w": qw}
        }
      }
    };
    
    print("🎯 Sending nav goal: ($x, $y, θ=$theta)");
    _channel!.sink.add(jsonEncode(msg));
  }
  
  /// Set initial pose estimate (for slam_toolbox localization)
  void publishInitialPose(double x, double y, {double theta = 0.0}) {
    if (!_connected || _channel == null) {
      print("⚠️ Not connected to ROSBridge, skipping initial pose");
      return;
    }
    
    // Convert theta to quaternion
    final double qz = _sin(theta / 2);
    final double qw = _cos(theta / 2);
    
    final msg = {
      "op": "publish",
      "topic": "/initialpose",
      "msg": {
        "header": {
          "frame_id": "map",
        },
        "pose": {
          "pose": {
            "position": {"x": x, "y": y, "z": 0.0},
            "orientation": {"x": 0.0, "y": 0.0, "z": qz, "w": qw}
          },
          "covariance": [0.25, 0.0, 0.0, 0.0, 0.0, 0.0,
                         0.0, 0.25, 0.0, 0.0, 0.0, 0.0,
                         0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                         0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                         0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                         0.0, 0.0, 0.0, 0.0, 0.0, 0.07]
        }
      }
    };
    
    print("📍 Setting initial pose: ($x, $y, θ=$theta)");
    _channel!.sink.add(jsonEncode(msg));
  }

  /// Navigate to a named waypoint
  void publishGoToWaypoint(String waypointName) {
    _publishSimple("/millie/waypoint/goto", waypointName);
  }
  
  /// Navigate through a sequence of waypoints (legacy)
  void publishNavigateSequence(List<String> waypointNames) {
    final sequenceStr = waypointNames.join(',');
    _publishSimple("/millie/waypoint/sequence", sequenceStr);
  }
  
  /// Execute a workflow (navigation + speak steps)
  /// Execute a workflow (navigation + speak steps)
  void publishWorkflow(List<Map<String, String>> steps, {Ticket? ticket}) {
    final Map<String, dynamic> data = {'steps': steps};
    if (ticket != null) {
      data['ticket'] = ticket.toJson();
    }
    final jsonStr = jsonEncode(data);
    _publishSimple("/millie/workflow/execute", jsonStr);
  }
  
  /// Cancel current workflow
  void publishWorkflowCancel() {
    _publishSimple("/millie/workflow/cancel", "cancel");
  }
  
  /// Save current robot position as a waypoint
  void publishSaveWaypoint(String name) {
    _publishSimple("/millie/waypoint/save", name);
  }
  
  /// Delete a waypoint by name
  void publishDeleteWaypoint(String name) {
    _publishSimple("/millie/waypoint/delete", name);
  }
  
  /// Update a waypoint (e.g., to set as default)
  void publishUpdateWaypoint(Waypoint waypoint) {
    final json = jsonEncode(waypoint.toJson());
    _publishSimple("/millie/waypoint/update", json);
  }
  
  /// Request waypoints list refresh
  void requestWaypoints() {
    _publishSimple("/millie/waypoint/list", "request");
  }
  
  /// Request saved sequences from robot
  void requestSequences() {
    _publishSimple("/millie/sequence/list", "request");
  }
  
  /// Save a sequence to the robot
  void publishSaveSequence(String name, List<String> waypointNames) {
    final json = jsonEncode({
      'name': name,
      'waypoints': waypointNames,
    });
    _publishSimple("/millie/sequence/save", json);
  }
  
  /// Delete a sequence from the robot
  void publishDeleteSequence(String name) {
    _publishSimple("/millie/sequence/delete", name);
  }
  
  /// Reorder sequences on the robot
  void publishReorderSequences(List<String> orderedNames) {
    final json = jsonEncode({
      'order': orderedNames,
    });
    _publishSimple("/millie/sequence/reorder", json);
  }
  
  /// Request saved actions from robot
  void requestActions() {
    _publishSimple("/millie/action/list", "request");
  }
  
  /// Save an action to the robot
  void publishSaveAction(ActionDefinition action) {
    final json = jsonEncode(action.toJson());
    _publishSimple("/millie/action/save", json);
  }
  
  /// Delete an action from the robot
  void publishDeleteAction(String name) {
    _publishSimple("/millie/action/delete", name);
  }
  
  /// Execute an action directly on the face tablet (no navigation)
  void publishExecuteAction(ActionDefinition action) {
    final json = jsonEncode(action.toJson());
    _publishSimple("/millie/action/execute", json);
  }
  
  /// Reorder actions on the robot
  void publishReorderActions(List<String> orderedNames) {
    final json = jsonEncode({
      'order': orderedNames,
    });
    _publishSimple("/millie/action/reorder", json);
  }
  
  /// Save company info to the robot
  void publishSaveCompanyInfo(CompanyInfoData info) {
    final json = jsonEncode(info.toJson());
    print("📤 Publishing company info: $json");
    _publishSimple("/millie/company_info/save", json);
  }
  
  /// Request company info from robot
  void requestCompanyInfo() {
    _publishSimple("/millie/company_info/list", "");
  }
  
  /// Save an AI agent to the robot
  void publishSaveAgent(AgentDefinition agent) {
    final json = jsonEncode(agent.toJson());
    print("📤 Publishing agent: $json");
    _publishSimple("/millie/agent/save", json);
  }
  
  /// Delete an AI agent from the robot
  void publishDeleteAgent(String name) {
    _publishSimple("/millie/agent/delete", name);
  }
  
  /// Request AI agents from robot
  void requestAgents() {
    _publishSimple("/millie/agent/list", "");
  }
  
  /// Cancel current navigation - calls Nav2 cancel service directly
  void publishCancelNav() {
    if (!_connected || _channel == null) return;
    
    // Call the Nav2 action cancel service directly via rosbridge
    // UUID of all zeros = cancel ALL active goals
    final cancelMsg = {
      "op": "call_service",
      "service": "/navigate_to_pose/_action/cancel_goal",
      "type": "action_msgs/srv/CancelGoal",
      "args": {
        "goal_info": {
          "goal_id": {"uuid": [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]},
          "stamp": {"sec": 0, "nanosec": 0}
        }
      }
    };
    _channel!.sink.add(jsonEncode(cancelMsg));
    
    print("🛑 Cancelling navigation");
  }
  
  /// Emergency stop - cancel autonomous navigation
  void publishEstop() {
    if (!_connected || _channel == null) {
      print("⚠️ E-STOP FAILED - Not connected to ROSBridge!");
      return;
    }
    
    // Cancel Nav2 navigation via service call
    publishCancelNav();
    
    // Send zero velocity to stop motion immediately
    final stopMsg = {
      "op": "publish",
      "topic": "/cmd_vel",
      "msg": {
        "linear": {"x": 0.0, "y": 0.0, "z": 0.0},
        "angular": {"x": 0.0, "y": 0.0, "z": 0.0}
      }
    };
    _channel!.sink.add(jsonEncode(stopMsg));
    
    print("🛑 E-STOP: Nav cancelled + zero velocity sent");
  }
  
  double _sin(double x) {
    // Taylor series approximation
    return x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  }
  
  double _cos(double x) {
    // Taylor series approximation
    return 1 - (x * x) / 2 + (x * x * x * x) / 24;
  }

  void publishShutdown() {
    _publishSimple("/shutdown", "shutdown");
  }

  void publishWake() {
    _publishSimple("/millie/wake", "wake");
  }

  void publishSleep() {
    _publishSimple("/millie/sleep", "sleep");
  }

  // ✅ new agent publisher helpers
  void publishDefaultAgent() => _publishSimple("/millie/agent", "default");
  void publishGreeterAgent() => _publishSimple("/millie/agent", "greeter");
  void publishBartenderAgent() => _publishSimple("/millie/agent", "bartender");
  void publishHostAgent() => _publishSimple("/millie/agent", "host");

  // ✅ Ticket methods
  /// Request tickets from robot
  void requestTickets() {
    _publishSimple("/millie/ticket/list", "request");
  }
  
  /// Save a ticket to the robot
  void publishSaveTicket(Map<String, dynamic> ticketJson) {
    final json = jsonEncode(ticketJson);
    _publishSimple("/millie/ticket/save", json);
  }
  
  /// Delete a ticket from the robot
  void publishDeleteTicket(String ticketId) {
    _publishSimple("/millie/ticket/delete", ticketId);
  }
  
  /// Clear all tickets on the robot
  void publishClearAllTickets() {
    _publishSimple("/millie/ticket/clear", "all");
  }
  
  /// Update a ticket on the robot
  void publishUpdateTicket(Map<String, dynamic> ticketJson) {
    final json = jsonEncode(ticketJson);
    _publishSimple("/millie/ticket/update", json);
  }

  // ✅ shared helper
  void _publishSimple(String topic, String data) {
    if (_channel == null) {
      print("⚠️ Not connected to ROSBridge, skipping publish for $topic");
      return;
    }
    
    print("🔌 _publishSimple: topic=$topic, connected=$_connected, channel=${_channel != null}");

    final msg = {
      "op": "publish",
      "topic": topic,
      "msg": {"data": data}
    };

    final jsonMsg = jsonEncode(msg);
    print("📤 Sending to $topic: $jsonMsg");
    _channel!.sink.add(jsonMsg);
  }

  void close() {
    try {
      _reconnectTimer?.cancel();
      _subscription?.cancel();
      _channel?.sink.close();
      _connected = false;
      print("👋 Disconnected from ROSBridge");
    } catch (e) {
      print("⚠️ Error closing ROSBridge: $e");
    }
  }
}
