import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final Color? backgroundColor;
  final TextStyle? textStyle;
  final BoxBorder? border;

  const ProfileAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 24,
    this.backgroundColor,
    this.textStyle,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final String initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? const Color(0xFFE8EAF6),
        backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty) 
          ? NetworkImage(photoUrl!) 
          : null,
        child: (photoUrl == null || photoUrl!.isEmpty)
          ? Text(
              initials,
              style: textStyle ?? TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3949AB),
              ),
            )
          : null,
      ),
    );
  }
}
