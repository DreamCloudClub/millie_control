import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/rosbridge.dart';
import '../widgets/top_notification.dart';
import 'action_editor_page.dart';

/// Locations page - Grid/List view of waypoints for quick navigation
class LocationsPage extends StatefulWidget {
  final RosBridge rosBridge;
  
  const LocationsPage({super.key, required this.rosBridge});

  // Static sequence that persists across page switches
  static List<Waypoint> sequence = [];
  
  // Static saved sequences (loaded from robot)
  static List<SavedSequence> savedSequences = [];
  
  // Static workflow state (persists across page switches)
  static WorkflowState workflowState = WorkflowState.editing;
  static int currentStep = 0;
  static int totalSteps = 0;
  static int stepOffset = 0;  // Offset for resumed workflows

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

enum WorkflowState { editing, running, stopped }
enum LeftPanelTab { points, actions, robot, tasks }

// Persisted tab selection across orientation changes
LeftPanelTab? _persistedLeftTab;

/// Step types for the task planner
enum StepType { navigate, prompt, display }

/// A single step in a task
class TaskStep {
  final StepType type;
  final String value;  // waypoint name, prompt name, or page name
  final String? label; // Display label
  
  TaskStep({required this.type, required this.value, this.label});
  
  String get displayLabel => label ?? value;
  
  // Get color based on step type
  Color get color {
    switch (type) {
      case StepType.navigate:
        return const Color(0xFF4CAF50);  // Green
      case StepType.prompt:
        return AppColors.dangerBright;  // Orange
      case StepType.display:
        return const Color(0xFF00BFFF);  // Cyan blue (AppColors.accent)
    }
  }
  
  // Get icon based on step type
  IconData get icon {
    switch (type) {
      case StepType.navigate:
        return Icons.location_on;
      case StepType.prompt:
        return Icons.chat_bubble;
      case StepType.display:
        return Icons.tablet_android;
    }
  }
}

/// Predefined actions (prompts and displays)
class ActionItem {
  final String name;
  final StepType type;
  final String? description;
  final List<TaskStep>? expandedSteps;  // For tasks that expand to multiple steps
  final bool isDefault;  // Default action for wake word / play button
  
  const ActionItem({
    required this.name,
    required this.type,
    this.description,
    this.expandedSteps,
    this.isDefault = false,
  });
  
  ActionItem copyWith({
    String? name,
    StepType? type,
    String? description,
    List<TaskStep>? expandedSteps,
    bool? isDefault,
  }) => ActionItem(
    name: name ?? this.name,
    type: type ?? this.type,
    description: description ?? this.description,
    expandedSteps: expandedSteps ?? this.expandedSteps,
    isDefault: isDefault ?? this.isDefault,
  );
}

class _LocationsPageState extends State<LocationsPage> {
  List<Waypoint> _waypoints = [];
  
  // Use static sequence from parent - now holds TaskSteps
  static List<TaskStep> _taskSteps = [];
  List<SavedSequence> get _savedSequences => LocationsPage.savedSequences;
  
  // Multi-listener callbacks (for cleanup)
  late final void Function(List<Waypoint>) _waypointListener;
  late final void Function(List<SavedSequence>) _sequenceListener;
  late final void Function(List<ActionDefinition>) _actionListener;
  late final void Function(String, int, int, List<Map<String, dynamic>>?) _workflowStatusListener;
  
  // Left panel tab - use persisted value
  LeftPanelTab get _leftTab => _persistedLeftTab ?? LeftPanelTab.points;
  set _leftTab(LeftPanelTab tab) => _persistedLeftTab = tab;
  
  // Tasks editing mode (was Routes)
  bool _isEditingTasks = false;
  
  // Points editing mode
  bool _isEditingPoints = false;
  
  // Actions editing mode (prompts)
  bool _isEditingActions = false;

  // Robot actions editing mode
  bool _isEditingRobotActions = false;

  // History editing mode
  bool _isEditingHistory = false;

  // History from robot
  List<HistoryEntry> _history = [];
  void Function(List<HistoryEntry>)? _historyListener;
  
  // Editable actions list - prompts only (static to persist, loaded from robot)
  static List<ActionItem> _actions = [];
  
  // Full action definitions from robot (for editing)
  static Map<String, ActionDefinition> _actionDefinitions = {};
  
  
  // Workflow execution state (use static from parent for persistence)
  WorkflowState get _workflowState => LocationsPage.workflowState;
  set _workflowState(WorkflowState value) => LocationsPage.workflowState = value;
  int get _currentStep => LocationsPage.currentStep;
  set _currentStep(int value) => LocationsPage.currentStep = value;
  int get _totalSteps => LocationsPage.totalSteps;
  set _totalSteps(int value) => LocationsPage.totalSteps = value;
  
  @override
  void initState() {
    super.initState();
    _setupWaypointsListener();
  }

