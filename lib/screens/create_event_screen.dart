// lib/screens/create_event_screen.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/screens/event_detail_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
import 'package:turikumwe/utils/validators.dart';
import 'package:turikumwe/helpers/event_creator.dart';
import 'package:image_picker/image_picker.dart';

class CreateEventScreen extends StatefulWidget {
  final int? groupId; // Optional: If creating an event for a specific group
  final Event? eventToEdit; // Optional: If editing an existing event

  const CreateEventScreen({Key? key, this.groupId, this.eventToEdit})
      : super(key: key);

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();

  final EventCreator _eventCreator = EventCreator();
  final DatabaseService _databaseService = DatabaseService();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  File? _imageFile;
  String? _selectedDistrict;
  String _selectedCategory = 'General';
  String _selectedPaymentMethod = 'MTN Mobile Money';
  bool _isPrivateEvent = false;
  bool _isPaidEvent = false;
  bool _isLoading = false;
  String? _existingImageUrl;
  bool isEditing = false; // Added isEditing variable

  // Questionnaire functionality
  bool _hasQuestionnaire = false;
  List<Map<String, dynamic>> _questionnaireItems = [];

  bool _validateQuestionnaire() {
    if (!_hasQuestionnaire || _questionnaireItems.isEmpty) {
      return true; // No questionnaire to validate
    }

    bool isValid = true;
    String errorMessage = '';

    // Check each questionnaire item
    for (int i = 0; i < _questionnaireItems.length; i++) {
      final item = _questionnaireItems[i];

      // Validate question text
      if (item['question'] == null ||
          item['question'].toString().trim().isEmpty) {
        errorMessage = 'Question ${i + 1} has no text';
        isValid = false;
        break;
      }

      // Validate options for multiple choice questions
      if (item['type'] == 'choice') {
        if (!item.containsKey('options') ||
            item['options'] == null ||
            !(item['options'] is List) ||
            (item['options'] as List).isEmpty) {
          errorMessage = 'Question ${i + 1} has no options';
          isValid = false;
          break;
        }

        // Check each option is not empty
        final options = item['options'] as List;
        for (int j = 0; j < options.length; j++) {
          final option = options[j];
          if (option == null || option.toString().trim().isEmpty) {
            errorMessage =
                'Question ${i + 1} has an empty option (Option ${j + 1})';
            isValid = false;
            break;
          }
        }

        if (!isValid) break;
      }
    }

    if (!isValid && mounted) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    return isValid;
  }

  // Payment methods
  final List<String> _paymentMethods = [
    'MTN Mobile Money',
    'Airtel Money',
    'Credit Card',
    'Bank Transfer',
  ];

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
  void initState() {
    super.initState();
    isEditing =
        widget.eventToEdit != null; // Set isEditing based on eventToEdit
    _initializeWithExistingEvent();
  }

