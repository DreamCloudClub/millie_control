import 'package:flutter/material.dart';

class RightToggle extends StatelessWidget {
  final VoidCallback onPressed;
  const RightToggle({super.key, required this.onPressed});

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
            Icons.menu,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
