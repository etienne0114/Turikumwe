// lib/screens/groups/create_group_post_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/services/service_locator.dart';
import 'package:turikumwe/utils/dialog_utils.dart';

class CreateGroupPostScreen extends StatefulWidget {
  final Group group;

  const CreateGroupPostScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<CreateGroupPostScreen> createState() => _CreateGroupPostScreenState();
}

class _CreateGroupPostScreenState extends State<CreateGroupPostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final List<File> _selectedImages = [];
  bool _isLoading = false;
  bool _isMember = false;

  @override
  void initState() {
    super.initState();
    _checkMembership();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _checkMembership() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser == null) {
      Navigator.pop(context);
      return;
    }

    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      final membership = await databaseService.getGroupMembership(
        widget.group.id,
        authService.currentUser!.id,
      );

      if (mounted) {
        setState(() {
          _isMember = membership != null;
        });
        
        if (!_isMember) {
          DialogUtils.showErrorSnackBar(
            context,
            message: 'You must be a member to post in this group',
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Failed to check membership status',
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      maxHeight: 1200,
      maxWidth: 1200,
      imageQuality: 85,
    );

    if (images.isNotEmpty) {
      setState(() {
        for (var image in images) {
          if (_selectedImages.length < 10) { // Limit to 10 images
            _selectedImages.add(File(image.path));
          } else {
            break;
          }
        }
      });
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      maxHeight: 1200,
      maxWidth: 1200,
      imageQuality: 85,
    );

    if (photo != null) {
      setState(() {
        if (_selectedImages.length < 10) { // Limit to 10 images
          _selectedImages.add(File(photo.path));
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _createPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedImages.isEmpty) {
      DialogUtils.showErrorSnackBar(
        context,
        message: 'Please add some text or images to your post',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      
      // In a real app, upload images to storage
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        // This is a placeholder. In a real app, you would upload each image
        // imageUrls = await Future.wait(_selectedImages.map(
        //   (file) => ServiceLocator.storage.uploadImage(file)
        // ));
        
        // For demo, we'll just use placeholders
        imageUrls = _selectedImages.map((file) => 'placeholder_image_url').toList();
      }
      
      // Create post
      final post = {
        'userId': authService.currentUser!.id,
        'groupId': widget.group.id,
        'content': content,
        'images': imageUrls.isNotEmpty ? imageUrls.join(',') : null,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      final postId = await databaseService.insertPost(post);
      
      setState(() => _isLoading = false);
      
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
            message: 'Failed to create post',
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
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
    final user = Provider.of<AuthService>(context).currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Post to ${widget.group.name}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // User info section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: user?.profilePicture != null
                              ? NetworkImage(user!.profilePicture!)
                              : null,
                          child: user?.profilePicture == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Anonymous',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Posting to ${widget.group.name}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content input
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        hintText: "What's on your mind?",
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      minLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  
                  // Image preview
                  if (_selectedImages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildImagesGrid(),
                    ),
                  
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      elevation: 0,
                      color: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Text(
                              'Add to your post:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.photo_library, color: Colors.green),
                              onPressed: _pickImages,
                              tooltip: 'Add Photos',
                            ),
                            IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.blue),
                              onPressed: _takePhoto,
                              tooltip: 'Take Photo',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Post button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
            ),
    );
  }

  Widget _buildImagesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _selectedImages.length,
      itemBuilder: (context, index) {
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
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}