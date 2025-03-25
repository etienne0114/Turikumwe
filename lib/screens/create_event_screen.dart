// lib/screens/create_event_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
import 'package:turikumwe/utils/string_utils.dart';
import 'package:turikumwe/utils/validators.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CreateEventScreen extends StatefulWidget {
  final int? groupId; // Optional: If creating an event for a specific group

  const CreateEventScreen({Key? key, this.groupId}) : super(key: key);

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  File? _imageFile;
  String? _selectedDistrict;
  String _selectedCategory = 'General';
  bool _isLoading = false;
  
  final List<String> _rwandanDistricts = [
    'Bugesera', 'Burera', 'Gakenke', 'Gasabo', 'Gatsibo',
    'Gicumbi', 'Gisagara', 'Huye', 'Kamonyi', 'Karongi',
    'Kayonza', 'Kicukiro', 'Kirehe', 'Muhanga', 'Musanze',
    'Ngoma', 'Ngororero', 'Nyabihu', 'Nyagatare', 'Nyamagabe',
    'Nyamasheke', 'Nyanza', 'Nyarugenge', 'Nyaruguru', 'Rubavu',
    'Ruhango', 'Rulindo', 'Rusizi', 'Rutsiro', 'Rwamagana',
  ];
  
  final List<String> _eventCategories = [
    'General',
    'Community',
    'Education',
    'Health',
    'Social',
    'Sports',
    'Culture',
    'Business',
    'Technology',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
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
        _imageFile = File(image.path);
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  DateTime _combineDateAndTime() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

 
Future<void> _createEvent() async {
  if (_formKey.currentState!.validate()) {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
      if (currentUser == null) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'You need to be logged in to create an event',
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final eventDateTime = _combineDateAndTime();
      
      // Create a new event
      final eventMap = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'date': eventDateTime.toIso8601String(),
        'location': _locationController.text.trim(),
        'image': null, // In a real app, this would be the uploaded image URL
        'groupId': widget.groupId,
        'organizerId': currentUser.id,
        'attendeesIds': '${currentUser.id}', // Organizer automatically attends
        'district': _selectedDistrict,
        'category': _selectedCategory,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      print("Creating event with data: $eventMap"); // Debug log
      
      // Create a new event
      final eventId = await DatabaseService().insertEvent(eventMap);

      setState(() {
        _isLoading = false;
      });

      if (eventId > 0) {
        if (mounted) {
          DialogUtils.showSuccessSnackBar(
            context,
            message: 'Event created successfully!',
          );
          
          // Navigate back to previous screen
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          DialogUtils.showErrorSnackBar(
            context,
            message: 'Failed to create event. Please try again.',
          );
        }
      }
    } catch (e) {
      print('Error creating event: $e'); // Debug log
      if (mounted) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'An error occurred: ${e.toString()}',
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createEvent,
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
              // Event Image
              InkWell(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    image: _imageFile != null
                        ? DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imageFile == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'Add Event Photo',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              
              // Event Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Event Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) => Validators.validateRequired(value, 'Event title'),
              ),
              const SizedBox(height: 16),
              
              // Date and Time Row
              Row(
                children: [
                  // Date Picker
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('MMM d, yyyy').format(_selectedDate),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Time Picker
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          _selectedTime.format(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) => Validators.validateRequired(value, 'Location'),
              ),
              const SizedBox(height: 16),
              
              // District Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'District',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map),
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
                validator: (value) => Validators.validateRequired(value, 'District'),
              ),
              const SizedBox(height: 16),
              
              // Category Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                value: _selectedCategory,
                items: _eventCategories.map((category) {
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
                validator: (value) => Validators.validateRequired(value, 'Description'),
              ),
              const SizedBox(height: 24),
              
              // Create Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createEvent,
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
                          'Create Event',
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