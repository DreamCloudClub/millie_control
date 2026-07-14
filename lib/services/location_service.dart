import '../utils/rosbridge.dart';

/// Service to track robot's current location
/// Tracks last arrived waypoint and current pose
class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  RosBridge? _rosBridge;
  
  // Last waypoint the robot arrived at
  String? _lastWaypointName;
  
  // Current robot pose
  RobotPose? _currentPose;
  
  // All known waypoints (for proximity matching)
  List<Waypoint> _waypoints = [];
  
  // Navigation state
  bool _isNavigating = false;
  String? _targetWaypointName;

  /// Initialize with RosBridge connection
  void init(RosBridge rosBridge) {
    _rosBridge = rosBridge;
    _setupListeners();
  }

  void _setupListeners() {
    if (_rosBridge == null) return;

    // Listen for pose updates
    _rosBridge!.onPoseUpdate = (pose) {
      _currentPose = pose;
    };

    // Listen for waypoints list
    _rosBridge!.onWaypointsUpdate = (waypoints) {
      _waypoints = waypoints;
    };

    // Listen for navigation status
    _rosBridge!.onNavStatusUpdate = (status) {
      if (status == NavStatus.succeeded && _targetWaypointName != null) {
        // Robot arrived at destination
        _lastWaypointName = _targetWaypointName;
        _isNavigating = false;
        _targetWaypointName = null;
      } else if (status == NavStatus.executing) {
        _isNavigating = true;
      } else if (status == NavStatus.canceled || status == NavStatus.failed) {
        _isNavigating = false;
        _targetWaypointName = null;
      }
    };
  }

  /// Call when starting navigation to a waypoint
  void setNavigatingTo(String waypointName) {
    _targetWaypointName = waypointName;
    _isNavigating = true;
  }

  /// Get current location name
  /// Returns waypoint name if at a waypoint, or null if unknown
  String? get currentLocationName {
    // If at a known waypoint, return its name
    if (_lastWaypointName != null) {
      return _lastWaypointName;
    }

    // Try to find nearest waypoint by proximity
    if (_currentPose != null && _waypoints.isNotEmpty) {
      final nearest = _findNearestWaypoint(_currentPose!);
      if (nearest != null) {
        return nearest.name;
      }
    }

    return null;
  }

  /// Get current robot pose
  RobotPose? get currentPose => _currentPose;

  /// Check if robot is currently navigating
  bool get isNavigating => _isNavigating;

  /// Get list of known waypoints
  List<Waypoint> get waypoints => _waypoints;

  /// Find nearest waypoint within threshold
  Waypoint? _findNearestWaypoint(RobotPose pose, {double threshold = 1.0}) {
    Waypoint? nearest;
    double minDist = threshold;

    for (final wp in _waypoints) {
      final dx = wp.x - pose.x;
      final dy = wp.y - pose.y;
      final dist = (dx * dx + dy * dy);
      if (dist < minDist * minDist) {
        minDist = dist;
        nearest = wp;
      }
    }

    return nearest;
  }

  /// Manually set current location (for testing or manual override)
  void setCurrentLocation(String waypointName) {
    _lastWaypointName = waypointName;
  }

  /// Clear current location
  void clearCurrentLocation() {
    _lastWaypointName = null;
  }
}

