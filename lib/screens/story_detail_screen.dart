// lib/screens/story_detail_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/story.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/create_story_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/image_utils.dart';

class StoryDetailScreen extends StatefulWidget {
  final Story story;

  const StoryDetailScreen({
    Key? key,
    required this.story,
  }) : super(key: key);

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isLiked = false;
  int _likeCount = 0;
  User? _storyAuthor;
  bool _isLoading = true;
  List<String> _imagesList = [];
  int _currentImageIndex = 0;

  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get story author
      _storyAuthor = await _databaseService.getUserById(widget.story.userId);

      // Check if user has liked this story
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser != null) {
        try {
          _isLiked = await _databaseService.hasUserLikedStory(
              widget.story.id, currentUser.id);
        } catch (e) {
          print('Error checking like status: $e');
          _isLiked = false;
        }
      }

      // Parse images
      if (widget.story.images != null && widget.story.images!.isNotEmpty) {
        // Change this line:
        if (widget.story.images is List<String>) {
          _imagesList = widget.story.images as List<String>;
        } else if (widget.story.images is String) {
          _imagesList = (widget.story.images as String).split(',');
        } else {
          _imagesList = [];
        }

// To this:
        if (widget.story.images != null) {
          if (widget.story.images is List<String>) {
            _imagesList = widget.story.images as List<String>;
          } else if (widget.story.images is String) {
            _imagesList = (widget.story.images as String).split(',');
          } else {
            _imagesList = [];
          }
        } else {
          _imagesList = [];
        }
      } else {
        _imagesList = [];
      }

      // Update like count
      setState(() {
        _likeCount = widget.story.likesCount;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _shareStory() {
    final String title = widget.story.title;
    final String category = widget.story.category;
    final String userName = _storyAuthor?.name ?? 'A user';

    final String shareText =
        '$title\n\nA $category story shared by $userName on Turikumwe.\n\nDownload the app to read more inspiring stories!';

    Share.share(shareText);
  }

  Future<void> _likeStory() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like stories')),
      );
      return;
    }

    try {
      await _databaseService.toggleLikeStory(widget.story.id, currentUser.id);

      // Update UI state
      setState(() {
        if (_isLiked) {
          _likeCount = _likeCount > 0 ? _likeCount - 1 : 0;
        } else {
          _likeCount++;
        }
        _isLiked = !_isLiked;
      });
    } catch (e) {
      print('Error liking story: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _editStory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateStoryScreen(storyToEdit: widget.story),
      ),
    );

    if (result == true) {
      // Reload the story data
      final updatedStory = await _databaseService.getStoryById(widget.story.id);
      if (updatedStory != null && mounted) {
        setState(() {
          // Update with the latest story data
          widget.story.title = updatedStory.title;
          widget.story.content = updatedStory.content;
          widget.story.category = updatedStory.category;
          widget.story.images = updatedStory.images;
        });
        _loadData(); // Reload all data
      }
    }
  }

  Future<void> _deleteStory() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story'),
        content: const Text(
            'Are you sure you want to delete this story? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final result = await _databaseService.deleteStory(widget.story.id);
      if (result > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story deleted successfully')),
        );
        Navigator.pop(context, true); // Return true to indicate deletion
      } else {
        throw Exception('Failed to delete story');
      }
    } catch (e) {
      print('Error deleting story: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    final isOwner =
        currentUser != null && currentUser.id == widget.story.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Story'),
        actions: [
          IconButton(
            onPressed: _shareStory,
            icon: const Icon(Icons.share),
          ),
          if (isOwner)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editStory();
                } else if (value == 'delete') {
                  _deleteStory();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image carousel if there are images
                  if (_imagesList.isNotEmpty)
                    Stack(
                      children: [
                        SizedBox(
                          height: 250,
                          width: double.infinity,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _imagesList.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentImageIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return Container(
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: FileImage(File(_imagesList[index])),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Image indicators
                        if (_imagesList.length > 1)
                          Positioned(
                            bottom: 10,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _imagesList.length,
                                (index) => Container(
                                  width: 8,
                                  height: 8,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentImageIndex == index
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category chip
                        Chip(
                          label: Text(
                            widget.story.category,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: Theme.of(context).primaryColor,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),

                        const SizedBox(height: 8),

                        // Title
                        Text(
                          widget.story.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Author and date
                        Row(
                          children: [
                            _storyAuthor?.profilePicture != null
                                ? CircleAvatar(
                                    radius: 20,
                                    backgroundImage: FileImage(
                                        File(_storyAuthor!.profilePicture!)),
                                  )
                                : const CircleAvatar(
                                    radius: 20,
                                    child: Icon(Icons.person),
                                  ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _storyAuthor?.name ?? 'Anonymous',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMMM d, yyyy').format(widget.story.createdAt),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Content
                        Text(
                          widget.story.content,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Like button and count
                        Row(
                          children: [
                            IconButton(
                              onPressed: _likeStory,
                              icon: Icon(
                                _isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _isLiked ? Colors.red : null,
                                size: 28,
                              ),
                            ),
                            Text(
                              '$_likeCount ${_likeCount == 1 ? 'like' : 'likes'}',
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            OutlinedButton.icon(
                              onPressed: _shareStory,
                              icon: const Icon(Icons.share),
                              label: const Text('Share'),
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
