// lib/screens/event_attendees_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';

class EventAttendeesScreen extends StatefulWidget {
  final Event event;

  const EventAttendeesScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<EventAttendeesScreen> createState() => _EventAttendeesScreenState();
}

class _EventAttendeesScreenState extends State<EventAttendeesScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _registrations = [];
  List<Map<String, dynamic>> _attendees = [];
  bool _isLoading = true;
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAttendees();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadAttendees() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load registrations with questionnaire responses and payment status
      final registrations = await DatabaseService().getEventRegistrations(widget.event.id);
      
      // Load attendees (confirmed attendees in the event)
      final attendeeList = <Map<String, dynamic>>[];
      if (widget.event.attendeesIds != null && widget.event.attendeesIds!.isNotEmpty) {
        final attendeeIds = widget.event.attendeesIds!
            .split(',')
            .where((id) => id.trim().isNotEmpty)
            .map((id) => int.parse(id.trim()))
            .toList();
        
        for (final id in attendeeIds) {
          final user = await DatabaseService().getUserById(id);
          if (user != null) {
            attendeeList.add({
              'id': user.id,
              'name': user.name,
              'email': user.email,
              'phoneNumber': user.phoneNumber,
              'profilePicture': user.profilePicture,
            });
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _registrations = registrations;
          _attendees = attendeeList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading attendees: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Failed to load attendees',
        );
      }
    }
  }
  
  void _viewQuestionnaireResponses(Map<String, dynamic> registration) {
    final responsesJson = registration['questionnaireResponses'];
    
    if (responsesJson == null || responsesJson.isEmpty) {
      DialogUtils.showInfoSnackBar(
        context,
        message: 'No questionnaire responses available',
      );
      return;
    }
    
    try {
      final responses = jsonDecode(responsesJson);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Responses from ${registration['name']}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in responses.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.value?.toString() ?? 'No response',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error parsing questionnaire responses: $e');
      DialogUtils.showErrorSnackBar(
        context,
        message: 'Error displaying responses',
      );
    }
  }
  
  Future<void> _approveAttendee(int userId) async {
    try {
      final success = await DatabaseService().addUserToEventAttendees(
        userId,
        widget.event.id,
      );
      
      if (success) {
        DialogUtils.showSuccessSnackBar(
          context,
          message: 'Attendee approved!',
        );
        _loadAttendees();
      } else {
        throw Exception('Failed to approve attendee');
      }
    } catch (e) {
      debugPrint('Error approving attendee: $e');
      DialogUtils.showErrorSnackBar(
        context,
        message: 'Failed to approve attendee',
      );
    }
  }
  
  Future<void> _removeAttendee(int userId) async {
    final confirm = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Remove Attendee',
      message: 'Are you sure you want to remove this attendee?',
      confirmText: 'Remove',
      cancelText: 'Cancel',
      isDangerous: true,
    );
    
    if (!confirm) return;
    
    try {
      final success = await DatabaseService().removeUserFromEventAttendees(
        userId,
        widget.event.id,
      );
      
      if (success) {
        DialogUtils.showSuccessSnackBar(
          context,
          message: 'Attendee removed',
        );
        _loadAttendees();
      } else {
        throw Exception('Failed to remove attendee');
      }
    } catch (e) {
      debugPrint('Error removing attendee: $e');
      DialogUtils.showErrorSnackBar(
        context,
        message: 'Failed to remove attendee',
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Attendees'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Attendees'),
            Tab(text: 'Registrations'),
          ],
        ),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              // Attendees tab
              _buildAttendeesTab(),
              
              // Registrations tab
              _buildRegistrationsTab(),
            ],
          ),
    );
  }
  
  Widget _buildAttendeesTab() {
    if (_attendees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No attendees yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadAttendees,
      child: ListView.builder(
        itemCount: _attendees.length,
        itemBuilder: (context, index) {
          final attendee = _attendees[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: attendee['profilePicture'] != null
                ? NetworkImage(attendee['profilePicture']) as ImageProvider
                : null,
              child: attendee['profilePicture'] == null
                ? Text((attendee['name'] as String)[0].toUpperCase())
                : null,
            ),
            title: Text(attendee['name']),
            subtitle: Text(attendee['email']),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeAttendee(attendee['id']),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildRegistrationsTab() {
    if (_registrations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.how_to_reg,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No registrations yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadAttendees,
      child: ListView.builder(
        itemCount: _registrations.length,
        itemBuilder: (context, index) {
          final registration = _registrations[index];
          final bool hasPaid = registration['paymentStatus'] == 'completed';
          final bool hasResponses = registration['questionnaireResponses'] != null;
          final int userId = registration['userId'];
          
          // Check if this user is already an attendee
          final bool isAttendee = _attendees.any((a) => a['id'] == userId);
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: registration['profilePicture'] != null
                          ? NetworkImage(registration['profilePicture']) as ImageProvider
                          : null,
                        child: registration['profilePicture'] == null
                          ? Text((registration['name'] as String)[0].toUpperCase())
                          : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              registration['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              registration['email'],
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Status chips
                  Wrap(
                    spacing: 8,
                    children: [
                      if (widget.event.price != null && widget.event.price! > 0)
                        Chip(
                          label: Text(hasPaid ? 'Paid' : 'Not Paid'),
                          backgroundColor: hasPaid ? Colors.green.shade100 : Colors.red.shade100,
                          labelStyle: TextStyle(
                            color: hasPaid ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                          avatar: Icon(
                            hasPaid ? Icons.check_circle : Icons.money_off,
                            color: hasPaid ? Colors.green : Colors.red,
                            size: 16,
                          ),
                        ),
                      if (isAttendee)
                        Chip(
                          label: const Text('Approved'),
                          backgroundColor: Colors.blue.shade100,
                          labelStyle: TextStyle(color: Colors.blue.shade800),
                          avatar: Icon(
                            Icons.verified,
                            color: Colors.blue.shade800,
                            size: 16,
                          ),
                        ),
                      if (hasResponses)
                        ActionChip(
                          label: const Text('View Responses'),
                          avatar: const Icon(Icons.question_answer, size: 16),
                          onPressed: () => _viewQuestionnaireResponses(registration),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isAttendee && ((widget.event.price == null || widget.event.price! <= 0) || hasPaid))
                        TextButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.green,
                          ),
                          onPressed: () => _approveAttendee(userId),
                        ),
                      if (isAttendee)
                        TextButton.icon(
                          icon: const Icon(Icons.close),
                          label: const Text('Remove'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: () => _removeAttendee(userId),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}