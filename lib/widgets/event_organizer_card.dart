// lib/widgets/event_organizer_card.dart
import 'package:flutter/material.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/profile_screen.dart';
import 'package:turikumwe/widgets/user_avatar.dart';

class EventOrganizerCard extends StatelessWidget {
  final User organizer;
  final VoidCallback? onContactPressed;

  const EventOrganizerCard({
    Key? key,
    required this.organizer,
    this.onContactPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(id: organizer.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Organized by',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Organizer Avatar
                  UserAvatar(
                    user: organizer,
                    radius: 24,
                    showBadge: organizer.isVerified ?? false,
                  ),
                  const SizedBox(width: 16),
                  // Organizer Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              organizer.fullName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (organizer.district != null)
                          Text(
                            organizer.district!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Contact button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.message_outlined),
                      color: AppColors.primary,
                      onPressed: onContactPressed ?? () {
                        // Default action to navigate to chat or contact screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Contact feature coming soon!'),
                          ),
                        );
                      },
                      tooltip: 'Contact Organizer',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}