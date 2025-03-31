// lib/screens/create_story_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/story.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/image_utils.dart';
import 'package:path/path.dart' as path;

class CreateStoryScreen extends StatefulWidget {
  final Story? storyToEdit;

  const CreateStoryScreen({
    Key? key,
    this.storyToEdit,
  }) : super(key: key);

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  String _selectedCategory = 'Success';
  final List<String> _categories = [
    'Success',
    'Innovation',
    'Community',
    'Education',
    'Health',
    'Agriculture',
  ];
  
  final List<File> _imageFiles = [];
  List<String> _existingImages = [];
  bool _isLoading = false;
  
  final DatabaseService _databaseService = DatabaseService();
  
  @override
  void initState() {
    super.initState();
    
    // If editing, pre-fill the form
    if (widget.storyToEdit != null) {
      _titleController.text = widget.storyToEdit!.title;
      _contentController.text = widget.storyToEdit!.content;
      _selectedCategory = widget.storyToEdit!.category;
      
      // Parse existing images from comma-separated string
      if (widget.storyToEdit!.images != null && widget.storyToEdit!.images!.isNotEmpty) {
        _existingImages = List<String>.from(widget.storyToEdit!.images!);
      }
    }
  }  
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImages() async {
    try {
      final pickedImages = await ImageUtils.pickMultipleImages();
      
      if (pickedImages.isNotEmpty) {
        setState(() {
          _imageFiles.addAll(pickedImages);
        });
      }
    } catch (e) {
      print('Error picking images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: ${e.toString()}')),
      );
    }
  }
  
  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
    });
  }
  
  void _removeExistingImage(int index) {
    setState(() {
      _existingImages.removeAt(index);
    });
  }
  
  Future<String?> _saveImagesToLocalStorage() async {
    try {
      // If no new images and no existing images, return null
      if (_imageFiles.isEmpty && _existingImages.isEmpty) {
        return null;
      }
      
      // If just keeping existing images with no changes
      if (_imageFiles.isEmpty && _existingImages.isNotEmpty) {
        return _existingImages.join(',');
      }
      
      // Create app's images directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/story_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      List<String> savedImagePaths = List.from(_existingImages);
      
      // Save new images
      for (var imageFile in _imageFiles) {
        final fileName = ImageUtils.getUniqueImageName(imageFile.path);
        final savedPath = path.join(imagesDir.path, fileName);
        
        // Compress and save the image
        final compressedImage = await ImageUtils.compressImage(imageFile);
        final savedImage = await compressedImage.copy(savedPath);
        
        savedImagePaths.add(savedImage.path);
      }
      
      return savedImagePaths.join(',');
    } catch (e) {
      print('Error saving images: $e');
      return null;
    }
  }
  
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Show loading indicator
    setState(() {
      _isLoading = true;
    });
    
    try {
      final title = _titleController.text.trim();
      final content = _contentController.text.trim();
      
      // Save images and get comma-separated string of paths
      final imagesString = await _saveImagesToLocalStorage();
      
      // Get current user ID
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        throw Exception('Not logged in');
      }
      
      if (widget.storyToEdit == null) {
        // Creating a new story
        final storyData = {
          'userId': currentUser.id,
          'title': title,
          'content': content,
          'category': _selectedCategory,
          'images': imagesString,
          'createdAt': DateTime.now().toIso8601String(),
          'likesCount': 0,
        };
        
        final result = await _databaseService.insertStory(storyData);
        
        if (mounted) {
          if (result > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Story shared successfully!')),
            );
            Navigator.of(context).pop(true); // Return true to indicate success
          } else {
            throw Exception('Failed to save story');
          }
        }
      } else {
        // Updating an existing story
        final storyData = {
          'id': widget.storyToEdit!.id,
          'title': title,
          'content': content,
          'category': _selectedCategory,
          'images': imagesString,
        };
        
        final result = await _databaseService.updateStory(storyData);
        
        if (mounted) {
          if (result > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Story updated successfully!')),
            );
            Navigator.of(context).pop(true); // Return true to indicate success
          } else {
            throw Exception('Failed to update story');
          }
        }
      }
    } catch (e) {
      print('Error saving story: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.storyToEdit != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Story' : 'Share Your Story'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title field
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Content field
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Content',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 10,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your story';
                        }
                        if (value.trim().length < 50) {
                          return 'Your story should be at least 50 characters';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Image picker section
                    const Text(
                      'Add Images (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Add image button
                    OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add Images'),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Existing images preview (if editing)
                    if (_existingImages.isNotEmpty) ...[
                      const Text(
                        'Current Images:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _existingImages.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: FileImage(File(_existingImages[index])),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeExistingImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
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
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // New images preview
                    if (_imageFiles.isNotEmpty) ...[
                      const Text(
                        'New Images:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imageFiles.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: FileImage(_imageFiles[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
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
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          isEditing ? 'Update Story' : 'Share Story',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}