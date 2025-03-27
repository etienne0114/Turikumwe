// lib/widgets/group_post_card_home.dart - For use on home screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/models/post.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/groups/group_detail_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:turikumwe/widgets/group_post_card.dart';

class GroupPostCardHome extends StatefulWidget {
  final Post post;
  final VoidCallback? onPostUpdated;

  const GroupPostCardHome({
    Key? key,
    required this.post,
    this.onPostUpdated,
  }) : super(key: key);

  @override
  State<GroupPostCardHome> createState() => _GroupPostCardHomeState();
}

class _GroupPostCardHomeState extends State<GroupPostCardHome> {
  User? _postAuthor;
  Group? _group;
  bool _isLiked = false;
  bool _isLoading = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadPostDetails();
  }

  Future<void> _loadPostDetails() async {
    setState(() => _isLoading = true);
    
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      // Load post author
      final author = await databaseService.getUserById(widget.post.userId);
      
      // Load group if post belongs to a group
      Group? group;
      if (widget.post.groupId != null) {
        group = await databaseService.getGroupById(widget.post.groupId!);
      }
      
      // Check if post is liked
      bool isLiked = false;
      final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
      if (currentUser != null) {
        isLiked = await databaseService.isPostLikedByUser(
          widget.post.id, 
          currentUser.id
        );
      }
      
      if (mounted) {
        setState(() {
          _postAuthor = author;
          _group = group;
          _isLiked = isLiked;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        print('Error loading post details: $e');
      }
    }
  }

  Future<void> _toggleLike() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to like posts')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      if (_isLiked) {
        // Unlike
        await databaseService.unlikePost(widget.post.id, authService.currentUser!.id);
        setState(() {
          _isLiked = false;
          widget.post.likesCount = widget.post.likesCount > 0 ? widget.post.likesCount - 1 : 0;
        });
      } else {
        // Like
        await databaseService.likePost(widget.post.id, authService.currentUser!.id);
        setState(() {
          _isLiked = true;
          widget.post.likesCount += 1;
        });
      }
      
      // Notify parent about the update
      widget.onPostUpdated?.call();
    } catch (e) {
      print('Error toggling like: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToGroup() {
    if (_group != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GroupDetailScreen(group: _group!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostHeader(),
          _buildPostContent(),
          if (widget.post.images != null && widget.post.images!.isNotEmpty)
            _buildPostImages(widget.post.images!.split(',')),
          _buildPostActions(),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info row
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: _postAuthor?.profilePicture != null
                    ? NetworkImage(_postAuthor!.profilePicture!)
                    : null,
                child: _postAuthor?.profilePicture == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _postAuthor?.name ?? 'Loading...',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      timeago.format(DateTime.parse(widget.post.createdAt)),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  // Show post options
                },
              ),
            ],
          ),
          
          // Group info - displayed prominently on home feed
          if (_group != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _navigateToGroup,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.group,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Posted in ${_group!.name}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.post.content,
              style: const TextStyle(fontSize: 16),
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
            if (!_expanded && widget.post.content.length > 150)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'See more',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostImages(List<String> imageUrls) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: PageView.builder(
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          final imageUrl = imageUrls[index].trim();
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
            ),
            clipBehavior: Clip.hardEdge,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 50,
                    color: Colors.grey[400],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostActions() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          TextButton.icon(
            icon: Icon(
              _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
              size: 18,
              color: _isLiked ? AppColors.primary : null,
            ),
            label: Text(
              '${widget.post.likesCount}',
              style: TextStyle(
                color: _isLiked ? AppColors.primary : null,
              ),
            ),
            onPressed: _toggleLike,
          ),
          TextButton.icon(
            icon: const Icon(Icons.comment_outlined, size: 18),
            label: Text('${widget.post.commentsCount}'),
            onPressed: () {
              // Show comments or navigate to post detail
            },
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share'),
            onPressed: () {
              // Implement share functionality
            },
          ),
        ],
      ),
    );
  }
}