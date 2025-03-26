// lib/screens/groups/create_group_post_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CreateGroupPostScreen extends StatefulWidget {
  final Group group;

  const CreateGroupPostScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<CreateGroupPostScreen> createState() => _CreateGroupPostScreenState();
}

class _CreateGroupPostScreenState extends State<CreateGroupPostScreen> {
  final _contentController = TextEditingController();
  final List<File> _selectedImages = [];
  bool _isLoading = false;
  
  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxHeight: 1200,
      maxWidth: 1200,
    );
    
    if (image != null) {
      setState(() {
        _selectedImages.add(File(image.path));
      });
    }
  }
  
  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      maxHeight: 1200,
      maxWidth: 1200,
    );
    
    if (photo != null) {
      setState(() {
        _selectedImages.add(File(photo.path));
      });
    }
  }
  
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }
  
  Future<void> _createPost() async {
    if (_contentController.text.trim().isEmpty) {
      DialogUtils.showErrorSnackBar(
        context,
        message: 'Please add some text to your post',
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
      if (currentUser == null) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'You need to be logged in to create a post',
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // In a real app, you would upload the images to storage
      // and get URLs back to store in the database
      List<String>? imageUrls;
      if (_selectedImages.isNotEmpty) {
        // Simulate image URLs for this demo
        imageUrls = List.generate(
          _selectedImages.length, 
          (index) => 'https://example.com/image_$index.jpg'
        );
      }
      
      final postMap = {
        'userId': currentUser.id,
        'groupId': widget.group.id,
        'content': _contentController.text.trim(),
        'images': imageUrls?.join(','),
        'createdAt': DateTime.now().toIso8601String(),
        'likesCount': 0,
        'commentsCount': 0,
      };
      
      final postId = await DatabaseService().insertPost(postMap);
      
      setState(() {
        _isLoading = false;
      });
      
      if (postId > 0) {
        if (mounted) {
          DialogUtils.showSuccessSnackBar(
            context,
            message: 'Post created successfully!',
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          DialogUtils.showErrorSnackBar(
            context,
            message: 'Failed to create post. Please try again.',
          );
        }
      }
    } catch (e) {
      print('Error creating post: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'An error occurred: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context).currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Post', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80), // Extra padding at bottom for button
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group name indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.group,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Posting to ${widget.group.name}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // User info and post content
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: currentUser?.profilePicture != null
                          ? NetworkImage(currentUser!.profilePicture!)
                          : null,
                      child: currentUser?.profilePicture == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          hintText: 'What\'s on your mind?',
                          border: InputBorder.none,
                        ),
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                  ],
                ),
                
                // Selected images grid
                if (_selectedImages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: List.generate(_selectedImages.length, (index) {
                      return Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(_selectedImages[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                
                // Add to post options
                const Text(
                  'Add to your post',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildAddToPostButton(
                      icon: Icons.photo_library,
                      color: Colors.green,
                      label: 'Photos',
                      onTap: _pickImage,
                    ),
                    _buildAddToPostButton(
                      icon: Icons.camera_alt,
                      color: const Color.fromARGB(255, 1, 120, 232),
                      label: 'Camera',
                      onTap: _takePhoto,
                    ),
                    // Add more options as needed
                  ],
                ),
              ],
            ),
          ),
          // Floating post button at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'POST',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAddToPostButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}