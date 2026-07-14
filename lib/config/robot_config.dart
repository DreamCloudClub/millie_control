/// Robot Connection Configuration
/// 
/// Update these values to match your robot's network settings.
/// All devices (controller tablet, face tablet) connect through ROSBridge.

class RobotConfig {
  /// Your robot's IP address on the local network
  static const String robotIP = '192.168.0.157';
  
  /// ROSBridge WebSocket port (default: 9090)
  static const int rosbridgePort = 9090;
  
  /// Boot server API port (default: 5050)  
  static const int apiPort = 5050;
  
  /// Web video server port (default: 8080)
  static const int videoPort = 8080;
  
  /// Full ROSBridge WebSocket URL
  static String get rosbridgeUrl => 'ws://$robotIP:$rosbridgePort';
  
  /// Full Boot Server API URL
  static String get apiUrl => 'http://$robotIP:$apiPort';
  
  /// Video stream URL (web_video_server)
  static String videoStreamUrl({
    String topic = '/oak/rgb/image_raw',
    int width = 320,
    int height = 240,
    int quality = 30,
  }) => 'http://$robotIP:$videoPort/stream?topic=$topic&width=$width&height=$height&quality=$quality&max_age=200';
}