  void _setupWaypointsListener() {
    // Multi-listener pattern - no more callback chaining needed!
    
    // Waypoints listener
    _waypointListener = (waypoints) {
      if (mounted) {
        setState(() => _waypoints = waypoints);
      }
    };
    widget.rosBridge.addWaypointListener(_waypointListener);
    
    // Workflow status listener (multi-listener pattern)
    _workflowStatusListener = (status, step, total, steps) {
      if (mounted) {
        setState(() {
          // Add offset for resumed workflows
          _currentStep = step + LocationsPage.stepOffset;
          _totalSteps = total + LocationsPage.stepOffset;
          
          // On 'started': clear old items and reload from robot
          if (status == 'started' && steps != null && steps.isNotEmpty) {
            _taskSteps.clear();
            for (final stepData in steps) {
              final type = stepData['type'] as String? ?? '';
              final value = stepData['value'] as String? ?? '';
              
              StepType stepType;
              switch (type) {
                case 'navigate':
                  stepType = StepType.navigate;
                  break;
                case 'action':
                  stepType = StepType.prompt;
                  break;
                case 'display':
                  stepType = StepType.display;
                  break;
                default:
                  stepType = StepType.navigate;
              }
              
              _taskSteps.add(TaskStep(
                type: stepType,
                value: value,
                label: value,
              ));
            }
            debugPrint('📥 Task Manager synced from robot: ${_taskSteps.length} steps');
          }
          // For other statuses: only populate if empty (late join scenario)
          else if (steps != null && steps.isNotEmpty && _taskSteps.isEmpty) {
            for (final stepData in steps) {
              final type = stepData['type'] as String? ?? '';
              final value = stepData['value'] as String? ?? '';
              
              StepType stepType;
              switch (type) {
                case 'navigate':
                  stepType = StepType.navigate;
                  break;
                case 'action':
                  stepType = StepType.prompt;
                  break;
                case 'display':
                  stepType = StepType.display;
                  break;
                default:
                  stepType = StepType.navigate;
              }
              
              _taskSteps.add(TaskStep(
                type: stepType,
                value: value,
                label: value,
              ));
            }
            debugPrint('📥 Task Manager populated (late join): ${_taskSteps.length} steps');
          }
          
          // Update workflow state
          if (status == 'started' || status == 'progress' || status == 'action' || status == 'display') {
            _workflowState = WorkflowState.running;
          } else if (status == 'complete') {
            _workflowState = WorkflowState.editing;
            _currentStep = 0;
            LocationsPage.stepOffset = 0;
            _taskSteps.clear();
          } else if (status == 'cancelled') {
            _workflowState = WorkflowState.stopped;
          }
        });
      }
    };
    widget.rosBridge.addWorkflowStatusListener(_workflowStatusListener);
    
    // Sequences listener (multi-listener pattern)
    _sequenceListener = (sequences) {
      if (mounted) {
        setState(() {
          // Merge instead of replace to preserve local order
          final existingNames = LocationsPage.savedSequences.map((s) => s.name).toSet();
          final incomingNames = sequences.map((s) => s.name).toSet();
          
          // Remove sequences that no longer exist on robot
          LocationsPage.savedSequences.removeWhere((s) => !incomingNames.contains(s.name));
          
          // Add new sequences that don't exist locally
          for (final seq in sequences) {
            if (!existingNames.contains(seq.name)) {
              LocationsPage.savedSequences.add(seq);
            }
          }
        });
      }
    };
    widget.rosBridge.addSequenceListener(_sequenceListener);
    
    // Actions listener (multi-listener pattern)
    _actionListener = (actions) {
      debugPrint('📥 Actions received from robot: ${actions.length}');
      for (final a in actions) {
        debugPrint('   - ${a.name}: isDefault=${a.isDefault}');
      }
      
      if (mounted) {
        setState(() {
          // Store full action definitions for editing
          _actionDefinitions = {for (var a in actions) a.name: a};
          
          // Rebuild actions list with isDefault from definitions
          _actions = actions.map((action) => ActionItem(
            name: action.name,
            type: StepType.prompt,
            description: action.description.isEmpty ? null : action.description,
            isDefault: action.isDefault,
          )).toList();
          
          // Sort so default action appears first
          _actions.sort((a, b) {
            if (a.isDefault && !b.isDefault) return -1;
            if (!a.isDefault && b.isDefault) return 1;
            return 0;
          });
          
          debugPrint('✅ Actions list updated, default action: ${_actions.where((a) => a.isDefault).map((a) => a.name).toList()}');
        });
      }
    };
    widget.rosBridge.addActionListener(_actionListener);

    // History listener
    _historyListener = (entries) {
      if (mounted) {
        setState(() => _history = entries);
      }
    };
    widget.rosBridge.addHistoryListener(_historyListener!);

    // Request initial data
    widget.rosBridge.requestWaypoints();
    widget.rosBridge.requestSequences();
    widget.rosBridge.requestActions();
    widget.rosBridge.requestHistory();
  }

  @override
  void didUpdateWidget(LocationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Don't re-setup listeners on widget update - they're already registered
  }
  
  @override
  void dispose() {
    // Multi-listener cleanup
    widget.rosBridge.removeWaypointListener(_waypointListener);
    widget.rosBridge.removeSequenceListener(_sequenceListener);
    widget.rosBridge.removeActionListener(_actionListener);
    widget.rosBridge.removeWorkflowStatusListener(_workflowStatusListener);
    if (_historyListener != null) {
      widget.rosBridge.removeHistoryListener(_historyListener!);
    }
    super.dispose();
  }

  void _addToSequence(Waypoint wp) {
    // Add waypoint as a navigate step
    setState(() {
      _taskSteps.add(TaskStep(
        type: StepType.navigate,
        value: wp.name,
        label: wp.name,
      ));
    });
  }

  void _removeFromSequence(int index) {
    setState(() => _taskSteps.removeAt(index));
  }

  void _clearSequence() {
    setState(() => _taskSteps.clear());
  }
  
