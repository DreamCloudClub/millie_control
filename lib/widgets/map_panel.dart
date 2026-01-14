import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/rosbridge.dart';
import 'top_notification.dart';

/// Map interaction modes
enum MapMode { none, setPose, addWaypoint }

/// Painter for direction dial
class _DirectionDialPainter extends CustomPainter {
  final double angle;
  
  _DirectionDialPainter({required this.angle});
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    
    // Draw tick marks
    final tickPaint = Paint()
      ..color = AppColors.textMuted
      ..strokeWidth = 2;
    
    for (int i = 0; i < 8; i++) {
      final tickAngle = i * math.pi / 4;
      final innerRadius = i % 2 == 0 ? radius - 15 : radius - 10;
      final start = Offset(
        center.dx + innerRadius * math.cos(tickAngle),
        center.dy + innerRadius * math.sin(tickAngle),
      );
      final end = Offset(
        center.dx + radius * math.cos(tickAngle),
        center.dy + radius * math.sin(tickAngle),
      );
      canvas.drawLine(start, end, tickPaint);
    }
    
    // Draw arrow pointing in selected direction (raw screen angle)
    final arrowPaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    final arrowEnd = Offset(
      center.dx + (radius - 5) * math.cos(angle),
      center.dy + (radius - 5) * math.sin(angle),
    );
    
    canvas.drawLine(center, arrowEnd, arrowPaint);
    
    // Draw arrow head
    final headLength = 15.0;
    final headAngle = 0.5;
    final head1 = Offset(
      arrowEnd.dx - headLength * math.cos(angle - headAngle),
      arrowEnd.dy - headLength * math.sin(angle - headAngle),
    );
    final head2 = Offset(
      arrowEnd.dx - headLength * math.cos(angle + headAngle),
      arrowEnd.dy - headLength * math.sin(angle + headAngle),
    );
    canvas.drawLine(arrowEnd, head1, arrowPaint);
    canvas.drawLine(arrowEnd, head2, arrowPaint);
    
    // Draw center dot
    canvas.drawCircle(center, 6, Paint()..color = AppColors.accent);
  }
  
  @override
  bool shouldRepaint(covariant _DirectionDialPainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}

/// Fully functional map view with:
/// - Live robot position from slam_toolbox
/// - Tap-to-navigate (sends goals to Nav2)
/// - Waypoint management (add, go to, delete)
class MapPanel extends StatefulWidget {
  final RosBridge rosBridge;
  
