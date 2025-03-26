import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:turikumwe/models/story.dart';
import 'package:turikumwe/widgets/user_avatar.dart';

class StoryDetailScreen extends StatelessWidget {
  final Story story;

  const StoryDetailScreen({Key? key, required this.story}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (story.images != null && story.images!.isNotEmpty)
              SizedBox(
                height: 300,
                child: PageView.builder(
                  itemCount: story.images!.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              body: PhotoView(
                                imageProvider: NetworkImage(story.images![index]),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Image.network(
                        story.images![index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Chip(
              label: Text(story.category),
            ),
            const SizedBox(height: 16),
            Text(
              story.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                UserAvatar(
                  imageUrl: story.userProfile,
                  radius: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  story.userName ?? 'Anonymous',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${story.likesCount} likes',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(story.content),
          ],
        ),
      ),
    );
  }
}