// lib/widgets/group_post_card_home.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/models/post.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/post_comments_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
import 'package:timeago/timeago.dart' as timeago;

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
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  bool _expanded = false;
  User? _postAuthor;
  Group? _postGroup;
  bool _isLoading = true;
  bool _updatingLike = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.post.likesCount;
    _commentsCount = widget.post.commentsCount;
    _loadAdditionalData();
  }

  Future<void> _loadAdditionalData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final databaseService = DatabaseService();
      
      // Load post author
      final author = await databaseService.getUserById(widget.post.userId);
      
      // Load group if post is in a group
      Group? group;
      if (widget.post.groupId != null) {
        group = await databaseService.getGroupById(widget.post.groupId!);
      }
      
      // Check if current user has liked this post
      final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
      if (currentUser != null) {
        // Check if user has liked the post
        try {
          _isLiked = await databaseService.hasUserLikedPost(widget.post.id, currentUser.id);
        } catch (e) {
          print('Error checking like status: $e');
          // Default to not liked if there's an error
          _isLiked = false;
        }
      }
      
      if (mounted) {
        setState(() {
          _postAuthor = author;
          _postGroup = group;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading post data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    if (currentUser == null) {
      // Show login prompt
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to like posts')),
      );
      return;
    }
    
    if (_updatingLike) return; // Prevent multiple taps
    
    setState(() {
      _updatingLike = true;
    });
    
    try {
      final databaseService = DatabaseService();
      
      // Toggle like status in the database
      final isNowLiked = await databaseService.toggleLikePost(widget.post.id, currentUser.id);
      
      setState(() {
        _isLiked = isNowLiked;
        _likesCount = isNowLiked ? _likesCount + 1 : _likesCount - 1;
        _updatingLike = false;
      });
      
      // Notify parent of update
      if (widget.onPostUpdated != null) {
        widget.onPostUpdated!();
      }
    } catch (e) {
      print('Error toggling like: $e');
      setState(() {
        _updatingLike = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating like: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        margin: EdgeInsets.only(bottom: 16),
        child: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

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
      leading: CircleAvatar(
        // In a real app, load the user's profile picture
        backgroundImage: _postAuthor?.profilePicture != null 
            ? NetworkImage(_postAuthor!.profilePicture!) 
            : null,
        child: _postAuthor?.profilePicture == null 
            ? const Icon(Icons.person) 
            : null,
      ),
      title: Row(
        children: [
          Text(
            _postAuthor?.name ?? 'Unknown User',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (_postGroup != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _postGroup!.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        timeago.format(DateTime.parse(widget.post.createdAt)),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          if (value == 'delete') {
            _deletePost();
          } else if (value == 'report') {
            _reportPost();
          }
        },
        itemBuilder: (context) {
          final currentUser = Provider.of<AuthService>(context).currentUser;
          final isAuthor = currentUser?.id == widget.post.userId;
          
          return [
            if (isAuthor)
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Post', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            const PopupMenuItem<String>(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag),
                  SizedBox(width: 8),
                  Text('Report Post'),
                ],
              ),
            ),
          ];
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
          final imagePath = imagesList[index].trim();
          
          // Determine image source (network, file, or asset)
          Widget imageWidget;
          
          if (imagePath.startsWith('http')) {
            // Network image
            imageWidget = Image.network(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('Error loading image: $error');
                return const Center(
                  child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                );
              },
            );
          } else if (imagePath.startsWith('/')) {
            // File path
            imageWidget = Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('Error loading image: $error');
                return const Center(
                  child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                );
              },
            );
          } else {
            // Asset image
            imageWidget = Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('Error loading image: $error');
                return const Center(
                  child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                );
              },
            );
          }
          
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageWidget,
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
            onPressed: _updatingLike ? null : _toggleLike,
          ),
          Text('$_likesCount'),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.comment_outlined),
            onPressed: _showComments,
          ),
          Text('$_commentsCount'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _sharePost,
          ),
        ],
      ),
    );
  }

  void _showComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostCommentsScreen(
          post: widget.post,
          onCommentAdded: () {
            setState(() {
              _commentsCount++;
            });
            
            if (widget.onPostUpdated != null) {
              widget.onPostUpdated!();
            }
          },
        ),
      ),
    );
  }

  void _sharePost() {
    // In a real app, implement sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing feature coming soon!')),
    );
  }

  void _reportPost() {
    // In a real app, implement reporting functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted. Thank you for helping us keep the community safe.')),
    );
  }

  void _deletePost() {
    // In a real app, show confirmation dialog and delete post
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Delete post from database
              try {
                await DatabaseService().deletePost(widget.post.id);
                
                if (widget.onPostUpdated != null) {
                  widget.onPostUpdated!();
                }
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post deleted successfully')),
                  );
                }
              } catch (e) {
                print('Error deleting post: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting post: ${e.toString()}')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}