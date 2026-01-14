// lib/services/openai_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Represents a tool/function call requested by the AI
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  
  ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
  
  factory ToolCall.fromJson(Map<String, dynamic> json) {
    final function = json['function'] as Map<String, dynamic>;
    return ToolCall(
      id: json['id'] as String,
      name: function['name'] as String,
      arguments: jsonDecode(function['arguments'] as String) as Map<String, dynamic>,
    );
  }
}

/// Chat completion response with content and token usage
class ChatCompletionResponse {
  final String content;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final List<ToolCall>? toolCalls;
  
  ChatCompletionResponse({
    required this.content,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    this.toolCalls,
  });
  
  /// Whether the AI wants to call tools
  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;
}

/// Service to manage OpenAI API calls for chat, TTS, and transcription
class OpenAIService {
  static final OpenAIService _instance = OpenAIService._internal();
  factory OpenAIService() => _instance;
  OpenAIService._internal();
  
  String get apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  bool get hasApiKey => apiKey.isNotEmpty && apiKey.startsWith('sk-');
  
  /// Call OpenAI Chat Completions API
  /// Supports optional tools (function calling)
  Future<ChatCompletionResponse?> chatCompletion({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    String model = 'gpt-4o-mini',
  }) async {
    if (!hasApiKey) {
      debugPrint('OpenAI: No API key configured');
      return null;
    }
    
    try {
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      
      // Build messages array with system prompt
      final allMessages = <Map<String, dynamic>>[
        {'role': 'system', 'content': systemPrompt},
        ...messages,
      ];
      
      final requestBody = <String, dynamic>{
        'model': model,
        'messages': allMessages,
        'temperature': 0.7,
        'max_tokens': 500,
      };
      
      // Add tools if provided
      if (tools != null && tools.isNotEmpty) {
        requestBody['tools'] = tools;
        requestBody['tool_choice'] = 'auto';
      }
      
      debugPrint('OpenAI Chat: ${messages.length} messages, model: $model');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final message = data['choices']?[0]?['message'];
        final content = message?['content'] as String? ?? '';
        
        // Extract token usage
        final usage = data['usage'];
        final promptTokens = usage?['prompt_tokens'] as int? ?? 0;
        final completionTokens = usage?['completion_tokens'] as int? ?? 0;
        final totalTokens = usage?['total_tokens'] as int? ?? 0;
        
        // Check for tool calls
        List<ToolCall>? toolCalls;
        final rawToolCalls = message?['tool_calls'] as List?;
        if (rawToolCalls != null && rawToolCalls.isNotEmpty) {
          toolCalls = rawToolCalls
              .map((tc) => ToolCall.fromJson(tc as Map<String, dynamic>))
              .toList();
          debugPrint('OpenAI: ${toolCalls.length} tool call(s) requested');
        }
        
        debugPrint('OpenAI: Response received ($totalTokens tokens)');
        
        return ChatCompletionResponse(
          content: content.trim(),
          promptTokens: promptTokens,
          completionTokens: completionTokens,
          totalTokens: totalTokens,
          toolCalls: toolCalls,
        );
      } else {
        final errorData = jsonDecode(response.body);
        debugPrint('OpenAI Error: ${errorData['error']?['message'] ?? response.body}');
      }
      
      return null;
    } catch (e) {
      debugPrint('OpenAI Error: $e');
      return null;
    }
  }
  
  /// Continue conversation after tool execution
  Future<ChatCompletionResponse?> continueWithToolResults({
    required String systemPrompt,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    String model = 'gpt-4o-mini',
  }) async {
    if (!hasApiKey) return null;
    
    try {
      final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
      
      final allMessages = <Map<String, dynamic>>[
        {'role': 'system', 'content': systemPrompt},
        ...messages,
      ];
      
      final requestBody = <String, dynamic>{
        'model': model,
        'messages': allMessages,
        'temperature': 0.7,
        'max_tokens': 500,
      };
      
      if (tools != null && tools.isNotEmpty) {
        requestBody['tools'] = tools;
        requestBody['tool_choice'] = 'auto';
      }
      
      debugPrint('OpenAI: Continuing with tool results...');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final message = data['choices']?[0]?['message'];
        final content = message?['content'] as String? ?? '';
        
        final usage = data['usage'];
        
        List<ToolCall>? toolCalls;
        final rawToolCalls = message?['tool_calls'] as List?;
        if (rawToolCalls != null && rawToolCalls.isNotEmpty) {
          toolCalls = rawToolCalls
              .map((tc) => ToolCall.fromJson(tc as Map<String, dynamic>))
              .toList();
        }
        
        return ChatCompletionResponse(
          content: content.trim(),
          promptTokens: usage?['prompt_tokens'] as int? ?? 0,
          completionTokens: usage?['completion_tokens'] as int? ?? 0,
          totalTokens: usage?['total_tokens'] as int? ?? 0,
          toolCalls: toolCalls,
        );
      }
      
      return null;
    } catch (e) {
      debugPrint('OpenAI Error: $e');
      return null;
    }
  }
  
  /// Text to Speech - returns path to audio file
  Future<String?> textToSpeech({
    required String text,
    String voice = 'shimmer',
    String model = 'tts-1',
  }) async {
    if (!hasApiKey) {
      debugPrint('OpenAI TTS: No API key');
      return null;
    }
    
    try {
      final uri = Uri.parse('https://api.openai.com/v1/audio/speech');
      
      final requestBody = {
        'model': model,
        'input': text,
        'voice': voice.toLowerCase(),
        'response_format': 'mp3',
      };
      
      debugPrint('OpenAI TTS: "${text.substring(0, text.length > 30 ? 30 : text.length)}..."');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        // Save audio to temp file
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('OpenAI TTS: Saved to $filePath');
        return filePath;
      } else {
        debugPrint('OpenAI TTS Error: ${response.statusCode}');
      }
      
      return null;
    } catch (e) {
      debugPrint('OpenAI TTS Error: $e');
      return null;
    }
  }
  
  /// Speech to Text (Whisper) - transcribe audio file
  Future<String?> speechToText(String audioFilePath) async {
    if (!hasApiKey) {
      debugPrint('OpenAI Whisper: No API key');
      return null;
    }
    
    try {
      final audioFile = File(audioFilePath);
      if (!await audioFile.exists()) {
        debugPrint('Whisper: Audio file not found');
        return null;
      }
      
      final audioBytes = await audioFile.readAsBytes();
      debugPrint('OpenAI Whisper: ${audioBytes.length} bytes');
      
      if (audioBytes.isEmpty) {
        debugPrint('Whisper: Empty audio file');
        return null;
      }
      
      final uri = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
      
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $apiKey';
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: 'audio.wav',
        ),
      );
      
      request.fields['model'] = 'whisper-1';
      request.fields['language'] = 'en';
      request.fields['response_format'] = 'text';
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final transcription = response.body.trim();
        debugPrint('Whisper: "$transcription"');
        return transcription;
      } else {
        debugPrint('Whisper Error: ${response.statusCode} - ${response.body}');
      }
      
      return null;
    } catch (e) {
      debugPrint('Whisper Error: $e');
      return null;
    }
  }
}

