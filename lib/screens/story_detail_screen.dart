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
              import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/models/story.dart';
import 'package:turikumwe/repositories/story_repository.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/widgets/user_avatar.dart';

class StoryDetailScreen extends StatefulWidget {
  final Story story;

  const StoryDetailScreen({Key? key, required this.story}) : super(key: key);

  @override
  _StoryDetailScreenState createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  bool _isLiked = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    final isLiked = await Provider.of<StoryRepository>(context, listen: false)
        .hasUserLikedStory(widget.story.id, user.id);
    if (mounted) {
      setState(() {
        _isLiked = isLiked;
      });
    }
  }

  Future<void> _toggleLike() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final storyRepo = Provider.of<StoryRepository>(context, listen: false);
      
      if (_isLiked) {
        await storyRepo.unlikeStory(widget.story.id, user.id);
      } else {
        await storyRepo.likeStory(widget.story.id, user.id);
      }

      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Details'),
        actions: [
          IconButton(
            icon: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: _isLiked ? Colors.red : null,
            ),
            onPressed: _isLoading ? null : _toggleLike,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.story.images != null && widget.story.images!.isNotEmpty)
              SizedBox(
                height: 300,
                child: PageView.builder(
                  itemCount: widget.story.images!.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(),
                              body: PhotoView(
                                imageProvider: NetworkImage(widget.story.images![index]),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Image.network(
                        widget.story.images![index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Chip(
              label: Text(widget.story.category),
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
            const SizedBox(height: 16),
            Text(
              widget.story.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                UserAvatar(
                  imageUrl: widget.story.userProfile,
                  radius: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.story.userName ?? 'Anonymous',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${widget.story.likesCount} likes',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.story.content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Posted ${timeago.format(widget.story.createdAt)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}children: [
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