// lib/screens/post_comments_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/comment.dart';
import 'package:turikumwe/models/post.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
// Removed outdated 'share' package import as 'share_plus' is already used.

class PostCommentsScreen extends StatefulWidget {
  final Post post;
  final VoidCallback? onCommentAdded;

  const PostCommentsScreen({
    Key? key,
    required this.post,
    this.onCommentAdded,
  }) : super(key: key);

  @override
  State<PostCommentsScreen> createState() => _PostCommentsScreenState();
}

class _PostCommentsScreenState extends State<PostCommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSendingComment = false;
  User? _postAuthor;
  
  @override
  void initState() {
    super.initState();
    _loadComments();
    _loadPostAuthor();
  }
  
  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }
  
  Future<void> _loadPostAuthor() async {
    try {
      final author = await DatabaseService().getUserById(widget.post.userId);
      if (mounted) {
        setState(() {
          _postAuthor = author;
        });
      }
    } catch (e) {
      print('Error loading post author: $e');
    }
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final db = DatabaseService();
      final commentsData = await db.getCommentsForPost(widget.post.id);
      
      if (mounted) {
        setState(() {
          _comments.clear();
          _comments.addAll(commentsData);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading comments: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        DialogUtils.showErrorSnackBar(
          context, 
          message: 'Failed to load comments. Please try again.',
        );
      }
    }
  }
  
  Future<void> _addComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;
    
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    if (currentUser == null) {
      DialogUtils.showErrorSnackBar(
        context, 
        message: 'You need to be logged in to comment.',
      );
      return;
    }
    
    setState(() {
      _isSendingComment = true;
    });
    
    try {
      final db = DatabaseService();
      
      final commentData = {
        'postId': widget.post.id,
        'userId': currentUser.id,
        'content': comment,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      final commentId = await db.addComment(commentData);
      
      if (commentId > 0) {
        _commentController.clear();
        
        // Add the new comment to the list with user details
        final newComment = {
          'id': commentId,
          'postId': widget.post.id,
          'userId': currentUser.id,
          'content': comment,
          'createdAt': DateTime.now().toIso8601String(),
          'userName': currentUser.name,
          'userProfilePicture': currentUser.profilePicture,
        };
        
        setState(() {
          _comments.insert(0, newComment); // Add to beginning of list
          _isSendingComment = false;
        });
        
        // Notify parent about the comment
        if (widget.onCommentAdded != null) {
          widget.onCommentAdded!();
        }
      } else {
        throw Exception('Failed to add comment');
      }
    } catch (e) {
      setState(() {
        _isSendingComment = false;
      });
      
      DialogUtils.showErrorSnackBar(
        context, 
        message: 'Error adding comment: ${e.toString()}',
      );
    }
  }
  
  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    if (currentUser == null || currentUser.id != comment['userId']) {
      DialogUtils.showErrorSnackBar(
        context, 
        message: 'You can only delete your own comments.',
      );
      return;
    }
    
    final confirm = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Delete Comment',
      message: 'Are you sure you want to delete this comment?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDangerous: true,
    );
    
    if (!confirm) return;
    
    try {
      final db = DatabaseService();
      final success = await db.deleteComment(comment['id']);
      
      if (success) {
        setState(() {
          _comments.removeWhere((c) => c['id'] == comment['id']);
        });
        
        // Notify parent about the comment removal
        if (widget.onCommentAdded != null) {
          widget.onCommentAdded!();
        }

        if (mounted) {
          DialogUtils.showSuccessSnackBar(
            context,
            message: 'Comment deleted successfully',
          );
        }
      } else {
        throw Exception('Failed to delete comment');
      }
    } catch (e) {
      DialogUtils.showErrorSnackBar(
        context, 
        message: 'Error deleting comment: ${e.toString()}',
      );
    }
  }

  void _sharePost() {
    try {
      // Basic sharing implementation
      final String postContent = widget.post.content;
      final String shareText = 'Check out this post:\n\n$postContent\n\n';
      
      Share.share(shareText);
      
      // Increment share count
      DatabaseService().incrementShareCount(widget.post.id);
    } catch (e) {
      print('Error sharing post: $e');
      DialogUtils.showErrorSnackBar(
        context,
        message: 'Error sharing post. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sharePost,
            tooltip: 'Share Post',
          ),
        ],
      ),
      body: Column(
        children: [
          // Post preview
          _buildPostPreview(),
          
          const Divider(thickness: 1),
          
          // Comments section
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _comments.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No comments yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Be the first to comment!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadComments,
                    child: ListView.separated(
                      itemCount: _comments.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return _buildCommentTile(_comments[index]);
                      },
                    ),
                  ),
          ),
          
          // Comment input
          _buildCommentInput(),
        ],
      ),
    );
  }
  
  Widget _buildPostPreview() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
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
                  _postAuthor?.name ?? 'Unknown User',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.post.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.post.images != null && widget.post.images!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildImagePreview(widget.post.images!.split(',').first),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImagePreview(String imagePath) {
    Widget imageWidget;
    
    if (imagePath.startsWith('http')) {
      imageWidget = Image.network(
        imagePath,
        height: 60,
        width: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 60,
            width: 60,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image),
          );
        },
      );
    } else if (imagePath.startsWith('/')) {
      imageWidget = Image.file(
        File(imagePath),
        height: 60,
        width: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 60,
            width: 60,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image),
          );
        },
      );
    } else {
      imageWidget = Container(
        height: 60,
        width: 60,
        color: Colors.grey[300],
        child: const Icon(Icons.image),
      );
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: imageWidget,
    );
  }
  
  Widget _buildCommentTile(Map<String, dynamic> comment) {
    final currentUser = Provider.of<AuthService>(context).currentUser;
    final isMyComment = currentUser != null && comment['userId'] == currentUser.id;
    final createdAt = DateTime.parse(comment['createdAt']);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: comment['userProfilePicture'] != null 
                ? NetworkImage(comment['userProfilePicture']) 
                : null,
            child: comment['userProfilePicture'] == null 
                ? const Icon(Icons.person, size: 16) 
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment['userName'] ?? 'Unknown User',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeago.format(createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (isMyComment) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _deleteComment(comment),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment['content'],
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(50),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: Provider.of<AuthService>(context).currentUser?.profilePicture != null
                ? NetworkImage(Provider.of<AuthService>(context).currentUser!.profilePicture!)
                : null,
            child: Provider.of<AuthService>(context).currentUser?.profilePicture == null
                ? const Icon(Icons.person, size: 16)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocusNode,
              decoration: const InputDecoration(
                hintText: 'Write a comment...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addComment(),
            ),
          ),
          IconButton(
            icon: _isSendingComment
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                : const Icon(Icons.send),
            color: AppColors.primary,
            onPressed: _isSendingComment ? null : _addComment,
          ),
        ],
      ),
    );
  }
}