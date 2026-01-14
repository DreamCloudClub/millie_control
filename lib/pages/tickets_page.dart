import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/rosbridge.dart';
import '../models/ticket.dart';
import '../services/location_service.dart';

/// Employee-facing Tickets page (like AI Notebook from millie_mini)
/// Shows list of all tickets with status and bottom control bar
class TicketsPage extends StatefulWidget {
  final RosBridge rosBridge;
  final VoidCallback onBack;
  final VoidCallback? onPause;
  final VoidCallback? onPlay;
  final VoidCallback? onRefresh;
  final VoidCallback? onExit;
  
  const TicketsPage({
    super.key,
    required this.rosBridge,
    required this.onBack,
    this.onPause,
    this.onPlay,
    this.onRefresh,
    this.onExit,
  });

  @override
  State<TicketsPage> createState() => TicketsPageState();
}

/// Ticket filter mode
enum TicketFilter { closed, open }

class TicketsPageState extends State<TicketsPage> with AutomaticKeepAliveClientMixin {
  List<Ticket> _tickets = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  TicketFilter _filter = TicketFilter.open;  // Default to Open tickets
  
  // Selected ticket for detail view (null = show list)
  Ticket? _selectedTicket;
  
  // Editing mode (true = show edit form instead of detail view)
  bool _isEditing = false;
  
  // Waypoints and sequences for delivery modal
  List<Waypoint> _waypoints = [];
  List<SavedSequence> _sequences = [];
  
  // Last selected delivery task (persisted across deliveries)
  String? _lastDeliveryTask;
  
  // Ticket counter - resets when all tickets are cleared
  static int _ticketCounter = 0;
  
  /// Get the next ticket number (auto-increments)
  static int get nextTicketNumber => ++_ticketCounter;
  
