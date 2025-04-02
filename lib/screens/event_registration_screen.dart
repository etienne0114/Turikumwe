// lib/screens/event_registration_screen.dart
import 'dart:convert';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/events_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
import 'package:turikumwe/widgets/payment_bottom_sheet.dart';

class EventRegistrationScreen extends StatefulWidget {
  final Event event;
  final VoidCallback? onRegistrationComplete;

  const EventRegistrationScreen({
    Key? key,
    required this.event,
    this.onRegistrationComplete,
  }) : super(key: key);

  @override
  State<EventRegistrationScreen> createState() =>
      _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends State<EventRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _responses = <String, dynamic>{};
  bool _isLoading = false;
  List<Map<String, dynamic>> _questionnaire = [];
  bool _isPaid = false;
  bool _hasQuestionnaire = false;

  @override
  void initState() {
    super.initState();
    _loadEventData();
  }

  // Updated _loadEventData method in event_registration_screen.dart
// This fixes the type conversion issues

  void _loadEventData() {
    // Check if event is paid
    _isPaid = widget.event.price != null && widget.event.price! > 0;

    // Parse questionnaire data if available
    _hasQuestionnaire = widget.event.hasQuestionnaire;

    if (_hasQuestionnaire && widget.event.questionnaireData != null) {
      _questionnaire = _parseQuestionnaireData();
    }
  }

  List<Map<String, dynamic>> _parseQuestionnaireData() {
    if (widget.event.questionnaireData == null) {
      return [];
    }

    try {
      final result = <Map<String, dynamic>>[];

      // Handle different data formats
      if (widget.event.questionnaireData is String) {
        // If it's a string, try to parse as JSON
        final dynamic parsed =
            jsonDecode(widget.event.questionnaireData as String);

        if (parsed is Map) {
          // Convert map format (question -> details) to list format
          (parsed as Map<String, dynamic>).forEach((question, details) {
            if (details is Map) {
              result.add({
                'question': question,
                'type': details['type'] ?? 'text',
                'required': details['required'] ?? true,
                'options': details['options'] is List
                    ? List<String>.from(
                        (details['options'] as List).map((e) => e.toString()))
                    : <String>[],
              });
            }
          });
        } else if (parsed is List) {
          // If it's already a list, just convert each item to the right format
          for (final item in parsed) {
            if (item is Map && item.containsKey('question')) {
              result.add({
                'question': item['question'],
                'type': item['type'] ?? 'text',
                'required': item['required'] ?? true,
                'options': item['options'] is List
                    ? List<String>.from(
                        (item['options'] as List).map((e) => e.toString()))
                    : <String>[],
              });
            }
          }
        }
      } else if (widget.event.questionnaireData is Map) {
        // If it's already a Map, convert to list format
        (widget.event.questionnaireData as Map<String, dynamic>)
            .forEach((question, details) {
          if (details is Map) {
            result.add({
              'question': question,
              'type': details['type'] ?? 'text',
              'required': details['required'] ?? true,
              'options': details['options'] is List
                  ? List<String>.from(
                      (details['options'] as List).map((e) => e.toString()))
                  : <String>[],
            });
          }
        });
      } else if (widget.event.questionnaireData is List) {
        // If it's already a list, make sure each item has the right structure
        for (final item in widget.event.questionnaireData as List) {
          if (item is Map && item.containsKey('question')) {
            result.add({
              'question': item['question'],
              'type': item['type'] ?? 'text',
              'required': item['required'] ?? true,
              'options': item['options'] is List
                  ? List<String>.from(
                      (item['options'] as List).map((e) => e.toString()))
                  : <String>[],
            });
          }
        }
      }

      return result;
    } catch (e) {
      debugPrint('Error parsing questionnaire data: $e');
      return [];
    }
  }

