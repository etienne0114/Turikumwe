// lib/widgets/story_card.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/story.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/story_detail_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/image_utils.dart';
import 'package:share_plus/share_plus.dart';

class StoryCard extends StatefulWidget {
  final Story story;
  final Function? onDelete;
  final Function? onEdit;

  const StoryCard({
    Key? key,
    required this.story,
    this.onDelete,
    this.onEdit,
  }) : super(key: key);

  @override
  State<StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<StoryCard> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLikeLoading = false;
  User? _author;
  bool _isLoading = true;
  List<String> _imagesList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(StoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.story.id != widget.story.id || 
        oldWidget.story.likesCount != widget.story.likesCount) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load author info
      _author = await _databaseService.getUserById(widget.story.userId);
      
      // Check if user has liked this story
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser != null) {
        try {
          _isLiked = await _databaseService.hasUserLikedStory(widget.story.id, currentUser.id);
        } catch (e) {
          print('Error checking like status: $e');
          _isLiked = false;
        }
      }

      // Parse images
      if (widget.story.images != null && widget.story.images!.isNotEmpty) {
        _imagesList = widget.story.images!;
      } else {
        _imagesList = [];
      }

      setState(() {
        _likeCount = widget.story.likesCount;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading story data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like stories')),
      );
      return;
    }

    if (_isLikeLoading) return;

    setState(() {
      _isLikeLoading = true;
    });

    try {
      await _databaseService.toggleLikeStory(widget.story.id, currentUser.id);
      
      // Optimistic UI update
      setState(() {
        if (_isLiked) {
          _likeCount--;
        } else {
          _likeCount++;
        }
        _isLiked = !_isLiked;
      });
    } catch (e) {
      print('Error toggling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLikeLoading = false;
        });
      }
    }
  }

  void _shareStory() {
    final String title = widget.story.title;
    final String category = widget.story.category;
    final String userName = _author?.name ?? 'A user';
    
    final String shareText = 
        '$title\n\nA $category story shared by $userName on Turikumwe.\n\nDownload the app to read more inspiring stories!';
    
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    
    // Check if current user is owner of this story
    final bool isOwner = currentUser != null && currentUser.id == widget.story.userId;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoryDetailScreen(story: widget.story),
            ),
          ).then((value) {
            // Reload data if returning with a change
            if (value == true) {
              _loadData();
            }
          });
        },
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Story image if available
                  if (_imagesList.isNotEmpty)
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: PageView.builder(
                        itemCount: _imagesList.length,
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
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Title
                        Text(
                          widget.story.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Content preview
                        Text(
                          widget.story.content.length > 100
                              ? '${widget.story.content.substring(0, 100)}...'
                              : widget.story.content,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Author and date
                        Row(
                          children: [
                            if (_author?.profilePicture != null)
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: FileImage(File(_author!.profilePicture!)),
                              )
                            else
                              const CircleAvatar(
                                radius: 16,
                                child: Icon(Icons.person, size: 16),
                              ),
                            
                            const SizedBox(width: 8),
                            
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _author?.name ?? 'Anonymous',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMMM d, yyyy').format(widget.story.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Like button
                        TextButton.icon(
                          onPressed: _toggleLike,
                          icon: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: _isLiked ? Colors.red : null,
                          ),
                          label: Text(
                            _likeCount.toString(),
                            style: TextStyle(
                              color: _isLiked ? Colors.red : null,
                            ),
                          ),
                        ),
                        
                        // Share button
                        IconButton(
                          onPressed: _shareStory,
                          icon: const Icon(Icons.share),
                        ),
                        
                        // More options (if owner)
                        if (isOwner && (widget.onEdit != null || widget.onDelete != null))
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit' && widget.onEdit != null) {
                                widget.onEdit!();
                              } else if (value == 'delete' && widget.onDelete != null) {
                                widget.onDelete!();
                              }
                            },
                            itemBuilder: (context) => [
                              if (widget.onEdit != null)
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
                              if (widget.onDelete != null)
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
                            icon: const Icon(Icons.more_vert),
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