  /// Reset the counter (call when clearing all tickets)
  static void resetCounter() => _ticketCounter = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadTickets();
    _setupRosBridgeCallbacks();
  }
  
  // Multi-listener references
  late final void Function(List<Waypoint>) _waypointListener;
  late final void Function(List<SavedSequence>) _sequenceListener;
  
  void _setupRosBridgeCallbacks() {
    // Waypoint listener
    _waypointListener = (waypoints) {
      if (mounted) setState(() => _waypoints = waypoints);
    };
    widget.rosBridge.addWaypointListener(_waypointListener);
    
    // Sequence listener
    _sequenceListener = (sequences) {
      if (mounted) setState(() => _sequences = sequences);
    };
    widget.rosBridge.addSequenceListener(_sequenceListener);
    
    // Ticket listener (already multi-listener)
    widget.rosBridge.addTicketListener(_onTicketsUpdate);
    
    // Request current data
    widget.rosBridge.requestWaypoints();
    widget.rosBridge.requestSequences();
    widget.rosBridge.requestTickets();
  }

  @override
  void dispose() {
    widget.rosBridge.removeWaypointListener(_waypointListener);
    widget.rosBridge.removeSequenceListener(_sequenceListener);
    widget.rosBridge.removeTicketListener(_onTicketsUpdate);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  void _onTicketsUpdate(List<Map<String, dynamic>> ticketsJson) {
    if (mounted) {
      final tickets = ticketsJson.map((json) => Ticket.fromJson(json)).toList();
      // Find highest ticket number to sync counter
      int maxNumber = 0;
      for (final t in tickets) {
        if (t.ticketNumber > maxNumber) maxNumber = t.ticketNumber;
      }
      _ticketCounter = maxNumber;
      
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  /// Public method to add a new ticket (called from order completion)
  void addTicket(Ticket ticket) {
    setState(() {
      _tickets.insert(0, ticket);
    });
    // Save to robot
    widget.rosBridge.publishSaveTicket(ticket.toJson());
  }
  
  /// Public method to update an existing ticket
  void updateTicket(Ticket ticket) {
    setState(() {
      final index = _tickets.indexWhere((t) => t.id == ticket.id);
      if (index != -1) {
        _tickets[index] = ticket;
      }
    });
    // Sync to robot
    widget.rosBridge.publishUpdateTicket(ticket.toJson());
  }
  
  /// Public method to delete a ticket by ID
  void deleteTicket(String ticketId) {
    setState(() {
      _tickets.removeWhere((t) => t.id == ticketId);
    });
    // Delete from robot
    widget.rosBridge.publishDeleteTicket(ticketId);
  }
  
  /// Create a new ticket with auto-numbered title
  /// If locationName is provided, it becomes the title
  Ticket createNumberedTicket({
    List<String>? items,
    String content = '',
    TicketStatus status = TicketStatus.open,
    String? locationName,
    ReturnPose? returnPose,
  }) {
    final ticketNum = nextTicketNumber;
    return Ticket.create(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ticketNumber: ticketNum,
      locationName: locationName,
      returnPose: returnPose,
      items: items,
      content: content,
      status: status,
    );
  }
  
  /// Refresh all tickets (clear and reset counter for new day)
  void clearAllTickets() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.refresh,
                  color: AppColors.success,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Refresh Tickets?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This will clear all ${_tickets.length} tickets and reset the order counter for a fresh start.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Clear tickets on robot first
                        widget.rosBridge.publishClearAllTickets();
                        setState(() {
                          _tickets.clear();
                          resetCounter();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Public method to refresh tickets list
  void refreshTickets() {
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    
    // Request tickets from robot - will update via onTicketsUpdate callback
    widget.rosBridge.requestTickets();
    
    // Timeout fallback if robot doesn't respond
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
    setState(() {
      _isLoading = false;
          // Leave _tickets empty if no response
        });
      }
    });
  }

  List<Ticket> get _filteredTickets {
    // First filter by open/closed status
    var filtered = _tickets.where((ticket) {
      if (_filter == TicketFilter.open) {
        return ticket.status == TicketStatus.open || ticket.status == TicketStatus.inProgress;
      } else {
        return ticket.status == TicketStatus.complete || ticket.status == TicketStatus.cancelled;
      }
    }).toList();
    
    // Then filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((ticket) {
        final titleMatch = ticket.title.toLowerCase().contains(_searchQuery);
        final contentMatch = ticket.content.toLowerCase().contains(_searchQuery);
        return titleMatch || contentMatch;
      }).toList();
    }
    
    return filtered;
  }
  
  Widget _buildFilterToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Closed (left)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _filter = TicketFilter.closed),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: _filter == TicketFilter.closed 
                        ? AppColors.dangerBright 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'Closed',
                      style: TextStyle(
                        color: _filter == TicketFilter.closed 
                            ? Colors.white 
                            : Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Open (right)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _filter = TicketFilter.open),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: _filter == TicketFilter.open 
                        ? AppColors.accent 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'Open',
                      style: TextStyle(
                        color: _filter == TicketFilter.open 
                            ? Colors.white 
                            : Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTicket(Ticket ticket) {
    // Show detail view within the same page (keeps dashboard frame)
    setState(() => _selectedTicket = ticket);
  }
  
  void _closeDetailView() {
    setState(() => _selectedTicket = null);
  }

  void _closeTicket(Ticket ticket) {
    // Mark ticket as complete
    final updated = ticket.copyWith(status: TicketStatus.complete);
    setState(() {
      final index = _tickets.indexWhere((t) => t.id == ticket.id);
      if (index != -1) {
        _tickets[index] = updated;
      }
    });
    // Sync to robot
    widget.rosBridge.publishUpdateTicket(updated.toJson());
  }

  void _reopenTicket(Ticket ticket) {
    // Reopen a closed ticket
    final updated = ticket.copyWith(status: TicketStatus.open);
    setState(() {
      final index = _tickets.indexWhere((t) => t.id == ticket.id);
      if (index != -1) {
        _tickets[index] = updated;
      }
    });
    // Sync to robot
    widget.rosBridge.publishUpdateTicket(updated.toJson());
  }

  void _deliverTicket(Ticket ticket) {
    // Show delivery modal with location and task selection
    _showDeliverModal(ticket);
  }

  void _showDeliverModal(Ticket ticket) {
    // Default to ticket's creation location, but validate it exists in waypoints
    String? selectedLocation = ticket.locationName;
    final waypointNames = _waypoints.map((w) => w.name).toSet();
    if (selectedLocation != null && !waypointNames.contains(selectedLocation)) {
      selectedLocation = null;  // Invalid, reset
    }
    if (selectedLocation == null && _waypoints.isNotEmpty) {
      selectedLocation = _waypoints.first.name;
    }
    
    // Use last delivery task, but validate it exists in sequences
    String? selectedTask = _lastDeliveryTask;
    final sequenceNames = _sequences.map((s) => s.name).toSet();
    if (selectedTask != null && !sequenceNames.contains(selectedTask)) {
      selectedTask = null;  // Invalid, reset
    }
    if (selectedTask == null && _sequences.isNotEmpty) {
      // Look for a task with "Deliver" in the name (case-insensitive)
      final deliveryTask = _sequences.where(
        (s) => s.name.toLowerCase().contains('deliver')
      ).firstOrNull;
      selectedTask = deliveryTask?.name ?? _sequences.first.name;
    }
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Delivery icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    color: AppColors.success,
                    size: 32,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Deliver Ticket',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Items: ${ticket.items.join(", ")}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.lg),
                
                // Location dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.accent, size: 20),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedLocation,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF2A2A2A),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            icon: Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.5)),
                            hint: Text(
                              'Select Location',
                              style: TextStyle(color: Colors.white.withOpacity(0.5)),
                            ),
                            items: _waypoints.map((wp) => DropdownMenuItem(
                              value: wp.name,
                              child: Text(wp.name),
                            )).toList(),
                            onChanged: (value) {
                              setDialogState(() => selectedLocation = value);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                
                // Task dropdown  
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment, color: AppColors.success, size: 20),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedTask,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF2A2A2A),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            icon: Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.5)),
                            hint: Text(
                              'Select Task',
                              style: TextStyle(color: Colors.white.withOpacity(0.5)),
                            ),
                            items: _sequences.map((seq) => DropdownMenuItem(
                              value: seq.name,
                              child: Text(seq.name),
                            )).toList(),
                            onChanged: (value) {
                              setDialogState(() => selectedTask = value);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (selectedLocation != null)
                            ? () {
                                Navigator.pop(context);
                                // Save selected task for next time
                                if (selectedTask != null) {
                                  _lastDeliveryTask = selectedTask;
                                }
                                // Execute delivery
                                _executeDelivery(
                                  ticket: ticket,
                                  locationName: selectedLocation!,
                                  taskName: selectedTask,
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.success.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Deliver', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _executeDelivery({
    required Ticket ticket,
    required String locationName,
    String? taskName,
  }) {
    // Close the ticket
    _closeTicket(ticket);
    
    // Build workflow steps
    // Robot handles showing face and 3-second delay before navigation
    final List<Map<String, String>> steps = [];
    
    // Step 1: Navigate to delivery location (where order was taken)
    steps.add({'type': 'navigate', 'value': locationName});
    
    // Step 2: Run the selected Task (which includes action + navigation steps)
    if (taskName != null) {
      final sequence = _sequences.where((s) => s.name == taskName).firstOrNull;
      if (sequence != null) {
        // Get sets of known names for type detection
        final waypointNames = _waypoints.map((w) => w.name).toSet();
        
        // Process each step in the task, detecting its type
        for (final stepName in sequence.waypointNames) {
          if (waypointNames.contains(stepName)) {
            // It's a waypoint - navigate
            steps.add({'type': 'navigate', 'value': stepName});
          } else {
            // Assume it's an action (AI conversation)
            steps.add({'type': 'action', 'value': stepName});
          }
        }
      }
    }
    
    // Publish workflow with ticket context (for template variables like {ticket.items})
    widget.rosBridge.publishWorkflow(steps, ticket: ticket);
    
    // Track navigation target for location service
    LocationService.instance.setNavigatingTo(locationName);
  }

  void _deleteTicket(Ticket ticket) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.dangerBright.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.dangerBright,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Delete Ticket?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This will permanently delete "${ticket.title.isEmpty ? 'Untitled Ticket' : ticket.title}".',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _tickets.removeWhere((t) => t.id == ticket.id);
                        });
                        // Delete from robot
                        widget.rosBridge.publishDeleteTicket(ticket.id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dangerBright,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // Show edit view if editing
    if (_selectedTicket != null && _isEditing) {
      return _buildEditView();
    }
    
    // Show detail view if a ticket is selected
    if (_selectedTicket != null) {
      return _buildDetailView();
    }
    
    // Show list view
    return _buildListView();
  }
  
  Widget _buildListView() {
    return Container(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            // Top bar card (dashboard style)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Row 1: Title + Search (truly centered) + Refresh
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Search field (truly centered, wider)
                      Container(
                        width: 280,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: AppSpacing.sm),
                            Icon(Icons.search, color: AppColors.textMuted, size: 18),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Search...',
                                  hintStyle: TextStyle(color: AppColors.textMuted),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: _clearSearch,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                                  child: Icon(Icons.close, color: AppColors.textMuted, size: 18),
                                ),
                              ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                        ),
                      ),
                      // Title on left, Refresh on right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Title with padding
                          const Padding(
                            padding: EdgeInsets.only(left: AppSpacing.xs),
                            child: Text(
                              'AI Tickets',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // Refresh button
                          GestureDetector(
                            onTap: clearAllTickets,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(AppRadius.small),
                              ),
                              child: const Icon(Icons.refresh, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Row 2: Filter toggle (Closed / Open)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        // Closed
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _filter = TicketFilter.closed),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _filter == TicketFilter.closed 
                                    ? AppColors.dangerBright 
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  'Closed',
                                  style: TextStyle(
                                    color: _filter == TicketFilter.closed 
                                        ? Colors.white 
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Open
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _filter = TicketFilter.open),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _filter == TicketFilter.open 
                                    ? AppColors.accent 
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  'Open',
                                  style: TextStyle(
                                    color: _filter == TicketFilter.open 
                                        ? Colors.white 
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.sm),
            
            // Tickets list (cards float on surface)
            Expanded(
              child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : _filteredTickets.isEmpty
                            ? _buildEmptyState()
                            : _filteredTickets.isEmpty && _searchQuery.isNotEmpty
                                ? _buildSearchEmptyState()
                                : ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: _filteredTickets.length,
                                    itemBuilder: (context, index) {
                                      final ticket = _filteredTickets[index];
                                      return _TicketCard(
                                        ticket: ticket,
                                        onOpen: () => _openTicket(ticket),
                                        onClose: () => _closeTicket(ticket),
                                        onReopen: () => _reopenTicket(ticket),
                                        onDeliver: () => _deliverTicket(ticket),
                                        onDelete: () => _deleteTicket(ticket),
                                      );
                                    },
                                  ),
            ),
            
            // Status text
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                '${_tickets.length} tickets',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailView() {
    final ticket = _selectedTicket!;
    final isOpen = ticket.status == TicketStatus.open || ticket.status == TicketStatus.inProgress;
    
    return Container(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // Single header row: back, icon, title, logo, edit, close, deliver, delete
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: _closeDetailView,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.dangerBright,
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Ticket icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: AppColors.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Title
                    Expanded(
                      child: Text(
                        ticket.title.startsWith('Ticket #') 
                            ? 'AI ${ticket.title}'
                            : 'AI Ticket',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Edit button
                    _buildDetailActionButton(
                      label: 'Edit',
                      color: AppColors.accent,
                      onTap: () => _openEditPage(ticket),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    // Close/Open button
                    _buildDetailActionButton(
                      label: isOpen ? 'Close' : 'Open',
                      color: isOpen ? AppColors.dangerBright : AppColors.success,
                      onTap: isOpen 
                          ? () { _closeTicket(ticket); _closeDetailView(); }
                          : () => _reopenTicket(ticket),
                    ),
                    // Deliver button (only for open)
                    if (isOpen) ...[
                      const SizedBox(width: AppSpacing.xs),
                      _buildDetailActionButton(
                        label: 'Deliver',
                        color: AppColors.success,
                        onTap: () => _showDeliverModal(ticket),
                        solid: true,
                      ),
                    ],
                    const SizedBox(width: AppSpacing.xs),
                    // Delete button
                    GestureDetector(
                      onTap: () { _deleteTicket(ticket); _closeDetailView(); },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.dangerBright,
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppSpacing.sm),
              
              // Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                color: Colors.white.withOpacity(0.1),
              ),
              
              // Ticket number + timestamp
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Text(
                      'Ticket #${ticket.ticketNumber}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Text(
                      _formatDetailDate(ticket.timestamp),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Items list
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ticket.items.isNotEmpty)
                        ...ticket.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    color: Colors.white,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                      else
                        Text(
                          'No items',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool solid = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: EdgeInsets.symmetric(
          horizontal: solid ? AppSpacing.xl : AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: solid ? color : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: solid ? null : Border.all(color: color, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: solid ? Colors.white : color,
          ),
        ),
      ),
    );
  }
  
  String _formatDetailDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:${date.minute.toString().padLeft(2, '0')} $period';

    if (difference.inDays == 0) {
      return 'Today at $timeStr';
    } else if (difference.inDays == 1) {
      return 'Yesterday at $timeStr';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
  
  void _openEditPage(Ticket ticket) {
    setState(() {
      _selectedTicket = ticket;
      _isEditing = true;
    });
  }
  
  void _closeEditView() {
    setState(() => _isEditing = false);
  }
  
  // Form controllers for edit view
  final _editTitleController = TextEditingController();
  final _editItemsController = TextEditingController();
  TicketStatus _editStatus = TicketStatus.open;
  
  Widget _buildEditView() {
    final ticket = _selectedTicket!;
    
    // Initialize controllers if needed
    if (_editTitleController.text.isEmpty && ticket.title.isNotEmpty) {
      _editTitleController.text = ticket.title;
      _editItemsController.text = ticket.items.join('\n');
      _editStatus = ticket.status;
    }
    
    return Container(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // Header row: back, title
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () {
                        _editTitleController.clear();
                        _editItemsController.clear();
                        _closeEditView();
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.dangerBright,
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Title
                    Expanded(
                      child: Text(
                        ticket.title.startsWith('Ticket #') 
                            ? 'Edit AI ${ticket.title}'
                            : 'Edit AI Ticket',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    // Save button
                    GestureDetector(
                      onTap: _saveEditedTicket,
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    // Delete button
                    GestureDetector(
                      onTap: () {
                        _deleteTicket(ticket);
                        _editTitleController.clear();
                        _editItemsController.clear();
                        setState(() {
                          _selectedTicket = null;
                          _isEditing = false;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.dangerBright,
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Form content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title field
                      const Text(
                        'Title',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _editTitleController,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Order #...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(AppSpacing.md),
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.lg),
                      
                      // Status dropdown
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<TicketStatus>(
                            value: _editStatus,
                            isExpanded: true,
                            dropdownColor: AppColors.surface,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            items: TicketStatus.values.map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(status.displayName),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _editStatus = value);
                              }
                            },
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.lg),
                      
                      // Items field
                      const Text(
                        'Items (one per line)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _editItemsController,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 10,
                        decoration: InputDecoration(
                          hintText: 'Enter items...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(AppSpacing.md),
                        ),
                      ),
                      
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _saveEditedTicket() {
    final ticket = _selectedTicket!;
    
    // Parse items from text
    final items = _editItemsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    
    final updatedTicket = ticket.copyWith(
      title: _editTitleController.text.trim(),
      items: items,
      status: _editStatus,
    );
    
    // Update in list
    setState(() {
      final index = _tickets.indexWhere((t) => t.id == ticket.id);
      if (index != -1) {
        _tickets[index] = updatedTicket;
      }
      _selectedTicket = updatedTicket;
      _isEditing = false;
    });
    
    // Clear controllers
    _editTitleController.clear();
    _editItemsController.clear();
    
    // Sync to robot
    widget.rosBridge.publishUpdateTicket(updatedTicket.toJson());
  }

  Widget _buildEmptyState() {
    final isOpen = _filter == TicketFilter.open;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOpen ? Icons.receipt_long_outlined : Icons.check_circle_outline,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isOpen ? 'No Open Tickets' : 'No Closed Tickets',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isOpen ? 'New orders will appear here' : 'Completed orders will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No matching tickets',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Ticket ticket;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final VoidCallback onDeliver;
  final VoidCallback onDelete;

  const _TicketCard({
    required this.ticket,
    required this.onOpen,
    required this.onClose,
    required this.onReopen,
    required this.onDeliver,
    required this.onDelete,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $amPm';

    if (dateOnly == today) {
      return 'Today, $timeStr';
    } else if (dateOnly == yesterday) {
      return 'Yesterday, $timeStr';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = ticket.status == TicketStatus.open || ticket.status == TicketStatus.inProgress;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Ticket icon + Title + Action buttons
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ticket icon in grey circle
            Container(
                  width: 36,
                  height: 36,
              decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.white,
                    size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
                // Title (expanded)
                      Expanded(
                        child: Text(
                    ticket.title.isEmpty ? 'Untitled Ticket' : ticket.title,
                          style: const TextStyle(
                      fontSize: 18,
                            fontWeight: FontWeight.bold,
                      color: Colors.white,
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                        ),
                      ),
                // View button (blue) - opens full ticket view
                _ActionButton(
                  label: 'View',
                  color: AppColors.accent,
                  onTap: onOpen,
                ),
                const SizedBox(width: AppSpacing.xs),
                // Close/Open button - Close (orange) for open, Open (green) for closed
                _ActionButton(
                  label: isOpen ? 'Close' : 'Open',
                  color: isOpen ? AppColors.dangerBright : AppColors.success,
                  onTap: isOpen ? onClose : onReopen,
                ),
                // Deliver button (green) - only for open tickets
                if (isOpen) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _ActionButton(
                    label: 'Deliver',
                    color: AppColors.success,
                    onTap: onDeliver,
                    solid: true,
                  ),
                ],
                const SizedBox(width: AppSpacing.xs),
                // Delete button (orange circle)
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 36,
                    height: 36,
                        decoration: BoxDecoration(
                      color: AppColors.dangerBright,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
            
            const SizedBox(height: AppSpacing.md),
            
            // Divider
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.1),
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            // Ticket number (subtitle) + Date/time
            Row(
              children: [
                  Text(
                  'Ticket #${ticket.ticketNumber}',
                    style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                const SizedBox(width: AppSpacing.md),
                  Text(
                  _formatDate(ticket.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            
            // Items list
            if (ticket.items.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ...ticket.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small action button for ticket card
class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool solid;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: EdgeInsets.symmetric(
          horizontal: solid ? AppSpacing.xl : AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: solid ? color : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: solid ? null : Border.all(color: color, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: solid ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
