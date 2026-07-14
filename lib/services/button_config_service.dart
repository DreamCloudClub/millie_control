import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Button configuration for quick buttons
class ButtonConfig {
  final String actionType; // 'none', 'waypoint', 'task', 'follow_on', 'follow_off'
  final String? value; // waypoint name or task name

  ButtonConfig({required this.actionType, this.value});

  Map<String, dynamic> toJson() => {
    'action_type': actionType,
    'value': value,
  };

  factory ButtonConfig.fromJson(Map<String, dynamic> json) => ButtonConfig(
    actionType: json['action_type'] as String? ?? 'none',
    value: json['value'] as String?,
  );

  factory ButtonConfig.empty() => ButtonConfig(actionType: 'none');
}

/// Service for storing and retrieving button configurations
/// Only for nav buttons (3 buttons, indices 6-8 on the grid)
class ButtonConfigService {
  static const String _storageKey = 'quick_button_configs';
  static const int buttonCount = 3;

  static Future<List<ButtonConfig>> loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);

    if (jsonStr == null) {
      // Return 9 empty configs
      return List.generate(buttonCount, (_) => ButtonConfig.empty());
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      final configs = jsonList.map((j) => ButtonConfig.fromJson(j)).toList();

      // Ensure we have exactly 3 configs
      while (configs.length < buttonCount) {
        configs.add(ButtonConfig.empty());
      }
      return configs.take(buttonCount).toList();
    } catch (e) {
      print('Error loading button configs: $e');
      return List.generate(buttonCount, (_) => ButtonConfig.empty());
    }
  }

  static Future<void> saveConfig(int index, ButtonConfig config) async {
    final configs = await loadConfigs();
    if (index >= 0 && index < buttonCount) {
      configs[index] = config;
    }
    await _saveAll(configs);
  }

  static Future<void> _saveAll(List<ButtonConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(configs.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }

  static Future<ButtonConfig> getConfig(int index) async {
    final configs = await loadConfigs();
    if (index >= 0 && index < buttonCount) {
      return configs[index];
    }
    return ButtonConfig.empty();
  }
}
