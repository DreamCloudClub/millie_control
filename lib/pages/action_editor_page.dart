import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/rosbridge.dart';
import '../widgets/top_notification.dart';

/// Full-page editor for creating/editing Actions
class ActionEditorPage extends StatefulWidget {
  final ActionDefinition? existingAction;  // null = creating new
  final Function(ActionDefinition) onSave;
  final RosBridge rosBridge;  // For fetching agents
  
  const ActionEditorPage({
    super.key,
    this.existingAction,
    required this.onSave,
    required this.rosBridge,
  });

  @override
  State<ActionEditorPage> createState() => _ActionEditorPageState();
}

class _ActionEditorPageState extends State<ActionEditorPage> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _contextController;
  late TextEditingController _systemInstructionsController;
  late TextEditingController _openingGreetingController;
  late TextEditingController _confirmationController;
  
  late List<ConversationStep> _steps;
  
  List<AgentDefinition> _agents = [];
  String? _selectedAgentName;
  String? _pendingAgentName;  // Store original until agents load
  
  // Multi-listener callback (for cleanup)
  late final void Function(List<AgentDefinition>) _agentListener;
  
  bool get _isEditing => widget.existingAction != null;

  @override
  void initState() {
    super.initState();
    final action = widget.existingAction;
    
    _nameController = TextEditingController(text: action?.name ?? '');
    _descriptionController = TextEditingController(text: action?.description ?? '');
    _contextController = TextEditingController(text: action?.context ?? '');
    _systemInstructionsController = TextEditingController(text: action?.systemInstructions ?? '');
    _openingGreetingController = TextEditingController(text: action?.openingGreeting ?? '');
    _confirmationController = TextEditingController(text: action?.confirmation ?? '');
    _steps = List.from(action?.steps ?? []);
    
    // Store the agent name - will be validated when agents load
    _pendingAgentName = action?.agentName.isNotEmpty == true ? action!.agentName : null;
    _selectedAgentName = null;  // Will be set when agents load
    
    _setupAgentsCallback();
    _requestAgents();
  }
  
  void _setupAgentsCallback() {
    // Multi-listener pattern
    _agentListener = (agents) {
      if (mounted) {
        setState(() {
          _agents = agents;
          // Restore pending agent selection if it exists in the loaded list
          if (_pendingAgentName != null && agents.any((a) => a.name == _pendingAgentName)) {
            _selectedAgentName = _pendingAgentName;
            _pendingAgentName = null;
          }
        });
      }
    };
    widget.rosBridge.addAgentListener(_agentListener);
  }
  
  void _requestAgents() {
    widget.rosBridge.requestAgents();
  }

  @override
  void dispose() {
    widget.rosBridge.removeAgentListener(_agentListener);  // Multi-listener cleanup
    _nameController.dispose();
    _descriptionController.dispose();
    _contextController.dispose();
    _systemInstructionsController.dispose();
    _openingGreetingController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _addStep() {
    setState(() {
      _steps.add(ConversationStep(
        type: 'question',
        content: '',
        required: true,
      ));
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
  }

  void _updateStep(int index, ConversationStep step) {
    setState(() {
      _steps[index] = step;
    });
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final step = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, step);
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      TopNotification.show(context, message: 'Please enter an Action Title', backgroundColor: AppColors.danger);
      return;
    }
    
    // Use selected agent or pending (if agents haven't loaded yet)
    final agentName = _selectedAgentName ?? _pendingAgentName ?? '';
    
    // Preserve isDefault from existing action when editing
    final isDefault = widget.existingAction?.isDefault ?? false;
    
    final action = ActionDefinition(
      name: name,
      description: _descriptionController.text.trim(),
      agentName: agentName,
      context: _contextController.text.trim(),
      systemInstructions: _systemInstructionsController.text.trim(),
      openingGreeting: _openingGreetingController.text.trim(),
      steps: _steps,
      confirmation: _confirmationController.text.trim(),
      isDefault: isDefault,
    );
    
    widget.onSave(action);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Action' : 'New Action',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: GestureDetector(
              onTap: _save,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(color: AppColors.success),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name & Description
            _buildSection(
              title: 'Basic Info',
              icon: Icons.info_outline,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'Action Title',
                  hint: 'Enter the Action Title',
                  required: true,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Action Description',
                  hint: 'Enter a brief description of this action',
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // AI Agent & Context
            _buildSection(
              title: 'AI Context',
              icon: Icons.psychology,
              children: [
                // Agent dropdown
                _buildAgentDropdown(),
                const SizedBox(height: AppSpacing.md),
                _buildTextField(
                  controller: _contextController,
                  label: 'Additional Context',
                  hint: 'Extra context specific to this action (optional)',
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildTextField(
                  controller: _systemInstructionsController,
                  label: 'Additional Instructions',
                  hint: 'Extra behavior rules for this action (optional)',
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Opening Greeting
            _buildSection(
              title: 'Opening Greeting',
              icon: Icons.record_voice_over,
              children: [
                _buildTextField(
                  controller: _openingGreetingController,
                  label: 'Greeting',
                  hint: 'What the robot says first',
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Conversation Steps
            _buildSection(
              title: 'Conversation Flow',
              icon: Icons.format_list_numbered,
              trailing: IconButton(
                onPressed: _addStep,
                icon: const Icon(Icons.add_circle, color: AppColors.accent),
                tooltip: 'Add Step',
              ),
              children: [
                if (_steps.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        'No conversation steps added.\nTap + to add steps.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _steps.length,
                    onReorder: _reorderSteps,
                    itemBuilder: (context, index) {
                      return _StepCard(
                        key: ValueKey('step_$index'),
                        index: index,
                        step: _steps[index],
                        onUpdate: (step) => _updateStep(index, step),
                        onRemove: () => _removeStep(index),
                      );
                    },
                  ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Confirmation
            _buildSection(
              title: 'Confirmation',
              icon: Icons.check_circle_outline,
              children: [
                _buildTextField(
                  controller: _confirmationController,
                  label: 'Confirmation Statement',
                  hint: 'What the robot says to confirm and close',
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.xl * 2),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (trailing != null) ...[
              const Spacer(),
              trailing,
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildAgentDropdown() {
    // Show loading hint if we're waiting for agents to load and have a pending selection
    final isLoadingAgent = _pendingAgentName != null && _agents.isEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Agent',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _selectedAgentName,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              hint: Text(
                isLoadingAgent 
                    ? 'Loading: $_pendingAgentName...'
                    : 'Select an agent (optional)',
                style: TextStyle(color: isLoadingAgent ? AppColors.accent : AppColors.textMuted.withOpacity(0.5)),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('None', style: TextStyle(color: AppColors.textMuted)),
                ),
                ..._agents.map((agent) => DropdownMenuItem<String?>(
                  value: agent.name,
                  child: Row(
                    children: [
                      const Icon(Icons.psychology, color: AppColors.accent, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              agent.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (agent.description.isNotEmpty)
                              Text(
                                agent.description,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ],
              onChanged: (value) {
                setState(() => _selectedAgentName = value);
              },
            ),
          ),
        ),
        if (_agents.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'No agents configured. Create agents in Settings → AI Agents.',
              style: TextStyle(
                color: AppColors.textMuted.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    bool required = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(color: AppColors.danger, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5)),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.all(AppSpacing.md),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
              borderSide: const BorderSide(color: AppColors.accent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Card for a single conversation step
class _StepCard extends StatefulWidget {
  final int index;
  final ConversationStep step;
  final Function(ConversationStep) onUpdate;
  final VoidCallback onRemove;

  const _StepCard({
    super.key,
    required this.index,
    required this.step,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.step.content);
  }

  @override
  void didUpdateWidget(_StepCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.content != widget.step.content) {
      _contentController.text = widget.step.content;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          const Icon(Icons.drag_handle, color: AppColors.textMuted, size: 20),
          const SizedBox(width: AppSpacing.sm),
          
          // Step number
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '${widget.index + 1}',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type selector
                Row(
                  children: [
                    _TypeChip(
                      label: 'Question',
                      isSelected: widget.step.type == 'question',
                      onTap: () => widget.onUpdate(widget.step.copyWith(type: 'question')),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _TypeChip(
                      label: 'Statement',
                      isSelected: widget.step.type == 'statement',
                      onTap: () => widget.onUpdate(widget.step.copyWith(type: 'statement')),
                    ),
                    const Spacer(),
                    // Required toggle
                    GestureDetector(
                      onTap: () => widget.onUpdate(widget.step.copyWith(required: !widget.step.required)),
                      child: Row(
                        children: [
                          Icon(
                            widget.step.required ? Icons.check_box : Icons.check_box_outline_blank,
                            color: widget.step.required ? AppColors.accent : AppColors.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Required',
                            style: TextStyle(
                              color: widget.step.required ? AppColors.accent : AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                
                // Content text field
                TextField(
                  controller: _contentController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: widget.step.type == 'question' 
                        ? 'Enter question'
                        : 'Enter statement',
                    hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.5), fontSize: 14),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.all(AppSpacing.sm),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    widget.onUpdate(widget.step.copyWith(content: value));
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(width: AppSpacing.sm),
          
          // Remove button
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textMuted,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

