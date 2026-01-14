import 'package:flutter/material.dart';

class LeftToggle extends StatelessWidget {
  final VoidCallback onPressed;
  const LeftToggle({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2C2C2C),
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(5),
        child: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(
            Icons.chat_bubble_outline,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
