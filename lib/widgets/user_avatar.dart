import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final String? initials;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
    this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? theme.colorScheme.primaryContainer,
      foregroundColor: textColor ?? theme.colorScheme.onPrimaryContainer,
      foregroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
      child: _buildFallbackChild(theme),
    );
  }

  Widget? _buildFallbackChild(ThemeData theme) {
    if (imageUrl != null) return null;
    
    if (initials != null && initials!.isNotEmpty) {
      return Text(
        initials!,
        style: TextStyle(
          fontSize: radius * 0.6,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    
    return Icon(
      Icons.person,
      size: radius * 0.8,
    );
  }
}