
// lib/widgets/story_card.dart
import 'package:flutter/material.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/story.dart';
import 'package:timeago/timeago.dart' as timeago;

class StoryCard extends StatelessWidget {
  final Story story;

  const StoryCard({
    Key? key,
    required this.story,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to full story
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Story image
            if (story.images != null && story.images!.isNotEmpty)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  image: DecorationImage(
                    image: AssetImage(story.images!.first),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            
            // Story info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category chip
                  Chip(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    label: Text(
                      story.category,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Title
                  Text(
                    story.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Content preview
                  Text(
                    story.content,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  // Story meta
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            // In a real app, load the user's profile picture
                            child: Icon(Icons.person, size: 14),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'User Name', // In a real app, load the user's name
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        timeago.format(story.createdAt),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Likes and read more
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite, size: 16, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            '${story.likesCount} likes',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          // Navigate to full story
                        },
                        child: const Text('Read More'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}