/// Ticket status for orders
enum TicketStatus { 
  open, 
  inProgress, 
  complete, 
  cancelled;
  
  String get displayName {
    switch (this) {
      case TicketStatus.open:
        return 'Open';
      case TicketStatus.inProgress:
        return 'In Progress';
      case TicketStatus.complete:
        return 'Complete';
      case TicketStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Return pose for delivery navigation
class ReturnPose {
  final double x;
  final double y;
  final double theta;
  
  ReturnPose({required this.x, required this.y, this.theta = 0.0});
  
  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'theta': theta};
  
  factory ReturnPose.fromJson(Map<String, dynamic> json) => ReturnPose(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    theta: (json['theta'] as num?)?.toDouble() ?? 0.0,
  );
}

/// Represents a customer order ticket
class Ticket {
  final String id;
  final String title;           // "Table 5" or location name
  final int ticketNumber;       // Ticket #1, #2, etc.
  final List<String> items;     // Individual order items
  final TicketStatus status;
  final DateTime timestamp;
  final String? locationName;   // Waypoint name where ticket was created
  final ReturnPose? returnPose; // Coordinates for delivery navigation

  Ticket({
    required this.id,
    required this.title,
    required this.ticketNumber,
    required this.items,
    required this.status,
    required this.timestamp,
    this.locationName,
    this.returnPose,
  });

  /// Create a new ticket
  factory Ticket.create({
    required String id,
    required int ticketNumber,
    String? title,
    String? locationName,
    ReturnPose? returnPose,
    List<String>? items,
    String content = '',
    TicketStatus status = TicketStatus.open,
  }) {
    // Support both items list and legacy content string
    final itemsList = items ?? 
        (content.isNotEmpty ? content.split('\n').where((s) => s.trim().isNotEmpty).toList() : []);
    
    // Use location name as title if provided, otherwise use ticket number
    final ticketTitle = title ?? locationName ?? 'Ticket #$ticketNumber';
    
    return Ticket(
      id: id,
      title: ticketTitle,
      ticketNumber: ticketNumber,
      items: itemsList,
      status: status,
      timestamp: DateTime.now(),
      locationName: locationName,
      returnPose: returnPose,
    );
  }

  /// Create from JSON (for ROS/robot storage)
  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      ticketNumber: json['ticket_number'] as int? ?? 0,
      items: (json['items'] as List<dynamic>?)?.cast<String>() ?? [],
      status: TicketStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TicketStatus.open,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
      locationName: json['location_name'] as String?,
      returnPose: json['return_pose'] != null 
          ? ReturnPose.fromJson(json['return_pose'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'ticket_number': ticketNumber,
      'items': items,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'location_name': locationName,
      'return_pose': returnPose?.toJson(),
    };
  }

  /// Create a copy with updated fields
  Ticket copyWith({
    String? title,
    int? ticketNumber,
    List<String>? items,
    TicketStatus? status,
    DateTime? timestamp,
    String? locationName,
    ReturnPose? returnPose,
  }) {
    return Ticket(
      id: id,
      title: title ?? this.title,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      items: items ?? this.items,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      locationName: locationName ?? this.locationName,
      returnPose: returnPose ?? this.returnPose,
    );
  }

  /// Get content as string (for backwards compatibility)
  String get content => items.join('\n');

  /// Get excerpt of content (first ~50 characters)
  String get excerpt {
    final contentStr = content;
    if (contentStr.length <= 50) return contentStr;
    return '${contentStr.substring(0, 50)}...';
  }
  
  /// Legacy compatibility
  DateTime get createdAt => timestamp;
  DateTime get updatedAt => timestamp;

  /// Get status color
  static int getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return 0xFF4CAF50;  // Green
      case TicketStatus.inProgress:
        return 0xFFFFA500;  // Orange
      case TicketStatus.complete:
        return 0xFF2196F3;  // Blue
      case TicketStatus.cancelled:
        return 0xFF888888;  // Gray
    }
  }

  /// Get status display text
  static String getStatusText(TicketStatus status) {
    return status.displayName;
  }
}
