// lib/screens/create_post_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final List<File> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (pickedFile != null) {
        setState(() {
          _selectedImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Error picking image. Please try again.',
        );
      }
    }
  }

  Future<void> _createPost() async {
    // Validate post content
    if (_contentController.text.trim().isEmpty) {
      DialogUtils.showErrorSnackBar(
        context, 
        message: 'Please write something for your post.',
      );
      return;
    }
    
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    if (currentUser == null) {
      DialogUtils.showErrorSnackBar(
        context, 
        message: 'You need to be logged in to create a post.',
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final databaseService = DatabaseService();
      
      // Process images - this is a simplified version
      // In a real app, you would upload these to a storage service and get URLs
      List<String> imageUrls = [];
      for (var imageFile in _selectedImages) {
        // Here you would upload image and get its URL
        // For now, we'll use the local file paths
        imageUrls.add(imageFile.path);
      }
      
      // Create post data - no groupId means it's a personal post
      final postData = {
        'userId': currentUser.id,
        'groupId': null, // No group - this is a personal post
        'content': _contentController.text.trim(),
        'images': imageUrls.isEmpty ? null : imageUrls.join(','),
        'createdAt': DateTime.now().toIso8601String(),
        'likesCount': 0,
        'commentsCount': 0,
      };
      
      // Insert post into database
      final postId = await databaseService.insertPost(postData);
      
      setState(() {
        _isLoading = false;
      });
      
      if (postId > 0 && mounted) {
        DialogUtils.showSuccessSnackBar(
          context, 
          message: 'Post created successfully!',
        );
        
        // Return to previous screen with success result
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to create post');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        DialogUtils.showErrorSnackBar(
          context, 
          message: 'Error creating post: ${e.toString()}',
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
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
              : const Text(
                  'Post',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info row
              Row(
                children: [
                  const CircleAvatar(
                    // In a real app, show user's profile picture
                    child: Icon(Icons.person),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    Provider.of<AuthService>(context).currentUser?.name ?? 'User',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Post content text field
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  border: InputBorder.none,
                ),
                maxLines: 10,
                minLines: 3,
              ),
              
              // Selected images preview
              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Selected Images (${_selectedImages.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(_selectedImages[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(127),
                                  shape: BoxShape.circle,
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
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.photo_library),
              onPressed: _pickImage,
              tooltip: 'Add Image',
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: () async {
                try {
                  final pickedFile = await _imagePicker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 70,
                  );
                  
                  if (pickedFile != null) {
                    setState(() {
                      _selectedImages.add(File(pickedFile.path));
                    });
                  }
                } catch (e) {
                  print('Error taking photo: $e');
                  if (mounted) {
                    DialogUtils.showErrorSnackBar(
                      context,
                      message: 'Error taking photo. Please try again.',
                    );
                  }
                }
              },
              tooltip: 'Take Photo',
            ),
            const Spacer(),
            // Show post button in the bottom bar as well
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}