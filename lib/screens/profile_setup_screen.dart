// lib/screens/profile_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
// import 'package:turikumwe/screens/home_screen.dart';
import 'package:turikumwe/screens/main_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/widgets/custom_button.dart';
import 'dart:io';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({Key? key}) : super(key: key);

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();

  String? _selectedDistrict;
  File? _profileImage;
  bool _isLoading = false;

  final List<String> _rwandanDistricts = [
    'Bugesera',
    'Burera',
    'Gakenke',
    'Gasabo',
    'Gatsibo',
    'Gicumbi',
    'Gisagara',
    'Huye',
    'Kamonyi',
    'Karongi',
    'Kayonza',
    'Kicukiro',
    'Kirehe',
    'Muhanga',
    'Musanze',
    'Ngoma',
    'Ngororero',
    'Nyabihu',
    'Nyagatare',
    'Nyamagabe',
    'Nyamasheke',
    'Nyanza',
    'Nyarugenge',
    'Nyaruguru',
    'Rubavu',
    'Ruhango',
    'Rulindo',
    'Rusizi',
    'Rutsiro',
    'Rwamagana',
  ];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // In a real app, you would upload the image to storage
      // and get a URL back, then save that URL to the user profile

      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.updateProfile({
        'phoneNumber': _phoneController.text.trim(),
        'district': _selectedDistrict,
        'bio': _bioController.text.trim(),
        // 'profilePicture': would be the uploaded image URL
      });

      setState(() {
        _isLoading = false;
      });

      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save profile. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Let\'s set up your profile to help you connect with your community!',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // Profile picture
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.lightGrey,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : null,
                        child: _profileImage == null
                            ? const Icon(Icons.person,
                                size: 60, color: Colors.grey)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Phone number
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // District dropdown
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'District',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  value: _selectedDistrict,
                  hint: const Text('Select your district'),
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your district';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Bio
                TextFormField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    prefixIcon: Icon(Icons.person_outline),
                    hintText: 'Tell us about yourself...',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 30),

                // Save button
                CustomButton(
                  text: 'Save Profile',
                  isLoading: _isLoading,
                  onPressed: _saveProfile,
                ),
                const SizedBox(height: 16),

                // Skip for now
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const MainScreen()),
                    );
                  },
                  child: const Text('Skip for now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
