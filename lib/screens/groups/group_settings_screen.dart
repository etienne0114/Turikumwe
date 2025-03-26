// lib/screens/groups/group_members_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/services/service_locator.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
import 'package:turikumwe/utils/image_utils.dart';
import 'package:turikumwe/utils/logger.dart';

class GroupSettingsScreen extends StatefulWidget {
  final Group group;

  const GroupSettingsScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  late Group _group;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _districtController;
  String? _newImagePath;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _nameController = TextEditingController(text: _group.name);
    _descriptionController = TextEditingController(text: _group.description);
    _categoryController = TextEditingController(text: _group.category);
    _districtController = TextEditingController(text: _group.district ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  Future<void> _updateGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Upload new image if selected
      String? imageUrl = _group.image;
      if (_newImagePath != null) {
        imageUrl = await ServiceLocator.storage.uploadImage(File(_newImagePath!));
      }

      final updatedGroup = Group(
        id: _group.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        image: imageUrl,
        category: _categoryController.text.trim(),
        district: _districtController.text.trim().isNotEmpty
            ? _districtController.text.trim()
            : null,
        membersCount: _group.membersCount,
        createdAt: _group.createdAt,
      );

      await ServiceLocator.database.updateGroup(updatedGroup.toMap());

      if (mounted) {
        setState(() => _group = updatedGroup);
        DialogUtils.showSuccessSnackBar(context, message: 'Group updated');
        Navigator.pop(context, updatedGroup);
      }
    } catch (e, stackTrace) {
      Logger.e('Error updating group', error: e, stackTrace: stackTrace);
      if (mounted) {
        DialogUtils.showErrorSnackBar(context, message: 'Update failed');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (pickedFile != null && mounted) {
        setState(() => _newImagePath = pickedFile.path);
      }
    } catch (e, stackTrace) {
      Logger.e('Error picking image', error: e, stackTrace: stackTrace);
      if (mounted) {
        DialogUtils.showErrorSnackBar(context, message: 'Image selection failed');
      }
    }
  }

  Future<void> _deleteGroup() async {
    final confirm = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Delete Group',
      message: 'This will permanently delete the group and all its content',
      confirmText: 'Delete',
      cancelText: 'Cancel', isDangerous: true,
    );

    if (!confirm || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await ServiceLocator.database.deleteGroup(_group.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e, stackTrace) {
      Logger.e('Error deleting group', error: e, stackTrace: stackTrace);
      if (mounted) {
        DialogUtils.showErrorSnackBar(context, message: 'Deletion failed');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _updateGroup,
          ),
        ],
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
                    _buildImagePicker(),
                    const SizedBox(height: 24),
                    _buildNameField(),
                    const SizedBox(height: 16),
                    _buildDescriptionField(),
                    const SizedBox(height: 16),
                    _buildCategoryField(),
                    const SizedBox(height: 16),
                    _buildDistrictField(),
                    const SizedBox(height: 24),
                    _buildGroupInfoSection(),
                    _buildDangerZone(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _isLoading ? null : _pickImage,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: _newImagePath != null
                  ? FileImage(File(_newImagePath!))
                  : (_group.image != null
                      ? NetworkImage(_group.image!) as ImageProvider<Object>
                      : null),
              child: _group.image == null && _newImagePath == null
                  ? const Icon(Icons.group, size: 60)
                  : null,
            ),
            if (!_isLoading)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Group Name',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.group),
      ),
      validator: (value) => value?.trim().isEmpty ?? true
          ? 'Please enter a group name'
          : null,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.description),
      ),
      maxLines: 3,
      validator: (value) => value?.trim().isEmpty ?? true
          ? 'Please enter a description'
          : null,
    );
  }

  Widget _buildCategoryField() {
    return TextFormField(
      controller: _categoryController,
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.category),
      ),
      validator: (value) => value?.trim().isEmpty ?? true
          ? 'Please enter a category'
          : null,
    );
  }

  Widget _buildDistrictField() {
    return TextFormField(
      controller: _districtController,
      decoration: const InputDecoration(
        labelText: 'District (Optional)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_on),
      ),
    );
  }

  Widget _buildGroupInfoSection() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.people),
          title: const Text('Members'),
          trailing: Text('${_group.membersCount}'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: const Text('Created On'),
          trailing: Text(
            DateFormat('MMM d, y').format(_group.createdAt),
          ),
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Danger Zone',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ),
        Card(
          color: Colors.red[50],
          child: ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text(
              'Delete Group',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Permanently delete this group and all its content'),
            onTap: _isLoading ? null : _deleteGroup,
          ),
        ),
      ],
    );
  }
}