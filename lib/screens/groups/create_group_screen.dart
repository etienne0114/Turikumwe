// lib/screens/groups/create_group_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
import 'dart:io';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  String? _selectedDistrict;
  bool _isPublic = true;
  File? _groupImage;
  bool _isLoading = false;

  // Categories and Districts data
  final List<String> _categories = [
    'Community',
    'Education',
    'Health',
    'Business',
    'Technology',
    'Environment',
    'Arts & Culture',
    'Sports',
    'Religion',
    'Other'
  ];

  final List<String> _rwandanDistricts = [
    'Bugesera', 'Burera', 'Gakenke', 'Gasabo', 'Gatsibo',
    'Gicumbi', 'Gisagara', 'Huye', 'Kamonyi', 'Karongi',
    'Kayonza', 'Kicukiro', 'Kirehe', 'Muhanga', 'Musanze',
    'Ngoma', 'Ngororero', 'Nyabihu', 'Nyagatare', 'Nyamagabe',
    'Nyamasheke', 'Nyanza', 'Nyarugenge', 'Nyaruguru', 'Rubavu',
    'Ruhango', 'Rulindo', 'Rusizi', 'Rutsiro', 'Rwamagana',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxHeight: 800,
      maxWidth: 800,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() {
        _groupImage = File(image.path);
      });
    }
  }

  Future<void> _createGroup() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategory == null) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Please select a category for your group',
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
            message: 'You need to be logged in to create a group',
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // In a real app, you would upload the image to storage
        // For this demo, we'll just store a placeholder or null
        
        // Create a new group
        final groupMap = {
          'name': _nameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'image': null, // In a real app, this would be the uploaded image URL
          'category': _selectedCategory,
          'district': _selectedDistrict,
          'membersCount': 1, // Creator is the first member
          'isPublic': _isPublic ? 1 : 0,
          'createdAt': DateTime.now().toIso8601String(),
        };

        print("Creating group with data: $groupMap"); // Debug log
        
        // Insert the group and get its ID
        final groupId = await DatabaseService().insertGroup(groupMap);

        if (groupId > 0) {
          // Add the creator as a member and admin
          final memberMap = {
            'groupId': groupId,
            'userId': currentUser.id,
            'isAdmin': 1, // Creator is admin
            'joinedAt': DateTime.now().toIso8601String(),
          };
          
          await DatabaseService().addGroupMember(memberMap);
          
          setState(() {
            _isLoading = false;
          });

          if (mounted) {
            DialogUtils.showSuccessSnackBar(
              context,
              message: 'Group created successfully!',
            );
            
            // Navigate back to previous screen with success result
            Navigator.pop(context, true);
          }
        } else {
          setState(() {
            _isLoading = false;
          });
          
          if (mounted) {
            DialogUtils.showErrorSnackBar(
              context,
              message: 'Failed to create group. Please try again.',
            );
          }
        }
      } catch (e) {
        print('Error creating group: $e'); // Debug log
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createGroup,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Image
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _groupImage != null ? FileImage(_groupImage!) : null,
                    child: _groupImage == null
                        ? Icon(
                            Icons.add_a_photo,
                            size: 40,
                            color: Colors.grey[600],
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _pickImage,
                  child: const Text('Add Group Photo'),
                ),
              ),
              const SizedBox(height: 16),
              
              // Group Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a group name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Category Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                hint: const Text('Select category'),
                value: _selectedCategory,
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // District Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'District (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                hint: const Text('Select district'),
                value: _selectedDistrict,
                items: _rwandanDistricts.map((district) {
                  return DropdownMenuItem(
                    value: district,
                    child: Text(district),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDistrict = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Group Privacy
              Card(
                elevation: 0,
                color: Colors.grey[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Group Privacy',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Public'),
                              subtitle: const Text('Anyone can join'),
                              value: true,
                              groupValue: _isPublic,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _isPublic = value;
                                  });
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Private'),
                              subtitle: const Text('Invite only'),
                              value: false,
                              groupValue: _isPublic,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _isPublic = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a group description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Create Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createGroup,
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
                          'Create Group',
                          style: TextStyle(fontSize: 16),
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