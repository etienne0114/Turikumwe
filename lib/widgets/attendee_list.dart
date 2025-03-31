// lib/widgets/attendee_list.dart
import 'package:flutter/material.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/profile_screen.dart';
import 'package:turikumwe/widgets/user_avatar.dart';

class AttendeeList extends StatelessWidget {
  final List<User> attendees;
  final int maxToShow;

  const AttendeeList({
    Key? key,
    required this.attendees,
    this.maxToShow = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayedAttendees = attendees.length > maxToShow 
        ? attendees.sublist(0, maxToShow)
        : attendees;
    
    return Column(
      children: [
        // Display attendees in a grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: displayedAttendees.length,
          itemBuilder: (context, index) {
            final attendee = displayedAttendees[index];
            return _buildAttendeeItem(context, attendee);
          },
        ),
        
        // Show "View More" button if there are more attendees
        if (attendees.length > maxToShow) ...[
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              _showAllAttendeesBottomSheet(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'View all ${attendees.length} attendees',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAttendeeItem(BuildContext context, User attendee) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(id: attendee.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          UserAvatar(
            user: attendee,
            radius: 30,
            showBadge: attendee.isVerified ?? false,
          ),
          const SizedBox(height: 8),
          Text(
            attendee.name.split(' ')[0], // Just first name for brevity
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showAllAttendeesBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${attendees.length} Attendees',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                const Divider(),
                
                // Attendees list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: attendees.length,
                    itemBuilder: (context, index) {
                      final attendee = attendees[index];
                      return ListTile(
                        leading: UserAvatar(
                          user: attendee,
                          radius: 20,
                          showBadge: attendee.isVerified ?? false,
                        ),
                        title: Text(
                          attendee.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: attendee.district != null
                            ? Text(attendee.district!)
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.message_outlined),
                          onPressed: () {
                            // Navigate to messaging screen
                            Navigator.pop(context);
                            // Add navigation to chat with this user
                          },
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(id: attendee.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}