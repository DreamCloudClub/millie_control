// lib/utils/robot_api.dart
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

/// API client for Millie Boot Server
class RobotApi {
  final String baseUrl;
  
  RobotApi(this.baseUrl);
  
  // === Status ===
  
  Future<RobotStatus?> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/status'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return RobotStatus.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      print('❌ Failed to get status: $e');
    }
    return null;
  }
  
  Future<bool> ping() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/ping'),
      ).timeout(const Duration(seconds: 3));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  // === ROS Control ===
  
  Future<ApiResult> startRos({String mode = 'main'}) async {
    return _post('/api/ros/start', {'mode': mode});
  }
  
  Future<ApiResult> stopRos() async {
    return _post('/api/ros/stop', {});
  }
  
  Future<ApiResult> restartRos({String? mode}) async {
    return _post('/api/ros/restart', mode != null ? {'mode': mode} : {});
  }
  
  Future<ApiResult> refreshConfig() async {
    return _post('/api/ros/rebuild', {});
  }
  
  // === Maps ===
  
  Future<MapListResult> listMaps() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/maps'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final maps = (data['maps'] as List)
            .map((m) => MapInfo.fromJson(m))
            .toList();
        return MapListResult(maps: maps, activeMap: data['active']);
      }
    } catch (e) {
      print('❌ Failed to list maps: $e');
    }
    return MapListResult(maps: [], activeMap: null);
  }
  
  Future<ApiResult> saveMap(String name) async {
    return _post('/api/map/save', {'name': name});
  }
  
  Future<ApiResult> selectMap(String name) async {
    return _post('/api/map/select', {'name': name});
  }
  
  Future<ApiResult> deleteMap(String name) async {
    return _post('/api/map/delete', {'name': name});
  }
  
  // === System ===
  
  Future<ApiResult> shutdown() async {
    return _post('/api/system/shutdown', {});
  }
  
  Future<ApiResult> reboot() async {
    return _post('/api/system/reboot', {});
  }
  
  // === Helper ===
  
  Future<ApiResult> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));
      
      final data = jsonDecode(response.body);
      return ApiResult(
        success: data['success'] ?? false,
        message: data['message'] ?? data['error'] ?? '',
        data: data,
      );
    } catch (e) {
      return ApiResult(success: false, message: e.toString());
    }
  }
}

/// Result from an API call
class ApiResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  
  ApiResult({required this.success, required this.message, this.data});
}

/// Robot status response
class RobotStatus {
  final bool rosRunning;
  final String mode;
  final int? pid;
  final SystemInfo system;
  final String logTail;
  
  RobotStatus({
    required this.rosRunning,
    required this.mode,
    this.pid,
    required this.system,
    required this.logTail,
  });
  
  factory RobotStatus.fromJson(Map<String, dynamic> json) {
    return RobotStatus(
      rosRunning: json['ros_running'] ?? false,
      mode: json['mode'] ?? 'stopped',
      pid: json['pid'],
      system: SystemInfo.fromJson(json['system'] ?? {}),
      logTail: json['log_tail'] ?? '',
    );
  }
}

/// System information
class SystemInfo {
  final double? cpuTemp;
  final double? cpuPercent;
  final double? uptimeHours;
  final int? memTotalMb;
  final int? memAvailMb;
  
  SystemInfo({
    this.cpuTemp,
    this.cpuPercent,
    this.uptimeHours,
    this.memTotalMb,
    this.memAvailMb,
  });
  
  factory SystemInfo.fromJson(Map<String, dynamic> json) {
    return SystemInfo(
      cpuTemp: json['cpu_temp_c']?.toDouble(),
      cpuPercent: json['cpu_percent']?.toDouble(),
      uptimeHours: json['uptime_hours']?.toDouble(),
      memTotalMb: json['mem_total_mb'],
      memAvailMb: json['mem_avail_mb'],
    );
  }
  
  int? get memUsedMb => (memTotalMb != null && memAvailMb != null) 
      ? memTotalMb! - memAvailMb! 
      : null;
      
  double? get memUsagePercent => (memTotalMb != null && memUsedMb != null)
      ? (memUsedMb! / memTotalMb!) * 100
      : null;
}

/// Map list result
class MapListResult {
  final List<MapInfo> maps;
  final String? activeMap;
  
  MapListResult({required this.maps, this.activeMap});
}

/// Map information
class MapInfo {
  final String name;
  final String path;
  final double modified;
  final bool isActive;
  
  MapInfo({required this.name, required this.path, required this.modified, this.isActive = false});
  
  factory MapInfo.fromJson(Map<String, dynamic> json) {
    return MapInfo(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      modified: (json['modified'] ?? 0).toDouble(),
      isActive: json['active'] ?? false,
    );
  }
  
  DateTime get modifiedDate => DateTime.fromMillisecondsSinceEpoch(
    (modified * 1000).toInt()
  );
}

