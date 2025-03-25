// lib/screens/event_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
import 'package:turikumwe/utils/string_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isAttending = false;
  bool _isLoading = false;
  List<int> _attendeesIds = [];
  int _organizerId = 0;
  String _organizerName = 'Event Host';

  @override
  void initState() {
    super.initState();
    _loadAttendanceStatus();
    _loadOrganizerDetails();
  }

  Future<void> _loadAttendanceStatus() async {
    setState(() {
      _isLoading = true;
    });

    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // In a real app, you would fetch this from the database
      // For now, we'll parse the attendeesIds string from the event
      if (widget.event.attendeesIds != null) {
        final attendeesIdsString = widget.event.attendeesIds!;
        final attendeesList = attendeesIdsString.split(',').map((id) => int.parse(id.trim())).toList();

        setState(() {
          _attendeesIds = attendeesList;
          _isAttending = _attendeesIds.contains(currentUser.id);
          _isLoading = false;
        });
      } else {
        setState(() {
          _attendeesIds = [];
          _isAttending = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading attendance status: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOrganizerDetails() async {
    // In a real app, you would fetch the organizer details from the database
    // For now, we'll just set the organizer ID
    setState(() {
      _organizerId = widget.event.organizerId;
    });

    try {
      final organizer = await DatabaseService().getUserById(widget.event.organizerId);
      if (organizer != null) {
        setState(() {
          _organizerName = organizer.name;
        });
      }
    } catch (e) {
      print('Error loading organizer details: $e');
    }
  }

  Future<void> _toggleAttendance() async {
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    if (currentUser == null) {
      DialogUtils.showErrorSnackBar(
        context,
        message: 'You need to be logged in to RSVP for events',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create a copy of the attendees list
      List<int> updatedAttendees = List.from(_attendeesIds);

      if (_isAttending) {
        // Remove the user from attendees
        updatedAttendees.remove(currentUser.id);
      } else {
        // Add the user to attendees
        if (!updatedAttendees.contains(currentUser.id)) {
          updatedAttendees.add(currentUser.id);
        }
      }

      // In a real app, you would update the event in the database
      // For this demo, we'll just update the local state
      final updatedEvent = {
        'id': widget.event.id,
        'attendeesIds': updatedAttendees.join(','),
      };
      
      await DatabaseService().updateEvent(updatedEvent);

      setState(() {
        _attendeesIds = updatedAttendees;
        _isAttending = !_isAttending;
        _isLoading = false;
      });

      DialogUtils.showSnackBar(
        context,
        message: _isAttending ? 'You\'re now attending this event' : 'You\'re no longer attending this event',
        backgroundColor: _isAttending ? Colors.green : Colors.grey,
      );
    } catch (e) {
      print('Error updating attendance: $e');
      setState(() {
        _isLoading = false;
      });
      
      DialogUtils.showErrorSnackBar(
        context,
        message: 'Failed to update attendance. Please try again.',
      );
    }
  }

  void _shareEvent() {
    final eventDate = DateFormat('EEEE, MMMM d, yyyy').format(widget.event.date);
    final eventTime = DateFormat('h:mm a').format(widget.event.date);
    
    final shareText = """
Join me at ${widget.event.title}!

🗓️ $eventDate at $eventTime
📍 ${widget.event.location}

${StringUtils.truncate(widget.event.description, 100)}

Download the Turikumwe app to RSVP and see more details.
""";

    Share.share(shareText);
  }

  Future<void> _openMapLocation() async {
    final location = Uri.encodeComponent(widget.event.location);
    final url = 'https://www.google.com/maps/search/?api=1&query=$location';
    
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      DialogUtils.showErrorSnackBar(
        context,
        message: 'Could not open map location',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentUserOrganizer = Provider.of<AuthService>(context).currentUser?.id == _organizerId;
    final eventDate = DateFormat('EEEE, MMMM d, yyyy').format(widget.event.date);
    final eventTime = DateFormat('h:mm a').format(widget.event.date);
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: widget.event.image != null
                  ? Image.asset(
                      widget.event.image!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppColors.primary.withOpacity(0.2),
                      child: Icon(
                        Icons.event,
                        size: 80,
                        color: AppColors.primary.withOpacity(0.8),
                      ),
                    ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _shareEvent,
              ),
              if (isCurrentUserOrganizer)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    // Navigate to edit event screen
                  },
                ),
            ],
          ),
          
          // Event details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.event.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Date and time
                  _buildInfoRow(
                    icon: Icons.calendar_today,
                    title: 'Date & Time',
                    subtitle: '$eventDate\n$eventTime',
                  ),
                  const SizedBox(height: 12),
                  
                  // Location with map link
                  InkWell(
                    onTap: _openMapLocation,
                    child: _buildInfoRow(
                      icon: Icons.location_on,
                      title: 'Location',
                      subtitle: widget.event.location,
                      trailing: const Icon(
                        Icons.map,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Organizer
                  _buildInfoRow(
                    icon: Icons.person,
                    title: 'Organizer',
                    subtitle: _organizerName,
                  ),
                  const SizedBox(height: 12),
                  
                  // Attendees count
                  _buildInfoRow(
                    icon: Icons.people,
                    title: 'Attendees',
                    subtitle: '${_attendeesIds.length} attending',
                  ),
                  const SizedBox(height: 20),
                  
                  // Description
                  const Text(
                    'About this event',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.event.description,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  
                  // RSVP button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _toggleAttendance,
                      icon: Icon(_isAttending ? Icons.check : Icons.add),
                      label: Text(_isAttending ? 'Attending' : 'RSVP for Event'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAttending 
                            ? Colors.green 
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  
                  // Cancel attendance button (if attending)
                  if (_isAttending)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _isLoading ? null : _toggleAttendance,
                          child: const Text('Cancel Attendance'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}