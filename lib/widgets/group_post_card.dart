// lib/widgets/group_post_card.dart (Fixed version)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/post.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';

class GroupPostCard extends StatefulWidget {
  final Post post;
  final bool isGroupMember;
  final VoidCallback? onPostUpdated;

  const GroupPostCard({
    Key? key,
    required this.post,
    required this.isGroupMember,
    this.onPostUpdated,
  }) : super(key: key);

  @override
  State<GroupPostCard> createState() => _GroupPostCardState();
}

class _GroupPostCardState extends State<GroupPostCard> {
  final TextEditingController _commentController = TextEditingController();
  bool _isLoadingComments = false;
  bool _isPostingComment = false;
  bool _showComments = false;
  List<Map<String, dynamic>> _comments = [];
  User? _postAuthor;
  bool _isLiked = false;
  
  // Create a local copy of the post that can be modified
  late Post _post;

  @override
  void initState() {
    super.initState();
    // Create a local copy of the post
    _post = widget.post;
    _loadPostAuthor();
    _checkIfLiked();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadPostAuthor() async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    final user = await databaseService.getUserById(_post.userId);
    if (mounted) {
      setState(() {
        _postAuthor = user;
      });
    }
  }

  Future<void> _checkIfLiked() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser == null) return;

    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      final isLiked = await databaseService.isPostLikedByUser(
        _post.id, 
        authService.currentUser!.id
      );
      
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
        });
      }
    } catch (e) {
      // Silently handle error
      print('Error checking if post is liked: $e');
    }
  }

  Future<void> _loadComments() async {
    if (_isLoadingComments) return;

    setState(() {
      _isLoadingComments = true;
      _showComments = true;
    });

    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      // Fetch comments for this post
      final comments = await databaseService.getCommentsForPost(_post.id);
      
      // For each comment, fetch the author
      for (var comment in comments) {
        final user = await databaseService.getUserById(comment['userId']);
        comment['user'] = user;
      }
      
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load comments: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _postComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to post comments')),
      );
      return;
    }

    setState(() => _isPostingComment = true);

    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      final commentData = {
        'postId': _post.id,
        'userId': authService.currentUser!.id,
        'content': comment,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      final commentId = await databaseService.insertComment(commentData);
      
      // Update post comments count
      await databaseService.incrementPostCommentsCount(_post.id);
      
      // Clear input field
      _commentController.clear();
      
      // Update local post copy
      setState(() {
        _post.commentsCount += 1;
        _isPostingComment = false;
        
        // Add the new comment to the list without reloading everything
        final newComment = {
          'id': commentId,
          'postId': _post.id,
          'userId': authService.currentUser!.id,
          'content': comment,
          'createdAt': DateTime.now().toIso8601String(),
          'user': authService.currentUser,
        };
        
        _comments.add(newComment);
      });
      
      // Notify parent about the update
      widget.onPostUpdated?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _isPostingComment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: ${e.toString()}')),
        );
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

    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      if (_isLiked) {
        // Unlike
        await databaseService.unlikePost(_post.id, authService.currentUser!.id);
        setState(() {
          _isLiked = false;
          // Update local copy, ensuring it doesn't go below 0
          _post.likesCount = _post.likesCount > 0 ? _post.likesCount - 1 : 0;
        });
      } else {
        // Like
        await databaseService.likePost(_post.id, authService.currentUser!.id);
        setState(() {
          _isLiked = true;
          _post.likesCount += 1;
        });
      }
      
      // Notify parent about the update
      widget.onPostUpdated?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to like/unlike post: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostHeader(),
          _buildPostContent(),
          _buildPostActions(),
          if (_showComments) _buildCommentsSection(),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
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
                  _formatDate(DateTime.parse(_post.createdAt)),
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
              showModalBottomSheet(
                context: context,
                builder: (_) => _buildPostOptions(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_post.content),
          if (_post.images != null && _post.images!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildPostImages(_post.images!.split(',')),
            ),
        ],
      ),
    );
  }

  Widget _buildPostImages(List<String> imageUrls) {
    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrls.first,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.image_not_supported),
              ),
            );
          },
        ),
      );
    } else {
      return GridView.count(
        crossAxisCount: imageUrls.length > 2 ? 3 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: imageUrls.map((url) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.image_not_supported),
                  ),
                );
              },
            ),
          );
        }).toList(),
      );
    }
  }

  Widget _buildPostActions() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              TextButton.icon(
                icon: Icon(
                  _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 18,
                  color: _isLiked ? AppColors.primary : null,
                ),
                label: Text(
                  '${_post.likesCount}',
                  style: TextStyle(
                    color: _isLiked ? AppColors.primary : null,
                  ),
                ),
                onPressed: widget.isGroupMember ? _toggleLike : null,
              ),
              TextButton.icon(
                icon: const Icon(Icons.comment_outlined, size: 18),
                label: Text('${_post.commentsCount}'),
                onPressed: () {
                  if (_showComments) {
                    setState(() {
                      _showComments = false;
                    });
                  } else {
                    _loadComments();
                  }
                },
              ),
            ],
          ),
          TextButton.icon(
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share'),
            onPressed: widget.isGroupMember ? () {
              // Implement share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share functionality coming soon')),
              );
            } : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _isLoadingComments
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._comments.map(_buildCommentItem).toList(),
                  ],
                ),
        ),
        if (widget.isGroupMember) _buildAddCommentField(),
      ],
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final User? user = comment['user'];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: user?.profilePicture != null
                ? NetworkImage(user!.profilePicture!)
                : null,
            child: user?.profilePicture == null ? const Icon(Icons.person, size: 16) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Unknown User',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(comment['content']),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    _formatDate(DateTime.parse(comment['createdAt'])),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCommentField() {
    return Padding(
      padding: const EdgeInsets.all(12),
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
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _isPostingComment
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.send, color: AppColors.primary),
                  onPressed: _postComment,
                ),
        ],
      ),
    );
  }

  Widget _buildPostOptions() {
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    final bool isAuthor = currentUser != null && currentUser.id == _post.userId;
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Post Options',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('Save Post'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post saved')),
                );
              },
            ),
            if (isAuthor) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Post'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to edit post page
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Post', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Post'),
                      content: const Text('Are you sure you want to delete this post?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    Navigator.pop(context);
                    // Delete post logic
                    try {
                      final databaseService = Provider.of<DatabaseService>(context, listen: false);
                      await databaseService.deletePost(_post.id);
                      widget.onPostUpdated?.call();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post deleted')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to delete post: ${e.toString()}')),
                      );
                    }
                  }
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report Post'),
                onTap: () {
                  Navigator.pop(context);
                  // Show report dialog
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Extension methods needed in DatabaseService class
extension GroupPostExtensions on DatabaseService {
  Future<List<Map<String, dynamic>>> getCommentsForPost(int postId) async {
    final db = await database;
    final List<Map<String, dynamic>> comments = await db.query(
      'comments',
      where: 'postId = ?',
      whereArgs: [postId],
      orderBy: 'createdAt ASC',
    );
    return comments;
  }

  Future<bool> isPostLikedByUser(int postId, int userId) async {
    final db = await database;
    try {
      // Check if post_likes table exists
      final tablesResult = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='post_likes'");
      if (tablesResult.isEmpty) {
        return false;
      }
      
      final List<Map<String, dynamic>> result = await db.query(
        'post_likes',
        where: 'postId = ? AND userId = ?',
        whereArgs: [postId, userId],
      );
      return result.isNotEmpty;
    } catch (e) {
      // Table might not exist
      return false;
    }
  }

  Future<void> likePost(int postId, int userId) async {
    final db = await database;
    
    // Start a transaction
    await db.transaction((txn) async {
      // Check if there's a likes table, create if it doesn't exist
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS post_likes (
          id INTEGER PRIMARY KEYid INTEGER PRIMARY KEY AUTOINCREMENT,
          postId INTEGER NOT NULL,
          userId INTEGER NOT NULL,
          createdAt TEXT NOT NULL,
          FOREIGN KEY (postId) REFERENCES posts (id),
          FOREIGN KEY (userId) REFERENCES users (id)
        )
      ''');
      
      // Add like record
      await txn.insert('post_likes', {
        'postId': postId,
        'userId': userId,
        'createdAt': DateTime.now().toIso8601String(),
      });
      
      // Increment likes count
      await txn.rawUpdate(
        'UPDATE posts SET likesCount = likesCount + 1 WHERE id = ?',
        [postId],
      );
    });
  }

  Future<void> unlikePost(int postId, int userId) async {
    final db = await database;
    
    // Start a transaction
    await db.transaction((txn) async {
      // Remove like record
      await txn.delete(
        'post_likes',
        where: 'postId = ? AND userId = ?',
        whereArgs: [postId, userId],
      );
      
      // Decrement likes count, ensuring it doesn't go below 0
      await txn.rawUpdate(
        'UPDATE posts SET likesCount = MAX(0, likesCount - 1) WHERE id = ?',
        [postId],
      );
    });
  }

  Future<int> incrementPostCommentsCount(int postId) async {
    final db = await database;
    return await db.rawUpdate(
      'UPDATE posts SET commentsCount = commentsCount + 1 WHERE id = ?',
      [postId],
    );
  }

  Future<int> insertComment(Map<String, dynamic> comment) async {
    final db = await database;
    return await db.insert('comments', comment);
  }

  Future<int> deletePost(int postId) async {
    final db = await database;
    
    // Start a transaction to delete post and related data
    return await db.transaction((txn) async {
      // Delete comments
      await txn.delete(
        'comments',
        where: 'postId = ?',
        whereArgs: [postId],
      );
      
      // Delete likes if the table exists
      try {
        await txn.delete(
          'post_likes',
          where: 'postId = ?',
          whereArgs: [postId],
        );
      } catch (e) {
        // Table might not exist, ignore
      }
      
      // Finally delete the post
      return await txn.delete(
        'posts',
        where: 'id = ?',
        whereArgs: [postId],
      );
    });
  }
}