  const MapPanel({super.key, required this.rosBridge});

  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel> {
  // Pan and zoom state
  Offset _offset = Offset.zero;
  double _scale = 3.0;  // Initial scale to make map visible (each map pixel = 3 screen pixels)
  
  // Robot position (from slam_toolbox)
  RobotPose? _robotPose;
  
  // Waypoints (from ROS)
  List<Waypoint> _waypoints = [];
  
  // Selected waypoint for actions
  Waypoint? _selectedWaypoint;
  
  // Navigation state
  bool _navigating = false;
  
  // Mode for map interactions
  MapMode _mapMode = MapMode.none;
  Offset? _dragStartWorld;  // Starting position for drag
  
  // Map data from ROS
  MapData? _mapData;
  ui.Image? _mapImage;
  bool _loadingMap = false;
  bool _initialViewSet = false;
  
  // Laser scan data
  LaserScan? _laserScan;
  
  // Multi-listener callbacks (for cleanup)
  late final void Function(MapData) _mapListener;
  late final void Function(RobotPose) _poseListener;
  late final void Function(List<Waypoint>) _waypointListener;
  late final void Function(NavStatus) _navStatusListener;
  late final void Function(LaserScan) _laserScanListener;
  
  // Map display settings
  double get _pixelsPerMeter => _mapData != null ? (1.0 / _mapData!.resolution) : 50.0;
  double get _mapWidthPx => _mapData?.width.toDouble() ?? 500;
  double get _mapHeightPx => _mapData?.height.toDouble() ?? 500;
  
  @override
  void initState() {
    super.initState();
    
    // Listen for robot pose updates (multi-listener pattern)
    _poseListener = (pose) {
      if (mounted) {
        setState(() => _robotPose = pose);
      }
    };
    widget.rosBridge.addPoseListener(_poseListener);
    
    // Listen for waypoint updates (multi-listener pattern)
    _waypointListener = (waypoints) {
      if (mounted) {
        setState(() => _waypoints = waypoints);
      }
    };
    widget.rosBridge.addWaypointListener(_waypointListener);
    
    // Listen for map updates (multi-listener pattern)
    _mapListener = (mapData) {
      if (mounted && !_loadingMap) {
        _updateMapImage(mapData);
      }
    };
    widget.rosBridge.addMapListener(_mapListener);
    
    // Listen for navigation status updates (multi-listener pattern)
    _navStatusListener = (status) {
      if (mounted) {
        _handleNavStatus(status);
      }
    };
    widget.rosBridge.addNavStatusListener(_navStatusListener);
    
    // Listen for laser scan updates (multi-listener pattern)
    _laserScanListener = (scan) {
      if (mounted) {
        setState(() => _laserScan = scan);
      }
    };
    widget.rosBridge.addLaserScanListener(_laserScanListener);
    
    // Request initial waypoints
    widget.rosBridge.requestWaypoints();
  }
  
  @override
  void dispose() {
    widget.rosBridge.removePoseListener(_poseListener);  // Multi-listener cleanup
    widget.rosBridge.removeWaypointListener(_waypointListener);  // Multi-listener cleanup
    widget.rosBridge.removeMapListener(_mapListener);  // Multi-listener cleanup
    widget.rosBridge.removeNavStatusListener(_navStatusListener);  // Multi-listener cleanup
    widget.rosBridge.removeLaserScanListener(_laserScanListener);  // Multi-listener cleanup
    _mapImage?.dispose();
    super.dispose();
  }
  
  void _handleNavStatus(NavStatus status) {
    setState(() => _navigating = false);
    
    switch (status) {
      case NavStatus.succeeded:
        _showNotification('✓ Navigation complete!', AppColors.accent);
        break;
      case NavStatus.canceled:
        _showNotification('Navigation cancelled', AppColors.warning);
        break;
      case NavStatus.failed:
        _showNotification('✗ Navigation failed', AppColors.danger);
        break;
      default:
        break;  // Don't show notification for idle/executing
    }
  }
  
  void _showNotification(String message, Color color) {
    TopNotification.show(context, message: message, backgroundColor: color);
  }
  
  /// Convert OccupancyGrid data to a displayable image
  Future<void> _updateMapImage(MapData mapData) async {
    _loadingMap = true;
    
    try {
      final width = mapData.width;
      final height = mapData.height;
      
      // Create RGBA pixel data
      final pixels = Uint8List(width * height * 4);
      
      for (int i = 0; i < mapData.data.length; i++) {
        final value = mapData.data[i];
        final pixelIndex = i * 4;
        
        int r, g, b, a;
        if (value == -1) {
          // Unknown - dark grey
          r = 40; g = 40; b = 45; a = 255;
        } else if (value == 0) {
          // Free - light grey/white
          r = 60; g = 62; b = 68; a = 255;
        } else if (value >= 100) {
          // Occupied - black/white walls
          r = 220; g = 220; b = 225; a = 255;
        } else {
          // Partially occupied - gradient
          final gray = 60 + (value * 1.6).toInt();
          r = gray; g = gray; b = gray; a = 255;
        }
        
        pixels[pixelIndex] = r;
        pixels[pixelIndex + 1] = g;
        pixels[pixelIndex + 2] = b;
        pixels[pixelIndex + 3] = a;
      }
      
      // Create image from pixels
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        width,
        height,
        ui.PixelFormat.rgba8888,
        (image) => completer.complete(image),
      );
      
      final image = await completer.future;
      
      if (mounted) {
        setState(() {
          _mapImage?.dispose();
          _mapData = mapData;
          _mapImage = image;
        });
      }
    } catch (e) {
      print("Error creating map image: $e");
    } finally {
      _loadingMap = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Center map on first load
          if (_mapData != null && !_initialViewSet) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _centerMapInView(constraints);
            });
          }
          
          return Stack(
            children: [
              // Map canvas with pan + zoom
              GestureDetector(
                onDoubleTapDown: _handleDoubleTap,
                onTapUp: _handleTap,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: Container(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  color: const Color(0xFF1a1a1f),
                  child: ClipRect(
                    child: CustomPaint(
                      painter: _FullMapPainter(
                        mapImage: _mapImage,
                        mapData: _mapData,
                        offset: _offset,
                        scale: _scale,
                        robotPose: _robotPose,
                        waypoints: _waypoints,
                        selectedWaypoint: _selectedWaypoint,
                        laserScan: _laserScan,
                      ),
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                  ),
                ),
              ),
              
              // Waypoint action popup
              if (_selectedWaypoint != null)
                _WaypointPopup(
                  waypoint: _selectedWaypoint!,
                  onGo: () => _goToWaypoint(_selectedWaypoint!),
                  onDelete: () => _deleteWaypoint(_selectedWaypoint!),
                  onCancel: () => setState(() => _selectedWaypoint = null),
                ),
              
              // Status bar (top)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildStatusBar(),
              ),
              
              
              // Map controls (bottom right)
              Positioned(
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: _MapControls(
                  onZoomIn: () => setState(() => _scale = (_scale * 1.3).clamp(0.5, 10.0)),
                  onZoomOut: () => setState(() => _scale = (_scale / 1.3).clamp(0.5, 10.0)),
                  onResetView: () => _resetView(constraints),
                  onCenterRobot: _centerOnRobot,
                  onSetPose: _togglePoseMode,
                  onAddWaypoint: _saveWaypointAtRobot,
                  mapMode: _mapMode,
                ),
              ),
              
              // Cancel navigation button
              if (_navigating)
                Positioned(
                  bottom: AppSpacing.md,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _cancelNavigation,
                      icon: const Icon(Icons.stop, color: Colors.white),
                      label: const Text('Cancel Navigation', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              
            ],
          );
        },
      ),
    );
  }
  
  void _centerMapInView(BoxConstraints constraints) {
    if (_mapData == null) return;
    
    // Calculate scale to fit map in view with some padding
    final mapWidth = _mapData!.width.toDouble();
    final mapHeight = _mapData!.height.toDouble();
    final viewWidth = constraints.maxWidth;
    final viewHeight = constraints.maxHeight;
    
    final scaleX = (viewWidth - 100) / mapWidth;
    final scaleY = (viewHeight - 100) / mapHeight;
    final fitScale = scaleX < scaleY ? scaleX : scaleY;
    
    // Center the map
    final scaledWidth = mapWidth * fitScale;
    final scaledHeight = mapHeight * fitScale;
    final offsetX = (viewWidth - scaledWidth) / 2;
    final offsetY = (viewHeight - scaledHeight) / 2;
    
    setState(() {
      _scale = fitScale.clamp(1.0, 10.0);
      _offset = Offset(offsetX, offsetY);
      _initialViewSet = true;
    });
  }
  
  void _resetView(BoxConstraints constraints) {
    _initialViewSet = false;
    _centerMapInView(constraints);
  }
  
  Widget _buildStatusBar() {
    final connected = widget.rosBridge.isConnected;
    final hasPosition = _robotPose != null;
    final hasMap = _mapData != null;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      color: AppColors.surface,
      child: Row(
        children: [
          Icon(
            Icons.map, 
            color: hasMap ? AppColors.success : AppColors.accent, 
            size: 18
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            hasMap ? 'Map ${_mapData!.width}x${_mapData!.height}' : 'Waiting for map...',
            style: TextStyle(
              color: hasMap ? AppColors.textPrimary : AppColors.textMuted, 
              fontWeight: FontWeight.bold
            ),
          ),
          if (_loadingMap) ...[
            const SizedBox(width: AppSpacing.sm),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
            ),
          ],
          const SizedBox(width: AppSpacing.md),
          Text(
            '${_waypoints.length} waypoints',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const Spacer(),
          // Robot position
          if (hasPosition) ...[
            Icon(Icons.location_on, color: AppColors.success, size: 14),
            const SizedBox(width: 4),
            Text(
              '(${_robotPose!.x.toStringAsFixed(2)}, ${_robotPose!.y.toStringAsFixed(2)})',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'monospace'),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          // Connection status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
            decoration: BoxDecoration(
              color: (connected ? AppColors.success : AppColors.danger).withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: connected ? AppColors.success : AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  connected ? 'LIVE' : 'OFFLINE',
                  style: TextStyle(
                    color: connected ? AppColors.success : AppColors.danger,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _InstructionRow(icon: Icons.touch_app, text: 'Double-tap: Navigate'),
          _InstructionRow(icon: Icons.smart_toy, text: 'Robot → tap → dial'),
          _InstructionRow(icon: Icons.add_location, text: 'Pin → tap → dial'),
        ],
      ),
    );
  }
  
  // === Coordinate Conversion ===
  
  Offset _worldToScreen(double x, double y) {
    if (_mapData != null) {
      // Convert world coordinates to pixel coordinates using map origin
      // Map origin is the world position of pixel (0, height-1) - bottom-left corner
      final pixelX = (x - _mapData!.originX) / _mapData!.resolution;
      final pixelY = _mapData!.height - (y - _mapData!.originY) / _mapData!.resolution;
      return Offset(pixelX, pixelY);
    } else {
      // Fallback: center-based for placeholder
      const mapSize = 10.0;
      const ppm = 50.0;
      return Offset(
        mapSize * ppm / 2 + x * ppm,
        mapSize * ppm / 2 - y * ppm,
      );
    }
  }
  
  Offset _screenToWorld(Offset screen) {
    // Account for pan and zoom
    final adjustedX = (screen.dx - _offset.dx) / _scale;
    final adjustedY = (screen.dy - _offset.dy) / _scale;
    
    if (_mapData != null) {
      // Convert pixel coordinates to world coordinates
      final worldX = adjustedX * _mapData!.resolution + _mapData!.originX;
      final worldY = (_mapData!.height - adjustedY) * _mapData!.resolution + _mapData!.originY;
      return Offset(worldX, worldY);
    } else {
      // Fallback
      const mapSize = 10.0;
      const ppm = 50.0;
      return Offset(
        (adjustedX - mapSize * ppm / 2) / ppm,
        (mapSize * ppm / 2 - adjustedY) / ppm,
      );
    }
  }
  
  // === Gesture Handling ===
  
  Offset _lastFocalPoint = Offset.zero;
  Offset? _modeStartScreen;  // For pose/waypoint mode
  
  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
    
    // If in a mode, record start position
    if (_mapMode != MapMode.none) {
      _modeStartScreen = details.localFocalPoint;
      _dragStartWorld = _screenToWorld(details.localFocalPoint);
    }
  }
  
  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_mapMode != MapMode.none) {
      // In mode - just track position, don't pan/zoom
      _lastPanPosition = details.localFocalPoint;
      return;
    }
    
    // Normal pan/zoom
    setState(() {
      _offset += details.focalPoint - _lastFocalPoint;
      _lastFocalPoint = details.focalPoint;
      
      if (details.scale != 1.0) {
        // Dampen zoom sensitivity (0.3 = 30% of the gesture)
        final dampedScale = 1.0 + (details.scale - 1.0) * 0.3;
        _scale = (_scale * dampedScale).clamp(0.5, 5.0);
      }
    });
  }
  
  void _onScaleEnd(ScaleEndDetails details) {
    if (_mapMode != MapMode.none && _dragStartWorld != null) {
      final x = _dragStartWorld!.dx;
      final y = _dragStartWorld!.dy;
      
      // Use robot's current heading or 0 for now
      final theta = _robotPose?.theta ?? 0.0;
      
      if (_mapMode == MapMode.setPose) {
        widget.rosBridge.publishInitialPose(x, y, theta: theta);
        _showNotification('🤖 Robot pose set at (${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})', AppColors.accent);
      } else if (_mapMode == MapMode.addWaypoint) {
        _showAddWaypointDialogWithTheta(x, y, theta);
      }
      
      setState(() {
        _mapMode = MapMode.none;
        _dragStartWorld = null;
        _lastPanPosition = null;
        _modeStartScreen = null;
      });
    }
  }
  
  void _handleTap(TapUpDetails details) {
    if (_mapMode != MapMode.none) {
      final worldPos = _screenToWorld(details.localPosition);
      _showDirectionPicker(worldPos.dx, worldPos.dy);
    } else {
      // Check if tapped on a waypoint
      final worldPos = _screenToWorld(details.localPosition);
      Waypoint? tappedWaypoint;
      
      for (final wp in _waypoints) {
        final dx = wp.x - worldPos.dx;
        final dy = wp.y - worldPos.dy;
        final dist = math.sqrt(dx * dx + dy * dy);
        // Hit detection radius in meters (about 0.5m)
        if (dist < 0.5) {
          tappedWaypoint = wp;
          break;
        }
      }
      
      setState(() => _selectedWaypoint = tappedWaypoint);
    }
  }
  
  void _showDirectionPicker(double x, double y) {
    double selectedAngle = _robotPose?.theta ?? 0.0;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.large)),
          title: Text(
            _mapMode == MapMode.setPose ? 'Set Robot Pose' : 'Add Waypoint',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Direction dial - raw screen coords for display
              GestureDetector(
                onPanUpdate: (details) {
                  final center = const Offset(75, 75);
                  final pos = details.localPosition - center;
                  setDialogState(() {
                    // Raw angle from screen (for dial display)
                    selectedAngle = math.atan2(pos.dy, pos.dx);
                  });
                },
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.background,
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: CustomPaint(
                    painter: _DirectionDialPainter(angle: selectedAngle),
                    size: const Size(150, 150),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${(-selectedAngle * 180 / math.pi).toStringAsFixed(0)}°',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _mapMode = MapMode.none);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () {
                Navigator.pop(context);
                // Convert screen angle to ROS angle (flip Y axis)
                final rosAngle = -selectedAngle;
                if (_mapMode == MapMode.setPose) {
                  widget.rosBridge.publishInitialPose(x, y, theta: rosAngle);
                  _showNotification('🤖 Robot pose set', AppColors.accent);
                } else if (_mapMode == MapMode.addWaypoint) {
                  _showAddWaypointDialogWithTheta(x, y, rosAngle);
                }
                setState(() => _mapMode = MapMode.none);
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
  
  Offset? _lastPanPosition;
  
  void _handleDoubleTap(TapDownDetails details) {
    if (_mapMode != MapMode.none) return;  // Ignore when in a mode
    final worldPos = _screenToWorld(details.localPosition);
    _navigateTo(worldPos.dx, worldPos.dy);
  }
  
  void _handleLongPress(LongPressStartDetails details) {
    final worldPos = _screenToWorld(details.localPosition);
    _showAddWaypointDialog(worldPos.dx, worldPos.dy);
  }
  
  // === Actions ===
  
  void _navigateTo(double x, double y) {
    // Don't specify heading - let robot approach from any direction
    // This prevents the "turn 270° right instead of 90° left" issue
    widget.rosBridge.publishNavGoal(x, y, theta: 0.0);
    setState(() => _navigating = true);
    
    _showNotification('Navigating to (${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})', AppColors.accent);
  }
  
  void _goToWaypoint(Waypoint wp) {
    widget.rosBridge.publishGoToWaypoint(wp.name);
    setState(() {
      _navigating = true;
      _selectedWaypoint = null;
    });
    
    _showNotification('Navigating to "${wp.name}"', AppColors.accent);
  }
  
  void _deleteWaypoint(Waypoint wp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete "${wp.name}"?', style: const TextStyle(color: AppColors.textPrimary)),
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
    
    if (confirm == true) {
      widget.rosBridge.publishDeleteWaypoint(wp.name);
      setState(() {
        _waypoints.removeWhere((w) => w.name == wp.name);
        _selectedWaypoint = null;
      });
    }
  }
  
  void _cancelNavigation() {
    widget.rosBridge.publishCancelNav();
    // Note: _navigating will be set to false when we receive NavStatus.canceled
  }
  
  void _togglePoseMode() {
    setState(() {
      _mapMode = _mapMode == MapMode.setPose ? MapMode.none : MapMode.setPose;
    });
    if (_mapMode == MapMode.setPose) {
      _showNotification('Tap on map to set robot position', AppColors.warning);
    }
  }
  
  void _saveWaypointAtRobot() {
    if (_robotPose == null) {
      _showNotification('⚠️ Robot position unknown', AppColors.warning);
      return;
    }
    _addWaypointAtRobot();
  }
  
  void _showAddWaypointDialogWithTheta(double x, double y, double theta) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        title: const Text('Add Waypoint', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Position: (${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            Text(
              'Direction: ${(theta * 180 / 3.14159).toStringAsFixed(0)}°',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Waypoint name (e.g., Kitchen)',
                hintStyle: TextStyle(color: AppColors.textMuted),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                widget.rosBridge.publishSaveWaypoint(name);
                setState(() {
                  _waypoints.add(Waypoint(name: name, x: x, y: y, theta: theta));
                });
                Navigator.pop(context);
                _showNotification('📍 Waypoint "$name" saved', AppColors.success);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  void _addWaypointAtRobot() {
    if (_robotPose == null) {
      _showNotification('Robot position unknown', AppColors.danger);
      return;
    }
    
    _showAddWaypointDialog(_robotPose!.x, _robotPose!.y);
  }
  
  void _showAddWaypointDialog(double x, double y) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        title: const Text('Add Waypoint', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Position: (${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Waypoint name (e.g., Kitchen)',
                hintStyle: TextStyle(color: AppColors.textMuted),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                widget.rosBridge.publishSaveWaypoint(name);
                setState(() {
                  _waypoints.add(Waypoint(name: name, x: x, y: y));
                });
                Navigator.pop(context);
                _showNotification('Waypoint "$name" saved', AppColors.success);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  void _centerOnRobot() {
    if (_robotPose == null || _mapData == null) return;
    
    // Convert robot world position to map pixel position
    final robotMapX = (_robotPose!.x - _mapData!.originX) / _mapData!.resolution;
    final robotMapY = _mapData!.height - (_robotPose!.y - _mapData!.originY) / _mapData!.resolution;
    
    final viewCenter = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    );
    
    setState(() {
      _offset = viewCenter - Offset(robotMapX * _scale, robotMapY * _scale);
    });
  }
}

// === Helper Widgets ===

class _InstructionRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InstructionRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 12),
          const SizedBox(width: AppSpacing.xs),
          Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetView;
  final VoidCallback onCenterRobot;
  final VoidCallback onSetPose;
  final VoidCallback onAddWaypoint;
  final MapMode mapMode;

  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetView,
    required this.onCenterRobot,
    required this.onSetPose,
    required this.onAddWaypoint,
    required this.mapMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Mode buttons at top
        _ControlButton(
          icon: Icons.smart_toy,
          onPressed: onSetPose,
          tooltip: 'Set robot pose',
          isActive: mapMode == MapMode.setPose,
        ),
        const SizedBox(height: AppSpacing.xs),
        _ControlButton(
          icon: Icons.add_location,
          onPressed: onAddWaypoint,
          tooltip: 'Save waypoint here',
          isActive: false,
        ),
        const SizedBox(height: AppSpacing.md),
        // Zoom/view controls
        _ControlButton(icon: Icons.add, onPressed: onZoomIn, tooltip: 'Zoom in'),
        const SizedBox(height: AppSpacing.xs),
        _ControlButton(icon: Icons.remove, onPressed: onZoomOut, tooltip: 'Zoom out'),
        const SizedBox(height: AppSpacing.xs),
        _ControlButton(icon: Icons.my_location, onPressed: onCenterRobot, tooltip: 'Center on robot'),
        const SizedBox(height: AppSpacing.xs),
        _ControlButton(icon: Icons.center_focus_strong, onPressed: onResetView, tooltip: 'Reset view'),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? AppColors.warning.withOpacity(0.2) : AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(color: isActive ? AppColors.warning : AppColors.border, width: isActive ? 2 : 1),
          ),
          child: Center(
            child: Icon(icon, color: isActive ? AppColors.warning : AppColors.textSecondary, size: 22),
          ),
        ),
      ),
    );
  }
}

class _AddWaypointButton extends StatelessWidget {
  final VoidCallback onAdd;

  const _AddWaypointButton({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_location, color: Colors.white, size: 18),
            SizedBox(width: AppSpacing.xs),
            Text('Add Here', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _WaypointPopup extends StatelessWidget {
  final Waypoint waypoint;
  final VoidCallback onGo;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const _WaypointPopup({
    required this.waypoint,
    required this.onGo,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        margin: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.accent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              waypoint.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '(${waypoint.x.toStringAsFixed(2)}, ${waypoint.y.toStringAsFixed(2)})',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.lg),
            // GO button - full width on top
            GestureDetector(
              onTap: onGo,
              child: Container(
                width: 140,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.navigation, color: Colors.white, size: 24),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        'GO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Delete and Cancel buttons - square icons aligned underneath
            SizedBox(
              width: 140,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SquareIconButton(
                    icon: Icons.delete,
                    color: AppColors.danger,
                    onPressed: onDelete,
                  ),
                  _SquareIconButton(
                    icon: Icons.close,
                    color: AppColors.textMuted,
                    onPressed: onCancel,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopupButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _PopupButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(child: Icon(icon, color: color, size: 24)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SmallPopupButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _SmallPopupButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: color, width: 1.5),
            ),
            child: Center(child: Icon(icon, color: color, size: 18)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _SquareIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(child: Icon(icon, color: color, size: 22)),
      ),
    );
  }
}

/// Full map painter that renders map, robot, and waypoints with transform
class _FullMapPainter extends CustomPainter {
  final ui.Image? mapImage;
  final MapData? mapData;
  final Offset offset;
  final double scale;
  final RobotPose? robotPose;
  final List<Waypoint> waypoints;
  final Waypoint? selectedWaypoint;
  final LaserScan? laserScan;

  _FullMapPainter({
    required this.mapImage,
    required this.mapData,
    required this.offset,
    required this.scale,
    required this.robotPose,
    required this.waypoints,
    required this.selectedWaypoint,
    this.laserScan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    
    // Apply pan and zoom transform
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    
    if (mapImage != null && mapData != null) {
      // Draw actual map
      _drawMap(canvas);
      _drawOriginAxes(canvas);
    } else {
      // Draw placeholder grid
      _drawPlaceholderGrid(canvas, size);
    }
    
    // Draw laser scan points
    if (laserScan != null && robotPose != null && mapData != null) {
      _drawLaserScan(canvas, laserScan!, robotPose!);
    }
    
    // Draw waypoints
    for (final wp in waypoints) {
      _drawWaypoint(canvas, wp, wp.name == selectedWaypoint?.name);
    }
    
    // Draw robot
    if (robotPose != null && mapData != null) {
      _drawRobot(canvas, robotPose!);
    }
    
    canvas.restore();
  }
  
  void _drawMap(Canvas canvas) {
    // ROS maps have origin at bottom-left, Flutter at top-left
    // Flip vertically
    canvas.save();
    canvas.scale(1, -1);
    canvas.translate(0, -mapData!.height.toDouble());
    
    final paint = Paint()..filterQuality = FilterQuality.none;
    canvas.drawImage(mapImage!, Offset.zero, paint);
    
    canvas.restore();
  }
  
  void _drawOriginAxes(Canvas canvas) {
    final originPx = _worldToMap(0, 0);
    final axisPaint = Paint()..strokeWidth = 2 / scale;  // Keep constant screen width
    
    // X axis (red)
    axisPaint.color = Colors.red.withOpacity(0.7);
    canvas.drawLine(originPx, Offset(originPx.dx + 30, originPx.dy), axisPaint);
    
    // Y axis (green) - up in world = negative Y in screen
    axisPaint.color = Colors.green.withOpacity(0.7);
    canvas.drawLine(originPx, Offset(originPx.dx, originPx.dy - 30), axisPaint);
    
    // Origin circle
    canvas.drawCircle(originPx, 3 / scale, Paint()..color = Colors.white);
  }
  
  void _drawPlaceholderGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3a3a3f)
      ..strokeWidth = 1 / scale;
    
    const gridSize = 500.0;
    const spacing = 50.0;
    
    for (var x = 0.0; x <= gridSize; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, gridSize), paint);
    }
    for (var y = 0.0; y <= gridSize; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(gridSize, y), paint);
    }
  }
  
  void _drawLaserScan(Canvas canvas, LaserScan scan, RobotPose pose) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.9)
      ..strokeWidth = 1.5 / scale;
    
    // Draw every 3rd point to reduce clutter
    for (int i = 0; i < scan.ranges.length; i += 3) {
      final range = scan.ranges[i];
      if (range <= 0.05 || range > 8.0) continue;  // Skip invalid readings
      
      // Calculate angle of this beam in world frame
      final beamAngle = scan.angleMin + i * scan.angleIncrement + pose.theta;
      
      // Calculate endpoint in world coordinates
      final endX = pose.x + range * math.cos(beamAngle);
      final endY = pose.y + range * math.sin(beamAngle);
      
      // Convert to map pixels
      final endPos = _worldToMap(endX, endY);
      
      // Draw small point
      canvas.drawCircle(endPos, 1.5 / scale, paint);
    }
  }
  
  void _drawWaypoint(Canvas canvas, Waypoint wp, bool isSelected) {
    final pos = _worldToMap(wp.x, wp.y);
    final radius = (isSelected ? 12.0 : 10.0) / scale;
    
    // Outer glow
    if (isSelected) {
      canvas.drawCircle(
        pos,
        radius * 1.5,
        Paint()..color = AppColors.accent.withOpacity(0.3),
      );
    }
    
    // Main circle
    canvas.drawCircle(
      pos,
      radius,
      Paint()..color = AppColors.accent,
    );
    
    // White border
    canvas.drawCircle(
      pos,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / scale,
    );
  }
  
  void _drawRobot(Canvas canvas, RobotPose pose) {
    final pos = _worldToMap(pose.x, pose.y);
    final radius = 14.0 / scale;
    
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(-pose.theta);  // Rotate to robot heading
    
    // Glow
    const robotColor = Color(0xFFFF6D00);  // Dark orange
    canvas.drawCircle(
      Offset.zero,
      radius * 1.3,
      Paint()..color = robotColor.withOpacity(0.4),
    );
    
    // Main circle
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = robotColor,
    );
    
    // White border
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / scale,
    );
    
    // Direction indicator (triangle pointing forward)
    final path = Path()
      ..moveTo(radius * 0.8, 0)
      ..lineTo(-radius * 0.4, -radius * 0.5)
      ..lineTo(-radius * 0.4, radius * 0.5)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    
    canvas.restore();
  }
  
  Offset _worldToMap(double x, double y) {
    if (mapData == null) {
      // Fallback for placeholder
      return Offset(250 + x * 50, 250 - y * 50);
    }
    return Offset(
      (x - mapData!.originX) / mapData!.resolution,
      mapData!.height - (y - mapData!.originY) / mapData!.resolution,
    );
  }

  @override
  bool shouldRepaint(covariant _FullMapPainter oldDelegate) {
    return oldDelegate.mapImage != mapImage ||
           oldDelegate.offset != offset ||
           oldDelegate.scale != scale ||
           oldDelegate.robotPose != robotPose ||
           oldDelegate.waypoints != waypoints ||
           oldDelegate.selectedWaypoint != selectedWaypoint ||
           oldDelegate.laserScan != laserScan;
  }
}

class _GridPainter extends CustomPainter {
  final double gridSpacing;
  final Offset center;

  _GridPainter({required this.gridSpacing, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withOpacity(0.3)
      ..strokeWidth = 1;

    // Draw grid lines
    for (var x = 0.0; x <= size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw origin axes (thicker, colored)
    final axisPaint = Paint()
      ..strokeWidth = 2;
    
    // X axis (red)
    axisPaint.color = Colors.red.withOpacity(0.5);
    canvas.drawLine(Offset(center.dx, center.dy), Offset(size.width, center.dy), axisPaint);
    
    // Y axis (green)
    axisPaint.color = Colors.green.withOpacity(0.5);
    canvas.drawLine(Offset(center.dx, center.dy), Offset(center.dx, 0), axisPaint);
    
    // Origin circle
    final originPaint = Paint()
      ..color = AppColors.textMuted
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, originPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
