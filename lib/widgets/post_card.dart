// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/post.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostCard extends StatefulWidget {
  final Post post;

  const PostCard({
    Key? key,
    required this.post,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.post.likesCount;
    _commentsCount = widget.post.commentsCount;
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    // In a real app, update the like in the database
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildContent(),
          if (widget.post.images != null && widget.post.images!.isNotEmpty)
            _buildImages(),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: const CircleAvatar(
        // In a real app, load the user's profile picture
        child: Icon(Icons.person),
      ),
      title: const Text(
        'User Name', // In a real app, load the user's name
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        // Convert string to DateTime before using timeago
        timeago.format(DateTime.parse(widget.post.createdAt)),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () {
          // Show post options
        },
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: Text(
              widget.post.content,
              style: const TextStyle(fontSize: 16),
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
          ),
          if (!_expanded && widget.post.content.length > 150)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _expanded = true;
                  });
                },
                child: const Text(
                  'See more',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImages() {
    // Split the images string into a list if it's a comma-separated string
    List<String> imagesList = [];
    if (widget.post.images != null) {
      imagesList = widget.post.images!.split(',');
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: PageView.builder(
        itemCount: imagesList.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              // Use NetworkImage instead of AssetImage for URLs
              image: DecorationImage(
                image: NetworkImage(imagesList[index].trim()),
                fit: BoxFit.cover,
                // Handle image loading errors
                onError: (exception, stackTrace) {
                  print('Error loading image: $exception');
                },
              ),
            ),
            // Fallback if image fails to load
            child: imagesList[index].isEmpty
                ? const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey))
                : null,
          );
        },
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: _isLiked ? Colors.red : null,
            ),
            onPressed: _toggleLike,
          ),
          Text('$_likesCount'),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.comment_outlined),
            onPressed: () {
              // Show comments
            },
          ),
          Text('$_commentsCount'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // Share post
            },
          ),
        ],
      ),
    );
  }
}