 Future<void> _submitRegistration() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      throw Exception('User not logged in');
    }

    // Record the registration in the database
    await DatabaseService().registerForEvent({
      'eventId': widget.event.id,
      'userId': currentUser.id,
      'registrationDate': DateTime.now().toIso8601String(),
      'status': _isPaid ? 'pending_payment' : 'registered', // For free events, mark as registered
      'paymentStatus': _isPaid ? 'pending' : 'completed', // For free events, mark payment as completed
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // Save questionnaire responses if any
    if (_hasQuestionnaire && _questionnaire.isNotEmpty) {
      final responsesJson = jsonEncode(_responses);
      await DatabaseService().saveQuestionnaireResponses(
        widget.event.id,
        currentUser.id,
        responsesJson,
      );
    }

    // For free events, automatically add user to attendees
    if (!_isPaid) {
      final success = await DatabaseService().addUserToEventAttendees(
        currentUser.id,
        widget.event.id,
      );

      if (success && mounted) {
        DialogUtils.showSuccessSnackBar(
          context,
          message: 'Registration successful! You are now registered for this event.',
        );

        // Call the callback
        if (widget.onRegistrationComplete != null) {
          widget.onRegistrationComplete!();
        }

        // Navigate back to previous screen, the callback will handle refresh
        Navigator.pop(context, true);
      } else if (mounted) {
        throw Exception('Failed to register for event');
      }
    } else {
      // For paid events, show payment sheet
      if (mounted) {
        _showPaymentSheet(currentUser);
      }
    }
  } catch (e) {
    debugPrint('Error during registration: $e');
    if (mounted) {
      DialogUtils.showErrorSnackBar(
        context,
        message: 'Registration failed. Please try again.',
      );
    }
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  @override
  void dispose() {
    super.dispose();
  }


  void _showPaymentSheet(User currentUser) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentBottomSheet(
        event: widget.event,
        onPaymentComplete: () {
          // Record payment
          DatabaseService().recordEventPayment({
            'eventId': widget.event.id,
            'userId': currentUser.id,
            'paymentStatus': 'completed',
            'paymentReference': 'REF${DateTime.now().millisecondsSinceEpoch}',
            'paymentAmount': widget.event.price,
            'paymentDate': DateTime.now().toIso8601String(),
          });

          // Call the callback
          if (widget.onRegistrationComplete != null) {
            widget.onRegistrationComplete!();
          }

          // Navigate back to previous screen
          Navigator.pop(context, true);
        },
        // Pass questionnaire responses to payment sheet
        questionnaireResponses:
            _hasQuestionnaire ? jsonEncode(_responses) : null,
      ),
    );
  }

  Widget _buildQuestionnaireForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title for questionnaire section
        const Padding(
          padding: EdgeInsets.only(bottom: 16.0),
          child: Text(
            'Registration Questions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Build form fields for each question
        ...List.generate(_questionnaire.length, (index) {
          final question = _questionnaire[index];
          final questionText = question['question'] as String;
          final questionType = question['type'] as String;
          final isRequired = question['required'] as bool? ?? true;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$questionText ${isRequired ? '*' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Different form fields based on question type
                if (questionType == 'text')
                  TextFormField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Your answer',
                    ),
                    validator: isRequired
                        ? (value) => value == null || value.isEmpty
                            ? 'Please answer this question'
                            : null
                        : null,
                    onChanged: (value) {
                      _responses[questionText] = value;
                    },
                  ),

                if (questionType == 'number')
                  TextFormField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Your answer (number)',
                    ),
                    keyboardType: TextInputType.number,
                    validator: isRequired
                        ? (value) => value == null || value.isEmpty
                            ? 'Please answer this question'
                            : null
                        : null,
                    onChanged: (value) {
                      _responses[questionText] = value;
                    },
                  ),

                if (questionType == 'choice' && question.containsKey('options'))
                  Column(
                    children: List.generate(
                      (question['options'] as List).length,
                      (optionIndex) {
                        final option = question['options'][optionIndex];
                        return RadioListTile<String>(
                          title: Text(option),
                          value: option,
                          groupValue: _responses[questionText],
                          onChanged: (value) {
                            setState(() {
                              _responses[questionText] = value;
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        );
                      },
                    ),
                  ),

                if (questionType == 'checkbox')
                  CheckboxListTile(
                    title: const Text('Yes'),
                    value: _responses[questionText] == true,
                    onChanged: (value) {
                      setState(() {
                        _responses[questionText] = value;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Registration'),
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
                    // Event details card
                    Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event image
                          if (widget.event.image != null &&
                              widget.event.image!.isNotEmpty)
                            Image.network(
                              widget.event.image!,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                height: 150,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child:
                                      Icon(Icons.image_not_supported, size: 50),
                                ),
                              ),
                            ),

                          // Event details
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.event.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('EEEE, MMMM d, y • h:mm a')
                                          .format(widget.event.date),
                                      style: TextStyle(
                                          color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.event.location,
                                      style: TextStyle(
                                          color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                                if (_isPaid) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.green.shade200),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.payment,
                                            size: 16, color: Colors.green),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Paid Event: ${widget.event.price!.toStringAsFixed(0)} RWF',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Questionnaire form
                    if (_hasQuestionnaire && _questionnaire.isNotEmpty)
                      _buildQuestionnaireForm(),

                    // Register button
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isLoading ? null : _submitRegistration,
                        child: Text(_isPaid
                            ? 'Continue to Payment (${widget.event.price!.toStringAsFixed(0)} RWF)'
                            : 'Register for Event'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