  void _initializeWithExistingEvent() {
    if (widget.eventToEdit != null) {
      // Populate form with existing event data
      final event = widget.eventToEdit!;
      _titleController.text = event.title;
      _descriptionController.text = event.description;
      _locationController.text = event.location;
      _selectedDate = event.date;
      _selectedTime = TimeOfDay.fromDateTime(event.date);
      _selectedDistrict = event.district;
      _selectedCategory = event.category ?? 'General';
      _existingImageUrl = event.image;

      // Check if it's a private event
      _isPrivateEvent = event.isPrivate ?? false;

      // Set price and payment info if it's a paid event
      if (event.price != null && event.price! > 0) {
        _isPaidEvent = true;
        _priceController.text = event.price!.toString();
        _selectedPaymentMethod = event.paymentMethod ?? 'MTN Mobile Money';
      }

      // Set questionnaire data if available
      if (event.questionnaireId != null) {
        _hasQuestionnaire = true;
      }

      if (_hasQuestionnaire && event.questionnaireData != null) {
        try {
          if (event.questionnaireData is List) {
            // If it's already a list, just cast it
            _questionnaireItems = List<Map<String, dynamic>>.from(
                event.questionnaireData as List);
          } else if (event.questionnaireData is Map<String, dynamic>) {
            // If it's a map, convert it to the list format you need
            final map = event.questionnaireData as Map<String, dynamic>;
            _questionnaireItems = map.entries.map((entry) {
              final question = entry.key;
              final details = entry.value as Map<String, dynamic>;
              return {
                'question': question,
                'type': details['type'] ?? 'text',
                'required': details['required'] ?? true,
                'options': details['options'] is List
                    ? List<String>.from(details['options'] as List)
                    : <String>[],
              };
            }).toList();
          } else {
            _questionnaireItems = [];
          }
        } catch (e) {
          debugPrint('Error parsing questionnaire data: $e');
          _questionnaireItems = [];
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
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

  // Show delete confirmation
  Future<void> _showDeleteConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
            'Are you sure you want to delete this event? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteEvent();
    }
  }

  // Delete event
  Future<void> _deleteEvent() async {
    if (widget.eventToEdit == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _databaseService.deleteEvent(widget.eventToEdit!.id);

      setState(() {
        _isLoading = false;
      });

      if (result > 0 && mounted) {
        DialogUtils.showSuccessSnackBar(
          context,
          message: 'Event deleted successfully!',
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Failed to delete event. Please try again.',
        );
      }
    } catch (e) {
      debugPrint('Error deleting event: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Error deleting event: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Then validate the questionnaire if needed
    if (!_validateQuestionnaire()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;

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

        // Prepare payment info
        double? price;
        String? paymentMethod;

        if (_isPaidEvent) {
          price = double.tryParse(_priceController.text);
          paymentMethod = _selectedPaymentMethod;
        }

        // Prepare questionnaire data - ensure proper formatting
        Map<String, dynamic>? questionnaireData;
        if (_hasQuestionnaire && _questionnaireItems.isNotEmpty) {
          questionnaireData = {};
          for (var item in _questionnaireItems) {
            // Only include items with valid questions
            if (item['question'] != null &&
                item['question'].toString().trim().isNotEmpty) {
              // Use question as the key and create a details map as the value
              questionnaireData[item['question'].toString().trim()] = {
                'type': item['type'] ?? 'text',
                'required': item['required'] ?? true,
                // Ensure options is a list of strings
                'options': (item['options'] is List)
                    ? List<String>.from(
                        (item['options'] as List).map((e) => e.toString()))
                    : <String>[],
              };
            }
          }
        }

        int resultId;
        Event? createdOrUpdatedEvent;

        // Update or create event based on whether we're editing
        if (widget.eventToEdit != null) {
          // Use our helper to update the event
          final success = await _eventCreator.updateEvent(
            id: widget.eventToEdit!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            date: eventDateTime,
            location: _locationController.text.trim(),
            image: _imageFile?.path ?? _existingImageUrl,
            groupId: widget.groupId,
            district: _selectedDistrict,
            category: _selectedCategory,
            isPrivate: _isPrivateEvent,
            price: price,
            paymentMethod: _isPaidEvent ? paymentMethod : null,
            hasQuestionnaire: _hasQuestionnaire,
            questionnaireData: questionnaireData,
          );

          resultId = success ? widget.eventToEdit!.id : 0;
          if (success) {
            // Fetch the updated event
            createdOrUpdatedEvent =
                await _databaseService.getEventById(widget.eventToEdit!.id);
          }
        } else {
          // Use our helper to create a new event
          resultId = await _eventCreator.createEvent(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            date: eventDateTime,
            location: _locationController.text.trim(),
            image: _imageFile?.path ?? _existingImageUrl,
            groupId: widget.groupId,
            organizerId: currentUser.id,
            district: _selectedDistrict,
            category: _selectedCategory,
            isPrivate: _isPrivateEvent,
            price: price,
            paymentMethod: _isPaidEvent ? paymentMethod : null,
            hasQuestionnaire: _hasQuestionnaire,
            questionnaireData: questionnaireData,
          );

          if (resultId > 0) {
            // Fetch the newly created event
            createdOrUpdatedEvent =
                await _databaseService.getEventById(resultId);
          }
        }

        setState(() {
          _isLoading = false;
        });

        if (resultId > 0 && createdOrUpdatedEvent != null && mounted) {
          DialogUtils.showSuccessSnackBar(
            context,
            message: widget.eventToEdit != null
                ? 'Event updated successfully!'
                : 'Event created successfully!',
          );

          // Navigate to the event detail screen with the created/updated event
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  EventDetailScreen(event: createdOrUpdatedEvent!),
            ),
          );
        } else if (mounted) {
          DialogUtils.showErrorSnackBar(
            context,
            message: 'Failed to save event. Please try again.',
          );
        }
      } catch (e) {
        debugPrint('Error saving event: $e');
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

  // Questionnaire functionality
  void _addQuestionnaireItem() {
    setState(() {
      _questionnaireItems.add({
        'question': '',
        'type': 'text', // Default type is text
        'required': true,
        'options': <String>[], // For multiple choice questions
      });
    });
  }

  void _removeQuestionnaireItem(int index) {
    setState(() {
      _questionnaireItems.removeAt(index);
    });
  }

  Widget _buildQuestionnaireSection() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Registration Questions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Switch(
                  value: _hasQuestionnaire,
                  onChanged: (value) {
                    setState(() {
                      _hasQuestionnaire = value;
                      if (value && _questionnaireItems.isEmpty) {
                        _addQuestionnaireItem(); // Add one item by default
                      }
                    });
                  },
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            if (_hasQuestionnaire) ...[
              const SizedBox(height: 8),
              const Text(
                'Add questions for attendees to answer when they register for your event',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),

              if (_questionnaireItems.isEmpty) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No questions added yet. Click "Add Question" below to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // List of questionnaire items
                ..._questionnaireItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    color: Colors.grey.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Question ${index + 1}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () =>
                                    _removeQuestionnaireItem(index),
                                iconSize: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: item['question'] as String? ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Question',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _questionnaireItems[index]['question'] =
                                    value.trim();
                              });
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Question cannot be empty';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'Answer Type',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  value: item['type'] as String? ?? 'text',
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'text', child: Text('Text')),
                                    DropdownMenuItem(
                                        value: 'number', child: Text('Number')),
                                    DropdownMenuItem(
                                        value: 'choice',
                                        child: Text('Multiple Choice')),
                                    DropdownMenuItem(
                                        value: 'checkbox',
                                        child: Text('Checkbox')),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _questionnaireItems[index]['type'] =
                                            value;
                                        // Initialize options list if switching to choice
                                        if (value == 'choice') {
                                          if (!_questionnaireItems[index]
                                                  .containsKey('options') ||
                                              (_questionnaireItems[index]
                                                      ['options'] ==
                                                  null) ||
                                              (_questionnaireItems[index]
                                                      ['options'] as List)
                                                  .isEmpty) {
                                            _questionnaireItems[index]
                                                ['options'] = ['Option 1'];
                                          }
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: item['required'] as bool? ?? true,
                                      onChanged: (value) {
                                        setState(() {
                                          _questionnaireItems[index]
                                              ['required'] = value ?? true;
                                        });
                                      },
                                    ),
                                    const Text('Required'),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Show options list for multiple choice questions
                          if (item['type'] == 'choice' &&
                              item.containsKey('options') &&
                              item['options'] != null) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Answer Options:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            ...(item['options'] as List)
                                .asMap()
                                .entries
                                .map((optionEntry) {
                              final optionIndex = optionEntry.key;
                              final option = optionEntry.value;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: option?.toString() ?? '',
                                        decoration: InputDecoration(
                                          labelText:
                                              'Option ${optionIndex + 1}',
                                          border: const OutlineInputBorder(),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 8),
                                        ),
                                        onChanged: (value) {
                                          setState(() {
                                            _questionnaireItems[index]
                                                    ['options'][optionIndex] =
                                                value.trim();
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Option cannot be empty';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle,
                                          color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          final options =
                                              _questionnaireItems[index]
                                                  ['options'] as List;
                                          // Don't remove the last option
                                          if (options.length > 1) {
                                            options.removeAt(optionIndex);
                                          } else {
                                            // Show a message if trying to remove the last option
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Multiple choice questions must have at least one option'),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        });
                                      },
                                      iconSize: 20,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),

                            // Add option button
                            TextButton.icon(
                              icon: const Icon(Icons.add_circle,
                                  color: AppColors.primary),
                              label: const Text('Add Option'),
                              onPressed: () {
                                setState(() {
                                  (_questionnaireItems[index]['options']
                                          as List)
                                      .add('');
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 0),
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],

              // Add question button
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: _addQuestionnaireItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Question'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Build Event Visibility section
  Widget _buildVisibilitySection() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Event Visibility',
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
                    value: false,
                    groupValue: _isPrivateEvent,
                    onChanged: (value) {
                      setState(() {
                        _isPrivateEvent = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Private'),
                    value: true,
                    groupValue: _isPrivateEvent,
                    onChanged: (value) {
                      setState(() {
                        _isPrivateEvent = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
            const Text(
              'Private events are only visible to invited guests.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build Event Pricing section
  Widget _buildPricingSection() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Event Pricing',
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
                    title: const Text('Free'),
                    value: false,
                    groupValue: _isPaidEvent,
                    onChanged: (value) {
                      setState(() {
                        _isPaidEvent = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Paid'),
                    value: true,
                    groupValue: _isPaidEvent,
                    onChanged: (value) {
                      setState(() {
                        _isPaidEvent = value!;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),

            // Conditional payment fields
            if (_isPaidEvent) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price (RWF)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.money),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => _isPaidEvent
                          ? Validators.validateNumber(value, 'Price')
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Payment method
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payment),
                      ),
                      value: _selectedPaymentMethod,
                      items: _paymentMethods.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(
                            method,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedPaymentMethod = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Event' : 'Create Event'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isLoading ? null : _showDeleteConfirmation,
              tooltip: 'Delete Event',
            ),
          TextButton(
            onPressed: _isLoading ? null : _saveEvent,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    isEditing ? 'Update' : 'Create',
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context)
            .unfocus(), // Hide keyboard when tapping outside
        child: SingleChildScrollView(
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
                          : _existingImageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(_existingImageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: _imageFile == null && _existingImageUrl == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo,
                                  size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                'Add Event Photo',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          )
                        : Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.white,
                              ),
                              onPressed: _pickImage,
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    const Color.fromRGBO(0, 0, 0, 0.5),
                              ),
                            ),
                          ),
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
                  validator: (value) =>
                      Validators.validateRequired(value, 'Event title'),
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
                  validator: (value) =>
                      Validators.validateRequired(value, 'Location'),
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
                  validator: (value) =>
                      Validators.validateRequired(value, 'District'),
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

                // Event Visibility
                _buildVisibilitySection(),
                const SizedBox(height: 16),

                // Event Pricing
                _buildPricingSection(),
                const SizedBox(height: 16),

                // Questionnaire section
                _buildQuestionnaireSection(),
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
                  validator: (value) =>
                      Validators.validateRequired(value, 'Description'),
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveEvent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : Text(
                            isEditing ? 'Update Event' : 'Create Event',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),

                // Extra space at bottom for safety
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
