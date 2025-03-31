// lib/widgets/user_avatar.dart
import 'package:flutter/material.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/user.dart';

class UserAvatar extends StatelessWidget {
  final User user;
  final double radius;
  final bool showBadge;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const UserAvatar({
    Key? key,
    required this.user,
    this.radius = 20,
    this.showBadge = false,
    this.onTap,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          _buildAvatar(),
          if (showBadge) _buildVerifiedBadge(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    // Check both profilePicture and profileImage fields
    final profileImage = user.profilePicture;
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.primary.withOpacity(0.1),
      backgroundImage: profileImage != null ? NetworkImage(profileImage) : null,
      child: profileImage == null ? _buildInitials() : null,
    );
  }

  Widget _buildInitials() {
    final initials = _getInitials();
    final fontSize = radius * 0.7; // Scale font size based on avatar size
    
    return Text(
      initials,
      style: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.bold,
        fontSize: fontSize,
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    final badgeSize = radius * 0.6; // Scale badge size based on avatar size
    
    return Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.verified,
          color: AppColors.primary,
          size: badgeSize,
        ),
      ),
    );
  }

  String _getInitials() {
    // Use name directly instead of fullName
    final name = user.name;
    
    if (name.isEmpty) {
      return '?';
    }
    
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    } else {
      return parts.first[0].toUpperCase();
    }
  }
}