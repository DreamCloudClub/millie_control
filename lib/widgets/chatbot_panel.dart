// lib/widgets/chatbot_panel.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';
import '../utils/rosbridge.dart';
import '../services/openai_service.dart';
import '../services/navigation_tools.dart';

/// Chat input states
enum ChatInputState {
  empty,      // No text, show record button
  recording,  // Recording, show stop + send
  hasText,    // Has text, show send button
  processing, // AI is processing
}

/// Chat message model
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  
  ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// AI-powered chat with voice input/output and navigation commands
class ChatbotPanel extends StatefulWidget {
  final RosBridge rosBridge;
  
  // Static state for persistence across page switches
  static final List<ChatMessage> _messages = [];
  static final List<Map<String, dynamic>> _conversationHistory = [];
  static NavigationTools? _navTools;
  
  const ChatbotPanel({
    super.key,
    required this.rosBridge,
  });

  @override
  State<ChatbotPanel> createState() => _ChatbotPanelState();
}

class _ChatbotPanelState extends State<ChatbotPanel> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final OpenAIService _openAI = OpenAIService();
  
  ChatInputState _inputState = ChatInputState.empty;
  bool _isMuted = false;
  String? _recordingPath;
  
  // Use static state for persistence
  List<ChatMessage> get _messages => ChatbotPanel._messages;
  List<Map<String, dynamic>> get _conversationHistory => ChatbotPanel._conversationHistory;
  NavigationTools get _navTools {
    ChatbotPanel._navTools ??= NavigationTools(widget.rosBridge);
    return ChatbotPanel._navTools!;
  }

  // Listener functions for cleanup
  late final void Function(List<Waypoint>) _waypointListener;
  late final void Function(List<SavedSequence>) _sequenceListener;
  late final void Function(RobotPose) _poseListener;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    
    // Use new multi-listener pattern - no more callback chaining needed!
    _waypointListener = (waypoints) {
      _navTools.updateWaypoints(waypoints);
      debugPrint('🤖 [ChatbotPanel] Received ${waypoints.length} waypoints via multi-listener');
    };
    _sequenceListener = (sequences) {
      _navTools.updateRoutes(sequences);
      debugPrint('🤖 [ChatbotPanel] Received ${sequences.length} sequences via multi-listener');
    };
    _poseListener = (pose) {
      _navTools.updatePose(pose);
    };
    
    // Register with ROSBridge - will receive cached data immediately if available
    widget.rosBridge.addWaypointListener(_waypointListener);
    widget.rosBridge.addSequenceListener(_sequenceListener);
    widget.rosBridge.addPoseListener(_poseListener);
    
    // Request fresh data from robot
    widget.rosBridge.requestWaypoints();
    widget.rosBridge.requestSequences();
    
    // Check mic permission
    _checkMicPermission();
  }

  Future<void> _checkMicPermission() async {
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  @override
  void dispose() {
    // Unregister from multi-listeners
    widget.rosBridge.removeWaypointListener(_waypointListener);
    widget.rosBridge.removeSequenceListener(_sequenceListener);
    widget.rosBridge.removePoseListener(_poseListener);
    
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      if (_textController.text.isNotEmpty) {
        _inputState = ChatInputState.hasText;
      } else if (_inputState != ChatInputState.recording && 
                 _inputState != ChatInputState.processing) {
        _inputState = ChatInputState.empty;
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        debugPrint('Microphone permission denied');
        return;
      }
      
      final directory = await getTemporaryDirectory();
      _recordingPath = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: _recordingPath!,
      );
      
      setState(() {
        _inputState = ChatInputState.recording;
      });
      
      debugPrint('Recording started: $_recordingPath');
      
      // Auto-stop after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        if (_inputState == ChatInputState.recording) {
          _stopRecording();
        }
      });
    } catch (e) {
      debugPrint('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_inputState != ChatInputState.recording) return;
    
    try {
      final path = await _recorder.stop();
      debugPrint('Recording stopped: $path');
      
      setState(() {
        _inputState = ChatInputState.processing;
        _textController.text = "Transcribing...";
      });
      
      // Transcribe with Whisper
      if (path != null) {
        final transcription = await _openAI.speechToText(path);
        
        if (transcription != null && transcription.isNotEmpty) {
          setState(() {
            _textController.text = transcription;
            _inputState = ChatInputState.hasText;
          });
        } else {
          setState(() {
            _textController.clear();
            _inputState = ChatInputState.empty;
          });
        }
        
        // Clean up recording file
        try {
          await File(path).delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() {
        _textController.clear();
        _inputState = ChatInputState.empty;
      });
    }
  }

  Future<void> _sendMessage() async {
    // If still recording, stop and transcribe first
    if (_inputState == ChatInputState.recording) {
      await _stopRecording();
      // Wait for transcription before proceeding
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final messageText = _textController.text.trim();
    if (messageText.isEmpty || messageText == "Transcribing...") return;

    // Add user message to UI
    setState(() {
      _messages.add(ChatMessage(content: messageText, isUser: true));
      _textController.clear();
      _inputState = ChatInputState.processing;
    });
    
    _scrollToBottom();
    _focusNode.unfocus();

    // Add to conversation history
    _conversationHistory.add({
      'role': 'user',
      'content': messageText,
    });

    // Call OpenAI
    await _processWithAI();
  }

  Future<void> _processWithAI() async {
    if (!_openAI.hasApiKey) {
      _addAssistantMessage("I'm not configured yet. Please add your OpenAI API key to the app.");
      return;
    }

    try {
      // Call OpenAI with navigation tools
      var response = await _openAI.chatCompletion(
        systemPrompt: _navTools.buildSystemPrompt(),
        messages: _conversationHistory,
        tools: _navTools.getToolDefinitions(),
      );

      if (response == null) {
        _addAssistantMessage("Sorry, I couldn't process that request. Please try again.");
        return;
      }

      // Handle tool calls
      while (response != null && response.hasToolCalls) {
        for (final toolCall in response.toolCalls!) {
          final result = _navTools.executeTool(toolCall.name, toolCall.arguments);
          
          // Add tool call to history
          _conversationHistory.add({
            'role': 'assistant',
            'content': null,
            'tool_calls': [{
              'id': toolCall.id,
              'type': 'function',
              'function': {
                'name': toolCall.name,
                'arguments': jsonEncode(toolCall.arguments),
              },
            }],
          });
          
          // Add tool result to history
          _conversationHistory.add({
            'role': 'tool',
            'tool_call_id': toolCall.id,
            'content': result,
          });
        }
        
        // Get follow-up response after tool execution
        response = await _openAI.continueWithToolResults(
          systemPrompt: _navTools.buildSystemPrompt(),
          messages: _conversationHistory,
          tools: _navTools.getToolDefinitions(),
        );
      }

      // Add final response
      if (response != null && response.content.isNotEmpty) {
        _conversationHistory.add({
          'role': 'assistant',
          'content': response.content,
        });
        _addAssistantMessage(response.content);
      }
    } catch (e) {
      debugPrint('AI Error: $e');
      _addAssistantMessage("Sorry, something went wrong. Please try again.");
    }
  }

  void _addAssistantMessage(String content) {
    // Clean up the response
    final cleanContent = _cleanResponse(content);
    if (cleanContent.isEmpty) return;
    
    setState(() {
      _messages.add(ChatMessage(content: cleanContent, isUser: false));
      _inputState = ChatInputState.empty;
    });
    
    _scrollToBottom();
    
    // Play TTS if not muted
    if (!_isMuted) {
      _playTTS(cleanContent);
    }
  }
  
  /// Clean up AI response - remove markdown, special chars, etc.
  String _cleanResponse(String text) {
    var clean = text.trim();
    
    // Remove emojis and special Unicode characters that may not render
    clean = clean.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '');
    clean = clean.replaceAll(RegExp(r'[\u{2600}-\u{26FF}]', unicode: true), '');
    clean = clean.replaceAll(RegExp(r'[\u{2700}-\u{27BF}]', unicode: true), '');
    clean = clean.replaceAll(RegExp(r'[\u{FE00}-\u{FE0F}]', unicode: true), '');
    clean = clean.replaceAll(RegExp(r'[\u{1F000}-\u{1F02F}]', unicode: true), '');
    
    // Remove markdown bold/italic
    clean = clean.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
    clean = clean.replaceAll(RegExp(r'\*(.+?)\*'), r'$1');
    clean = clean.replaceAll(RegExp(r'__(.+?)__'), r'$1');
    clean = clean.replaceAll(RegExp(r'_(.+?)_'), r'$1');
    
    // Remove code blocks
    clean = clean.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    clean = clean.replaceAll(RegExp(r'`(.+?)`'), r'$1');
    
    // Remove markdown headers
    clean = clean.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');
    
    // Remove bullet points/lists formatting  
    clean = clean.replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '');
    clean = clean.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');
    
    // Remove any remaining non-printable characters
    clean = clean.replaceAll(RegExp(r'[^\x20-\x7E\n\r\t]'), '');
    
    // Remove extra whitespace
    clean = clean.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    clean = clean.replaceAll(RegExp(r'  +'), ' ');
    clean = clean.trim();
    
    return clean;
  }

  Future<void> _playTTS(String text) async {
    try {
      final audioPath = await _openAI.textToSpeech(text: text);
      if (audioPath != null) {
        await _audioPlayer.play(DeviceFileSource(audioPath));
        
        // Clean up after playback
        _audioPlayer.onPlayerComplete.first.then((_) {
          try {
            File(audioPath).delete();
          } catch (_) {}
        });
      }
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearConversation() {
    setState(() {
      _messages.clear();
      _conversationHistory.clear();
      _inputState = ChatInputState.empty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            // Header bar (top)
            _buildHeader(),
            
            const SizedBox(height: AppSpacing.sm),
            
            // Chat messages area (middle - transparent)
            Expanded(
              child: _messages.isEmpty ? _buildEmptyState() : _buildMessageList(),
            ),
            
            const SizedBox(height: AppSpacing.sm),
            
            // Input bar (bottom)
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.smart_toy, color: AppColors.accent, size: 20),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'AI Chat Control',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Clear/Refresh button
          GestureDetector(
            onTap: _clearConversation,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasApiKey = _openAI.hasApiKey;
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasApiKey ? Icons.smart_toy_outlined : Icons.key_off,
            color: AppColors.accent.withOpacity(0.5),
            size: 64,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            hasApiKey ? 'AI Chat Control' : 'API Key Required',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hasApiKey 
                ? 'Use the chatbot to control the robot.'
                : 'Add your OpenAI API key in\nopenai_service.dart',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _messages.length + (_inputState == ChatInputState.processing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          // Show typing indicator
          return const _TypingIndicator();
        }
        return _ChatBubble(message: _messages[index]);
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left button (mute/stop)
          _buildLeftButton(),
          
          const SizedBox(width: AppSpacing.sm),
          
          // Text input field
          Expanded(child: _buildTextField()),
          
          const SizedBox(width: AppSpacing.sm),
          
          // Right button (record/send)
          _buildRightButton(),
        ],
      ),
    );
  }

  Widget _buildLeftButton() {
    if (_inputState == ChatInputState.recording) {
      // Stop recording button
      return _InputButton(
        icon: Icons.stop,
        onTap: _stopRecording,
        backgroundColor: AppColors.danger,
        iconColor: Colors.white,
      );
    }
    
    // Mute/unmute button
    return _InputButton(
      icon: _isMuted ? Icons.volume_off : Icons.volume_up,
      onTap: _toggleMute,
      backgroundColor: AppColors.surfaceLight,
      iconColor: _isMuted ? AppColors.textMuted : AppColors.textPrimary,
    );
  }

  Widget _buildTextField() {
    final isRecording = _inputState == ChatInputState.recording;
    final isProcessing = _inputState == ChatInputState.processing;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: AppColors.border),
      ),
      child: isRecording
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.mic, color: AppColors.danger, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Recording...',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            )
          : Center(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                enabled: !isProcessing,
                style: const TextStyle(color: AppColors.textPrimary),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: isProcessing ? 'Thinking...' : 'Type or tap mic to speak...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
    );
  }

  Widget _buildRightButton() {
    if (_inputState == ChatInputState.processing) {
      // Loading indicator
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }
    
    if (_inputState == ChatInputState.empty) {
      // Record button
      return _InputButton(
        icon: Icons.mic,
        onTap: _startRecording,
        backgroundColor: AppColors.accent,
        iconColor: Colors.white,
      );
    }
    
    // Send button
    return _InputButton(
      icon: Icons.send,
      onTap: _sendMessage,
      backgroundColor: AppColors.accent,
      iconColor: Colors.white,
    );
  }
}


/// Input button
class _InputButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;

  const _InputButton({
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

/// Chat message bubble
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: message.isUser ? AppColors.accent : AppColors.surfaceLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border: message.isUser 
              ? null 
              : Border.all(color: AppColors.accent.withOpacity(0.3)),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: message.isUser ? Colors.white : AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// Typing indicator for when AI is thinking
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final delay = i * 0.2;
                final value = ((_controller.value + delay) % 1.0);
                final opacity = (value < 0.5 ? value * 2 : (1 - value) * 2).clamp(0.3, 1.0);
                return Container(
                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(opacity),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