  void _loadSequence(SavedSequence saved) {
    // Convert waypoint names to TaskSteps and APPEND to planner
    final steps = <TaskStep>[];
    for (final name in saved.waypointNames) {
      // Check if it's a waypoint
      final wp = _waypoints.where((w) => w.name == name).firstOrNull;
      if (wp != null) {
        steps.add(TaskStep(
          type: StepType.navigate,
          value: wp.name,
          label: wp.name,
        ));
      } else {
        // Could be an action (prompt) - check actions list
        final action = _actions.where((a) => a.name == name).firstOrNull;
        if (action != null) {
          steps.add(TaskStep(
            type: action.type,
            value: action.name,
            label: action.name,
          ));
        }
      }
    }
    // Append instead of replace
    setState(() {
      _taskSteps.addAll(steps);
    });
  }
  
  void _saveSequence() {
    if (_taskSteps.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Save Task', style: TextStyle(color: AppColors.textPrimary)),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Task name',
              hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  // Save step values (names of waypoints/actions)
                  final stepValues = _taskSteps.map((s) => s.value).toList();
                  widget.rosBridge.publishSaveSequence(name, stepValues);
                  
                  // Add locally too
                  setState(() {
                    LocationsPage.savedSequences.add(SavedSequence(
                      name: name,
                      waypointNames: stepValues,
                    ));
                  });
                  
                  Navigator.pop(context);
                  _showNotification('Saved "$name"');
                }
              },
              child: const Text('Save', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        );
      },
    );
  }
  
  void _deleteSequence(SavedSequence seq) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        title: Text('Delete "${seq.name}"?', style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'This task has ${seq.waypointNames.length} steps and will be permanently deleted.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      widget.rosBridge.publishDeleteSequence(seq.name);
      setState(() {
        LocationsPage.savedSequences.removeWhere((s) => s.name == seq.name);
      });
    }
  }

  void _executeSequence() {
    if (_taskSteps.isEmpty) return;
    
    // Reset offset for fresh start
    LocationsPage.stepOffset = 0;
    
    // Send full workflow to robot - map step types to robot format
    final steps = _taskSteps.map((step) => <String, String>{
      'type': _mapStepTypeForRobot(step.type),
      'value': step.value,
    }).toList();
    
    widget.rosBridge.publishWorkflow(steps);
    setState(() {
      _workflowState = WorkflowState.running;
      _currentStep = 0;
      _totalSteps = _taskSteps.length;
    });
  }

  void _stopWorkflow() {
    widget.rosBridge.publishWorkflowCancel();
    setState(() => _workflowState = WorkflowState.stopped);
  }

  void _resumeWorkflow() {
    // Resume from current step - set offset so UI shows correct position
    LocationsPage.stepOffset = _currentStep;
    
    final remainingSteps = _taskSteps.skip(_currentStep).map((step) => <String, String>{
      'type': _mapStepTypeForRobot(step.type),
      'value': step.value,
    }).toList();
    
    widget.rosBridge.publishWorkflow(remainingSteps);
    setState(() => _workflowState = WorkflowState.running);
  }
  
  /// Map UI step types to robot workflow step types
  String _mapStepTypeForRobot(StepType type) {
    switch (type) {
      case StepType.navigate:
        return 'navigate';
      case StepType.prompt:
        return 'action';  // Robot expects 'action' for AI conversation
      case StepType.display:
        return 'display';
    }
  }

  void _restartWorkflow() {
    _executeSequence();
  }

  void _showNotification(String message) {
    TopNotification.show(context, message: message, backgroundColor: AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isPortrait = orientation == Orientation.portrait;
        
        if (isPortrait) {
          return Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top: Tabs and content
                Expanded(
                  child: _buildLeftPanel(isPortrait: true),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Bottom: Task Manager
                Expanded(
                  child: _buildPlannerPanel(),
                ),
              ],
            ),
          );
        }
        
        // Landscape layout (original)
        return Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Sequences/Waypoints panel
              Expanded(
                flex: 3,
                child: _buildLeftPanel(isPortrait: false),
              ),
              const SizedBox(width: AppSpacing.lg),
              // Right: Navigation planner
              Expanded(
                flex: 2,
                child: _buildPlannerPanel(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeftPanel({bool isPortrait = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab toggle row - tabs on left, edit button on right
          Row(
            children: [
              // Tabs in a row
              _buildTabButton('Points', LeftPanelTab.points, compact: isPortrait),
              const SizedBox(width: AppSpacing.xs),
              _buildTabButton('Actions', LeftPanelTab.actions, compact: isPortrait),
              const SizedBox(width: AppSpacing.xs),
              _buildTabButton('Tasks', LeftPanelTab.tasks, compact: isPortrait),
              const SizedBox(width: AppSpacing.xs),
              _buildTabButton('Robot', LeftPanelTab.robot, compact: isPortrait),
              const Spacer(),
              // Edit button area (right-aligned)
              if (_leftTab == LeftPanelTab.points)
                _buildPointsEditSaveButton(compact: isPortrait),
              if (_leftTab == LeftPanelTab.actions) ...[
                _buildAddActionButton(compact: isPortrait),
                const SizedBox(width: AppSpacing.xs),
                _buildActionsEditSaveButton(compact: isPortrait),
              ],
              if (_leftTab == LeftPanelTab.tasks)
                _buildEditSaveButton(compact: isPortrait),
              if (_leftTab == LeftPanelTab.robot) ...[
                _buildRobotClearButton(compact: isPortrait),
                const SizedBox(width: AppSpacing.xs),
                _buildRobotEditButton(compact: isPortrait),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Content based on tab
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabButton(String label, LeftPanelTab tab, {bool compact = false}) {
    final isActive = _leftTab == tab;
    // Use different colors for different tabs
    Color activeColor;
    switch (tab) {
      case LeftPanelTab.points:
        activeColor = AppColors.success;  // Green
        break;
      case LeftPanelTab.actions:
        activeColor = AppColors.dangerBright;  // Orange
        break;
      case LeftPanelTab.tasks:
        activeColor = AppColors.accent;  // Blue
        break;
      case LeftPanelTab.robot:
        activeColor = AppColors.dangerBright;  // Orange to match actions
        break;
    }
    return GestureDetector(
      onTap: () => setState(() => _leftTab = tab),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.md : AppSpacing.md,
          vertical: compact ? AppSpacing.sm : AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(
            color: isActive ? activeColor : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : AppColors.textMuted,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTabContent() {
    switch (_leftTab) {
      case LeftPanelTab.points:
        return _buildWaypointsList();
      case LeftPanelTab.actions:
        return _buildActionsList(source: 'user');
      case LeftPanelTab.robot:
        return _buildActionsList(source: 'robot');
      case LeftPanelTab.tasks:
        return _buildSequencesList();
    }
  }
  
  Widget _buildEditSaveButton({bool compact = false}) {
    return GestureDetector(
      onTap: () {
        if (_isEditingTasks) {
          // Save the current order to the robot
          final orderedNames = LocationsPage.savedSequences.map((s) => s.name).toList();
          widget.rosBridge.publishReorderSequences(orderedNames);
        }
        setState(() => _isEditingTasks = !_isEditingTasks);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.md : AppSpacing.md,
          vertical: compact ? AppSpacing.sm : AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: _isEditingTasks 
              ? AppColors.success.withOpacity(0.15) 
              : AppColors.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(
            color: _isEditingTasks ? AppColors.success : AppColors.accent,
          ),
        ),
        child: Center(
          child: Text(
            _isEditingTasks ? 'Save' : 'Edit',
            style: TextStyle(
              color: _isEditingTasks ? AppColors.success : AppColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPointsEditSaveButton({bool compact = false}) {
    return GestureDetector(
      onTap: () {
        setState(() => _isEditingPoints = !_isEditingPoints);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.md : AppSpacing.md,
          vertical: compact ? AppSpacing.sm : AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: _isEditingPoints 
              ? AppColors.success.withOpacity(0.15) 
              : AppColors.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(
            color: _isEditingPoints ? AppColors.success : AppColors.accent,
          ),
        ),
        child: Center(
          child: Text(
            _isEditingPoints ? 'Save' : 'Edit',
            style: TextStyle(
              color: _isEditingPoints ? AppColors.success : AppColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAddActionButton({bool compact = false}) {
    return GestureDetector(
      onTap: () => _showAddActionDialog(),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.md : AppSpacing.md,
          vertical: compact ? AppSpacing.sm : AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(color: AppColors.success),
        ),
        child: Center(
          child: Icon(Icons.add, color: AppColors.success, size: compact ? 18 : 20),
        ),
      ),
    );
  }
  
  void _showAddActionDialog({ActionItem? existingAction}) {
    // Get full ActionDefinition from cache for editing
    ActionDefinition? existingDef;
    if (existingAction != null) {
      // Look up full definition from robot data
      existingDef = _actionDefinitions[existingAction.name];
      // Fallback to basic definition if not found (shouldn't happen)
      existingDef ??= ActionDefinition(
        name: existingAction.name,
        description: existingAction.description ?? '',
      );
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActionEditorPage(
          existingAction: existingDef,
          onSave: (action) {
            // Save to robot
            widget.rosBridge.publishSaveAction(action);
            
            setState(() {
              // Update full definition cache
              if (existingAction != null && existingAction.name != action.name) {
                // Name changed - remove old entry
                _actionDefinitions.remove(existingAction.name);
              }
              _actionDefinitions[action.name] = action;
              
              if (existingAction != null) {
                // Update existing action
                final index = _actions.indexWhere((a) => a.name == existingAction.name);
                if (index != -1) {
                  _actions[index] = ActionItem(
                    name: action.name,
                    type: StepType.prompt,
                    description: action.description.isEmpty ? null : action.description,
                    isDefault: action.isDefault,
                  );
                }
              } else {
                // Add new action
                _actions.add(ActionItem(
                  name: action.name,
                  type: StepType.prompt,
                  description: action.description.isEmpty ? null : action.description,
                  isDefault: action.isDefault,
                ));
              }
              
              // Resort so default appears first
              _actions.sort((a, b) {
                if (a.isDefault && !b.isDefault) return -1;
                if (!a.isDefault && b.isDefault) return 1;
                return 0;
              });
            });
          },
        ),
      ),
    );
  }
  
  Widget _buildActionsEditSaveButton({bool compact = false}) {
    return GestureDetector(
      onTap: () {
        if (_isEditingActions) {
          // Save the current order to the robot
          final orderedNames = _actions.map((a) => a.name).toList();
          widget.rosBridge.publishReorderActions(orderedNames);
        }
        setState(() => _isEditingActions = !_isEditingActions);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.md : AppSpacing.md,
          vertical: compact ? AppSpacing.sm : AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: _isEditingActions 
              ? AppColors.success.withOpacity(0.15) 
              : AppColors.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(
            color: _isEditingActions ? AppColors.success : AppColors.accent,
          ),
        ),
        child: Center(
          child: Text(
            _isEditingActions ? 'Save' : 'Edit',
            style: TextStyle(
              color: _isEditingActions ? AppColors.success : AppColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 13 : 14,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRobotClearButton({bool compact = false}) {
    // Get robot-generated actions
    final robotActions = _actions.where((action) {
      final def = _actionDefinitions[action.name];
      return def?.source == 'robot';
    }).toList();

    if (robotActions.isEmpty) return const SizedBox.shrink();

    // Clear all button for robot actions
    return GestureDetector(
      onTap: () {
        // Delete all robot-generated actions
        for (final action in robotActions) {
          widget.rosBridge.publishDeleteAction(action.name);
        }
        setState(() => _isEditingRobotActions = false);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.md : AppSpacing.md,
          vertical: compact ? AppSpacing.sm : AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(color: AppColors.danger),
        ),
        child: Text(
          'Clear',
          style: TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.bold,
            fontSize: compact ? 13 : 14,
          ),
        ),
      ),
    );
  }

  Widget _buildRobotEditButton({bool compact = false}) {
    return GestureDetector(
      onTap: () {
        setState(() => _isEditingRobotActions = !_isEditingRobotActions);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.md : AppSpacing.md,
          vertical: compact ? AppSpacing.sm : AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: _isEditingRobotActions
              ? AppColors.success.withOpacity(0.15)
              : AppColors.accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(
            color: _isEditingRobotActions ? AppColors.success : AppColors.accent,
          ),
        ),
        child: Text(
          _isEditingRobotActions ? 'Done' : 'Edit',
          style: TextStyle(
            color: _isEditingRobotActions ? AppColors.success : AppColors.accent,
            fontWeight: FontWeight.bold,
            fontSize: compact ? 13 : 14,
          ),
        ),
      ),
    );
  }
  
  
  void _deleteWaypoint(Waypoint wp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        title: Text('Delete "${wp.name}"?', style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'This point at (${wp.x.toStringAsFixed(2)}, ${wp.y.toStringAsFixed(2)}) will be permanently deleted.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
    }
  }
  
  void _setDefaultWaypoint(Waypoint wp) {
    debugPrint('📍 Setting default waypoint: ${wp.name}');
    
    // Optimistic local update - update UI immediately
    setState(() {
      for (int i = 0; i < _waypoints.length; i++) {
        final isNewDefault = _waypoints[i].name == wp.name;
        // Clear old default(s) and set new one
        if (_waypoints[i].isDefault || isNewDefault) {
          _waypoints[i] = _waypoints[i].copyWith(isDefault: isNewDefault);
        }
      }
      // Sort so default appears first
      _waypoints.sort((a, b) {
        if (a.isDefault && !b.isDefault) return -1;
        if (!a.isDefault && b.isDefault) return 1;
        return 0;
      });
    });
    
    // Send the full waypoint with isDefault=true directly (skip cache lookup)
    final updatedWp = wp.copyWith(isDefault: true);
    widget.rosBridge.publishUpdateWaypoint(updatedWp);
  }
  
  
  Widget _buildSequencesList() {
    if (_savedSequences.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 48,
              color: AppColors.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'No saved tasks',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Build a task and tap Save',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    
    if (_isEditingTasks) {
      // Edit mode: reorderable with drag handles and delete
      return ReorderableListView.builder(
        itemCount: _savedSequences.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = LocationsPage.savedSequences.removeAt(oldIndex);
            LocationsPage.savedSequences.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final seq = _savedSequences[index];
          return _SavedSequenceCard(
            key: ValueKey(seq.name),
            sequence: seq,
            isEditing: true,
            onTap: () => _loadSequence(seq),
            onDelete: () => _deleteSequence(seq),
          );
        },
      );
    } else {
      // Default mode: simple list with Load button
      return ListView.builder(
        itemCount: _savedSequences.length,
        itemBuilder: (context, index) {
          final seq = _savedSequences[index];
          return _SavedSequenceCard(
            key: ValueKey(seq.name),
            sequence: seq,
            isEditing: false,
            onTap: () => _loadSequence(seq),
            onDelete: () => _deleteSequence(seq),
          );
        },
      );
    }
  }

  Widget _buildWaypointsList() {
    if (_waypoints.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 48,
              color: AppColors.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'No saved points',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Add points from the Map page',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    
    if (_isEditingPoints) {
      // Edit mode: reorderable with drag handles and delete
      return ReorderableListView.builder(
        itemCount: _waypoints.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = _waypoints.removeAt(oldIndex);
            _waypoints.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final wp = _waypoints[index];
          return _SavedWaypointCard(
            key: ValueKey(wp.name),
            waypoint: wp,
            isEditing: true,
            onTap: () => _addToSequence(wp),
            onDelete: () => _deleteWaypoint(wp),
            onSetDefault: () => _setDefaultWaypoint(wp),
          );
        },
      );
    } else {
      // Default mode: list with Add button
      return ListView.builder(
        itemCount: _waypoints.length,
        itemBuilder: (context, index) {
          final wp = _waypoints[index];
          return _SavedWaypointCard(
            key: ValueKey(wp.name),
            waypoint: wp,
            isEditing: false,
            onTap: () => _addToSequence(wp),
            onDelete: () => _deleteWaypoint(wp),
            onSetDefault: () => _setDefaultWaypoint(wp),
          );
        },
      );
    }
  }
  
  Widget _buildActionsList({String source = 'user'}) {
    // Filter actions by source using the full definitions
    final filteredActions = _actions.where((action) {
      final def = _actionDefinitions[action.name];
      return def?.source == source;
    }).toList();

    if (filteredActions.isEmpty) {
      final label = source == 'robot' ? 'robot-generated' : 'saved';
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              source == 'robot' ? Icons.smart_toy : Icons.chat_bubble_outline,
              size: 48,
              color: AppColors.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No $label actions',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    final isEditing = (source == 'user' && _isEditingActions) ||
                       (source == 'robot' && _isEditingRobotActions);

    if (isEditing) {
      // Edit mode: show edit and delete buttons
      return ListView.builder(
        itemCount: filteredActions.length,
        itemBuilder: (context, index) {
          final action = filteredActions[index];
          return _ActionCard(
            key: ValueKey(action.name),
            action: action,
            isEditing: true,
            onTap: () => _addActionToPlanner(action),
            onEdit: () => _showAddActionDialog(existingAction: action),
            onDelete: () => _deleteAction(action),
          );
        },
      );
    } else {
      // Default mode: simple list with Load button
      return ListView.builder(
        itemCount: filteredActions.length,
        itemBuilder: (context, index) {
          final action = filteredActions[index];
          return _ActionCard(
            key: ValueKey(action.name),
            action: action,
            isEditing: false,
            onTap: () => _addActionToPlanner(action),
            onDelete: () => _deleteAction(action),
            showDefaultButton: source == 'user',
            onSetDefault: () => _setDefaultAction(action),
          );
        },
      );
    }
  }
  
  void _setDefaultAction(ActionItem action) {
    debugPrint('🎯 Setting default action: ${action.name}');
    debugPrint('📦 Available definitions: ${_actionDefinitions.keys.toList()}');
    
    // Get the full action definition
    final actionDef = _actionDefinitions[action.name];
    if (actionDef == null) {
      debugPrint('❌ Action definition not found for: ${action.name}');
      return;
    }
    
    debugPrint('✅ Found action definition, current isDefault: ${actionDef.isDefault}');
    
    // Create updated definition with isDefault = true
    final updatedDef = actionDef.copyWith(isDefault: true);
    
    debugPrint('📤 Publishing action with isDefault: ${updatedDef.isDefault}');
    
    // Publish the update - robot will clear other defaults
    widget.rosBridge.publishSaveAction(updatedDef);
  }
  
  void _addActionToPlanner(ActionItem action) {
    setState(() {
      _taskSteps.add(TaskStep(
        type: action.type,
        value: action.name,
        label: action.name,
      ));
    });
  }
  
  void _deleteAction(ActionItem action) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        title: Text('Delete "${action.name}"?', style: const TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This action will be removed from the list.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      // Delete from robot
      widget.rosBridge.publishDeleteAction(action.name);
      
      setState(() {
        _actions.removeWhere((a) => a.name == action.name);
      });
    }
  }
  
  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: AppColors.textMuted.withOpacity(0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'No history yet',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Tasks and actions will appear here',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // Show history in reverse chronological order (newest first)
    final sortedHistory = List<HistoryEntry>.from(_history)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.builder(
      itemCount: sortedHistory.length,
      itemBuilder: (context, index) {
        final entry = sortedHistory[index];
        return _HistoryCard(
          key: ValueKey(entry.timestamp),
          entry: entry,
          isEditing: _isEditingHistory,
          onDelete: () {
            widget.rosBridge.publishDeleteHistoryEntry(entry.timestamp.toIso8601String());
            setState(() {
              _history.removeWhere((h) => h.timestamp == entry.timestamp);
            });
          },
        );
      },
    );
  }

  Widget _buildPlannerPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment, color: AppColors.accent, size: 20),
                const SizedBox(width: AppSpacing.sm),
                const Text(
                  'Task Manager',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_taskSteps.isNotEmpty)
                  Text(
                    '${_taskSteps.length} steps',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          // Task steps list
          Expanded(
            child: _taskSteps.isEmpty
                ? Center(
                    child: Text(
                      'Add points or actions to build a task',
                      style: TextStyle(
                        color: AppColors.textMuted.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  )
                : _workflowState == WorkflowState.editing
                    ? ReorderableListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        itemCount: _taskSteps.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _taskSteps.removeAt(oldIndex);
                            _taskSteps.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final step = _taskSteps[index];
                          return _TaskStepItem(
                            key: ValueKey('${step.value}_$index'),
                            index: index,
                            step: step,
                            onRemove: () => _removeFromSequence(index),
                            isActive: false,
                            isEditing: true,
                          );
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        itemCount: _taskSteps.length,
                        itemBuilder: (context, index) {
                          final step = _taskSteps[index];
                          return _TaskStepItem(
                            key: ValueKey('${step.value}_$index'),
                            index: index,
                            step: step,
                            onRemove: () {},
                            isActive: index == _currentStep,
                            isEditing: false,
                          );
                        },
                      ),
          ),
          // Action buttons - change based on workflow state
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: _buildActionButtons(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    switch (_workflowState) {
      case WorkflowState.editing:
        return Row(
          children: [
            // Save button (moved to left)
            Expanded(
              child: GestureDetector(
                onTap: _taskSteps.isEmpty ? null : _saveSequence,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.5),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Save',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Go button (widest)
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _taskSteps.isEmpty ? null : _executeSequence,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'GO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Clear button (moved to right)
            Expanded(
              child: GestureDetector(
                onTap: _taskSteps.isEmpty ? null : _clearSequence,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(color: AppColors.dangerBright),
                  ),
                  child: const Center(
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: AppColors.dangerBright,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      
      case WorkflowState.running:
        // PAUSE button (orange)
        return GestureDetector(
          onTap: _stopWorkflow,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pause, color: Colors.white, size: 20),
                  SizedBox(width: 4),
                  Text(
                    'PAUSE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      
      case WorkflowState.stopped:
        // Restart (left), Resume (center/widest), Exit (right)
        return Row(
          children: [
            // Restart button - outline style like Clear
            Expanded(
              child: GestureDetector(
                onTap: _restartWorkflow,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.5),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Restart',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Resume button (widest) - solid green like Go
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _resumeWorkflow,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Resume',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Exit button - styled like Clear button but with orange
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _workflowState = WorkflowState.editing;
                  _currentStep = 0;
                  LocationsPage.stepOffset = 0;
                }),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(color: AppColors.dangerBright),
                  ),
                  child: const Center(
                    child: Text(
                      'Exit',
                      style: TextStyle(
                        color: AppColors.dangerBright,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.place_outlined,
            size: 48,
            color: AppColors.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No locations saved',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Add waypoints from the Map page',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Saved sequence card
class _SavedSequenceCard extends StatelessWidget {
  final SavedSequence sequence;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SavedSequenceCard({
    super.key,
    required this.sequence,
    required this.isEditing,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEditing ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Drag handle (edit mode only)
            if (isEditing) ...[
              const Icon(Icons.drag_handle, color: AppColors.textMuted, size: 20),
              const SizedBox(width: AppSpacing.sm),
            ],
            // Task icon (default blue)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: const Icon(Icons.assignment, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            // Task info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sequence.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sequence.waypointNames.length} steps: ${sequence.waypointNames.join(' → ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Delete button (edit mode) or Load button (default mode)
            if (isEditing)
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
              )
            else
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(color: AppColors.accent),
                  ),
                  child: const Text(
                    'Load',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Saved waypoint card
class _SavedWaypointCard extends StatelessWidget {
  final Waypoint waypoint;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onSetDefault;

  const _SavedWaypointCard({
    super.key,
    required this.waypoint,
    required this.isEditing,
    required this.onTap,
    required this.onDelete,
    this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEditing ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: waypoint.isDefault ? const Color(0xFF4CAF50) : AppColors.border,
            width: waypoint.isDefault ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Drag handle (edit mode only)
            if (isEditing) ...[
              const Icon(Icons.drag_handle, color: AppColors.textMuted, size: 20),
              const SizedBox(width: AppSpacing.sm),
            ],
            // Location icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: const Icon(Icons.location_on, color: Color(0xFF4CAF50), size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            // Waypoint info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    waypoint.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '(${waypoint.x.toStringAsFixed(2)}, ${waypoint.y.toStringAsFixed(2)})',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Edit mode: delete button only
            if (isEditing)
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
              )
            // Non-edit mode: Default status / Set Default button + Load button
            else ...[
              // Default status (blue) or Set Default button (orange) - on LEFT
              waypoint.isDefault
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: const Text(
                        'Default',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: onSetDefault,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBright.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                          border: Border.all(color: AppColors.dangerBright),
                        ),
                        child: const Text(
                          'Set Default',
                          style: TextStyle(
                            color: AppColors.dangerBright,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
              const SizedBox(width: AppSpacing.sm),
              // Load button - on RIGHT
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(color: const Color(0xFF4CAF50)),
                  ),
                  child: const Text(
                    'Load',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Action card for the actions list
class _ActionCard extends StatelessWidget {
  final ActionItem action;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRun;
  final VoidCallback? onSetDefault;
  final bool showDelete;
  final bool showDefaultButton;

  const _ActionCard({
    super.key,
    required this.action,
    required this.isEditing,
    required this.onTap,
    this.onEdit,
    required this.onDelete,
    this.onRun,
    this.onSetDefault,
    this.showDelete = true,
    this.showDefaultButton = false,
  });

  Color get _color {
    switch (action.type) {
      case StepType.navigate:
        return const Color(0xFF4CAF50);  // Green
      case StepType.prompt:
        return AppColors.dangerBright;  // Orange
      case StepType.display:
        return const Color(0xFF00BFFF);  // Cyan blue (AppColors.accent)
    }
  }

  IconData get _icon {
    switch (action.type) {
      case StepType.navigate:
        return Icons.location_on;
      case StepType.prompt:
        return Icons.chat_bubble;
      case StepType.display:
        return Icons.tablet_android;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEditing ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: action.isDefault ? AppColors.dangerBright : AppColors.border,
            width: action.isDefault ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Drag handle (edit mode only)
            if (isEditing) ...[
              const Icon(Icons.drag_handle, color: AppColors.textMuted, size: 20),
              const SizedBox(width: AppSpacing.sm),
            ],
            // Action icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(_icon, color: _color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            // Action info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (action.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      action.description!,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Edit + Delete buttons (edit mode) or Load + Default buttons (default mode)
            if (isEditing) ...[
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 20),
                ),
              if (onEdit != null && showDelete)
                const SizedBox(width: AppSpacing.md),
              if (showDelete)
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
                ),
            ] else ...[
              // Default status / Set Default button (only for actions, not displays) - on LEFT
              if (showDefaultButton) ...[
                action.isDefault
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: const Text(
                          'Default',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: onSetDefault,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(AppRadius.small),
                            border: Border.all(color: AppColors.accent),
                          ),
                          child: const Text(
                            'Set Default',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                const SizedBox(width: AppSpacing.sm),
              ],
              // Load button - stays on RIGHT
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(color: _color),
                  ),
                  child: Text(
                    'Load',
                    style: TextStyle(
                      color: _color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Task step item in the planner
class _TaskStepItem extends StatelessWidget {
  final int index;
  final TaskStep step;
  final VoidCallback onRemove;
  final bool isActive;
  final bool isEditing;

  const _TaskStepItem({
    super.key,
    required this.index,
    required this.step,
    required this.onRemove,
    this.isActive = false,
    this.isEditing = true,
  });

  @override
  Widget build(BuildContext context) {
    final stepColor = step.color;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isActive ? stepColor.withOpacity(0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(
          color: isActive ? stepColor : AppColors.border,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Drag handle (only in editing mode)
          if (isEditing)
            const Icon(Icons.drag_handle, color: AppColors.textMuted, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: AppSpacing.sm),
          // Step type icon with number
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? stepColor : stepColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Icon(
                step.icon,
                color: isActive ? Colors.white : stepColor,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Step number
          Text(
            '${index + 1}.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Name
          Expanded(
            child: Text(
              step.displayLabel,
              style: TextStyle(
                color: isActive ? stepColor : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          // Remove button (only in editing mode)
          if (isEditing)
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
            ),
          // Active indicator
          if (isActive)
            Icon(Icons.arrow_forward, color: stepColor, size: 18),
        ],
      ),
    );
  }
}

/// Location card - used in both grid and list modes
class _LocationCard extends StatelessWidget {
  final Waypoint waypoint;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isGridMode;

  const _LocationCard({
    required this.waypoint,
    required this.isSelected,
    required this.onTap,
    required this.isGridMode,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseColor = AppColors.accent;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: isGridMode ? null : 64,
        decoration: BoxDecoration(
          color: isSelected 
              ? baseColor.withOpacity(0.2) 
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: isSelected 
                ? baseColor 
                : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: baseColor.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: isGridMode ? _buildGridContent() : _buildListContent(),
      ),
    );
  }

  Widget _buildGridContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.place,
          color: isSelected ? AppColors.accent : AppColors.textSecondary,
          size: 32,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          waypoint.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected ? AppColors.accent : AppColors.textPrimary,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildListContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Icon(
            Icons.place,
            color: isSelected ? AppColors.accent : AppColors.textSecondary,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              waypoint.name,
              style: TextStyle(
                color: isSelected ? AppColors.accent : AppColors.textPrimary,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (isSelected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: const Text(
                'Tap to GO',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// History entry card
class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final bool isEditing;
  final VoidCallback? onDelete;

  const _HistoryCard({
    super.key,
    required this.entry,
    this.isEditing = false,
    this.onDelete,
  });

  IconData get _icon {
    // Robot face icon for AI-generated entries
    if (entry.source == 'robot') {
      return Icons.smart_toy;
    }

    // Determine icon based on step types
    final types = entry.steps.map((s) => s.type).toSet();

    // Single navigate step = point/location
    if (types.length == 1 && types.contains('navigate')) {
      return Icons.location_on;
    }

    // Single action step = chat/action
    if (types.length == 1 && types.contains('action')) {
      return Icons.chat_bubble;
    }

    // Multiple steps or mixed = task
    if (entry.steps.length > 1) {
      return Icons.assignment;
    }

    // Display = tablet
    if (types.contains('display')) {
      return Icons.tablet_android;
    }

    // Default fallback
    return Icons.route;
  }

  Color get _color {
    // Robot = accent blue
    if (entry.source == 'robot') {
      return AppColors.accent;
    }

    // Match icon type to color
    final types = entry.steps.map((s) => s.type).toSet();

    if (types.length == 1 && types.contains('navigate')) {
      return const Color(0xFF4CAF50);  // Green for points
    }

    if (types.length == 1 && types.contains('action')) {
      return AppColors.dangerBright;  // Orange for actions
    }

    if (entry.steps.length > 1) {
      return AppColors.accent;  // Blue for tasks
    }

    return AppColors.accent;
  }

  String get _timeString {
    final now = DateTime.now();
    final diff = now.difference(entry.timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${entry.timestamp.month}/${entry.timestamp.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,  // Fixed height for consistency
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Type icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(_icon, color: _color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          // Content - show description and step count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.description,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Show step summary as compact chips
                Row(
                  children: [
                    ...entry.steps.take(3).map((step) {
                      Color chipColor;
                      IconData chipIcon;
                      switch (step.type) {
                        case 'navigate':
                          chipColor = const Color(0xFF4CAF50);
                          chipIcon = Icons.location_on;
                          break;
                        case 'action':
                          chipColor = AppColors.dangerBright;
                          chipIcon = Icons.chat_bubble;
                          break;
                        case 'display':
                          chipColor = AppColors.accent;
                          chipIcon = Icons.tablet_android;
                          break;
                        default:
                          chipColor = AppColors.textMuted;
                          chipIcon = Icons.circle;
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: chipColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(chipIcon, size: 10, color: chipColor),
                              const SizedBox(width: 4),
                              Text(
                                step.value,
                                style: TextStyle(
                                  color: chipColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (entry.steps.length > 3)
                      Text(
                        '+${entry.steps.length - 3}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Timestamp or delete button
          if (isEditing && onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
            )
          else
            Text(
              _timeString,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}
