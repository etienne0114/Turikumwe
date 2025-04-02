// lib/screens/event_detail_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/create_event_screen.dart';
import 'package:turikumwe/screens/event_registration_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Event _event;
  bool _isAttending = false;
  bool _isLoading = false;
  bool _isLoadingAttendees = false;
  List<User> _attendees = [];
  User? _organizer;
  bool _isEventPast = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _isEventPast = _event.date.isBefore(DateTime.now());
    _checkAttendanceStatus();
    _loadAttendees();
    _loadOrganizer();

    // Track event view for analytics
    _trackEventView();

    if (_event.isPrivate == true) {
      _checkRegistrationStatus();
    }

// Check payment status for paid events
    if (_event.price != null && _event.price! > 0) {
      _checkPaymentStatus();
    }
  }

  Future<void> _trackEventView() async {
    try {
      // Just log for now, no actual DB operation
      debugPrint('Event viewed: ${_event.id}');
    } catch (e) {
      debugPrint('Error tracking event view: $e');
    }
  }

  Future<void> _checkRegistrationStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    if (currentUser != null) {
      final registration = await DatabaseService().getEventRegistration(
        _event.id,
        currentUser.id,
      );

      if (mounted && registration != null) {
        setState(() {
        });
      }
    }
  }

  Future<void> _checkPaymentStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    if (currentUser != null) {

      if (mounted) {
        setState(() {
        });
      }
    }
  }

  void _navigateToRegistration() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventRegistrationScreen(
          event: _event,
          onRegistrationComplete: () {
            _refreshEventData();
            _checkRegistrationStatus();
            _checkPaymentStatus();
          },
        ),
      ),
    );

    if (result == true) {
      _refreshEventData();
    }
  }

  Future<void> _checkAttendanceStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    if (currentUser != null) {
      try {
        // Check if current user is in the attendees list
        if (_event.attendeesIds != null && _event.attendeesIds!.isNotEmpty) {
          final attendeeIds = _event.attendeesIds!
              .split(',')
              .where((id) => id.trim().isNotEmpty)
              .map((id) => int.parse(id.trim()))
              .toList();

          final isAttending = attendeeIds.contains(currentUser.id);

          // Also check registration status separately


          setState(() {
            _isAttending = isAttending;
          });
        } else {
          // If no attendees yet, check if registered

          setState(() {
            _isAttending = false;
          });
        }
      } catch (e) {
        debugPrint('Error checking attendance status: $e');
      }
    }
  }

  Future<void> _loadAttendees() async {
    setState(() {
      _isLoadingAttendees = true;
    });

    try {
      if (_event.attendeesIds == null || _event.attendeesIds!.isEmpty) {
        setState(() {
          _attendees = [];
          _isLoadingAttendees = false;
        });
        return;
      }

      // Get list of attendee IDs
      final attendeeIdsStr = _event.attendeesIds!;
      final attendeeIds = attendeeIdsStr
          .split(',')
          .where((id) => id.trim().isNotEmpty)
          .map((id) => int.parse(id.trim()))
          .toList();

      if (attendeeIds.isEmpty) {
        setState(() {
          _isLoadingAttendees = false;
        });
        return;
      }

      // Get each user separately (as a workaround for getUsersByIds)
      List<User> attendees = [];
      for (var id in attendeeIds) {
        final user = await DatabaseService().getUserById(id);
        if (user != null) {
          attendees.add(user);
        }
      }

      if (mounted) {
        setState(() {
          _attendees = attendees;
          _isLoadingAttendees = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading attendees: $e');
      if (mounted) {
        setState(() {
          _isLoadingAttendees = false;
        });
      }
    }
  }

  Future<void> _loadOrganizer() async {
    try {
      final organizer = await DatabaseService().getUserById(_event.organizerId);
      if (mounted && organizer != null) {
        setState(() {
          _organizer = organizer;
        });
      }
    } catch (e) {
      debugPrint('Error loading organizer: $e');
    }
  }

  Future<void> _toggleAttendance() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      DialogUtils.showErrorSnackBar(
        context,
        message: 'You need to be logged in to register for events',
      );
      return;
    }

    // If event is private or paid, show registration form instead of directly registering
    if (_event.isPrivate == true ||
        (_event.price != null && _event.price! > 0)) {
      _navigateToRegistration();
      return;
    }

    setState(() {
      _isLoading = true;
    });
  }

  Future<void> _shareEvent() async {
    final String shareText = 'Check out this event: ${_event.title}\n'
        'Date: ${DateFormat('EEEE, MMM d, y • h:mm a').format(_event.date)}\n'
        'Location: ${_event.location}, ${_event.district ?? ''}\n\n'
        'Join me at this event through the Turikumwe app!';

    try {
      // Track share analytics
      debugPrint('Event shared: ${_event.id}');

      await Share.share(shareText);
    } catch (e) {
      debugPrint('Error sharing event: $e');
      if (mounted) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Failed to share event. Please try again.',
        );
      }
    }
  }

  Future<void> _openLocationMap() async {
    final String query = Uri.encodeComponent(
        '${_event.location}, ${_event.district ?? ''}, Rwanda');
    final Uri uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          DialogUtils.showErrorSnackBar(
            context,
            message: 'Could not open map application',
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening map: $e');
      if (mounted) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Failed to open map.',
        );
      }
    }
  }

  void _navigateToEditEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEventScreen(eventToEdit: _event),
      ),
    ).then((result) {
      if (result == true) {
        _refreshEventData();
      }
    });
  }

  Future<void> _refreshEventData() async {
    try {
      final freshEvent = await DatabaseService().getEventById(_event.id);
      if (freshEvent != null && mounted) {
        setState(() {
          _event = freshEvent;
        });
        _checkAttendanceStatus();
        _loadAttendees();
      }
    } catch (e) {
      debugPrint('Error refreshing event data: $e');
    }
  }

  bool get _isOrganizerOrAdmin {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    if (currentUser == null) return false;

    // Check if user is the organizer or an admin
    return currentUser.id == _event.organizerId ||
        (currentUser.isAdmin == true);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final bool isLoggedIn = authService.currentUser != null;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshEventData,
        child: CustomScrollView(
          slivers: [
            // App Bar with Image
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              actions: [
                if (_isOrganizerOrAdmin)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _navigateToEditEvent,
                    tooltip: 'Edit Event',
                  ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _shareEvent,
                  tooltip: 'Share Event',
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildEventImage(),
              ),
            ),

            // Event Content
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title, Date, Location Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Event Title
                        Text(
                          _event.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),

                        // Date & Time
                        _buildInfoRow(
                          icon: Icons.calendar_today,
                          title: 'Date & Time',
                          content: DateFormat('EEEE, MMM d, y • h:mm a')
                              .format(_event.date),
                          primaryColor: AppColors.primary,
                        ),
                        const SizedBox(height: 12),

                        // Location with Map Button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Location',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _event.district != null
                                        ? '${_event.location}, ${_event.district}'
                                        : _event.location,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.map,
                                  color: AppColors.primary),
                              onPressed: _openLocationMap,
                              tooltip: 'Open in Map',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Category
                        if (_event.category != null) ...[
                          _buildInfoRow(
                            icon: Icons.category,
                            title: 'Category',
                            content: _event.category!,
                            primaryColor: Colors.teal,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Price Information (if paid event)
                        if (_event.price != null && _event.price! > 0) ...[
                          _buildInfoRow(
                            icon: Icons.money,
                            title: 'Entry Fee',
                            content: '${_event.price!.toStringAsFixed(0)} RWF',
                            subContent: _event.paymentMethod != null
                                ? 'Payment via ${_event.paymentMethod}'
                                : null,
                            primaryColor: Colors.green,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Organizer
                        _buildInfoRow(
                          icon: Icons.person,
                          title: 'Organizer',
                          content: _organizer?.name ?? 'Loading...',
                          primaryColor: Colors.deepPurple,
                        ),
                        const SizedBox(height: 12),

                        // Attendees count
                        _buildInfoRow(
                          icon: Icons.people,
                          title: 'Attendees',
                          content: _isLoadingAttendees
                              ? 'Loading...'
                              : '${_attendees.length} registered',
                          primaryColor: Colors.blue,
                        ),
                        const SizedBox(height: 12),

                        // Visibility Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _event.isPrivate == true
                                ? Colors.amber.withOpacity(0.2)
                                : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _event.isPrivate == true
                                    ? Icons.lock
                                    : Icons.public,
                                size: 16,
                                color: _event.isPrivate == true
                                    ? Colors.amber[800]
                                    : Colors.green[800],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _event.isPrivate == true
                                    ? 'Private Event'
                                    : 'Public Event',
                                style: TextStyle(
                                  color: _event.isPrivate == true
                                      ? Colors.amber[800]
                                      : Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 32),

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
                          _event.description,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),

                        const Divider(height: 32),

                        // Attendees Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Attendees',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_attendees.length} people attending',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Attendees List (Simple implementation)
                        if (_isLoadingAttendees)
                          const Center(
                            child: CircularProgressIndicator(),
                          )
                        else if (_attendees.isEmpty)
                          const Center(
                            child:
                                Text('No attendees yet. Be the first to join!'),
                          )
                        else
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _attendees.map((attendee) {
                              return Column(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: attendee.profilePicture !=
                                            null
                                        ? NetworkImage(attendee.profilePicture!)
                                            as ImageProvider
                                        : null,
                                    child: attendee.profilePicture == null
                                        ? Text(
                                            attendee.name[0].toUpperCase(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    attendee.name
                                        .split(' ')[0], // Just first name
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              );
                            }).toList(),
                          ),

                        const SizedBox(height: 80), // Bottom padding for FAB
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Attendance Button
      floatingActionButton: !_isEventPast && isLoggedIn
          ? SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _toggleAttendance,
                icon: Icon(_isAttending ? Icons.close : Icons.check_circle),
                label: Text(
                  _isAttending
                      ? 'Cancel Registration'
                      : _event.isPrivate == true
                          ? 'Request to Join Event'
                          : _event.price != null && _event.price! > 0
                              ? 'Register Now • ${_event.price!.toStringAsFixed(0)} RWF'
                              : 'Register Now • Free',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isAttending ? Colors.red : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            )
          : _isEventPast
              ? SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.event_busy),
                    label: const Text('Event has ended'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEventImage() {
    if (_event.image == null || _event.image!.isEmpty) {
      return Container(
        color: AppColors.primary.withOpacity(0.2),
        child: const Center(
          child: Icon(
            Icons.event,
            size: 64,
            color: Colors.white,
          ),
        ),
      );
    }

    try {
      if (_event.image!.startsWith('http')) {
        // Network image
        return Hero(
          tag: 'event-image-${_event.id}',
          child: Image.network(
            _event.image!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(
                  Icons.image_not_supported,
                  size: 50,
                  color: Colors.grey,
                ),
              );
            },
          ),
        );
      } else if (_event.image!.startsWith('file://') ||
          _event.image!.startsWith('/')) {
        // Local file image
        final imagePath = _event.image!.startsWith('file://')
            ? _event.image!.replaceFirst('file://', '')
            : _event.image!;

        return Hero(
          tag: 'event-image-${_event.id}',
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(
                  Icons.broken_image,
                  size: 50,
                  color: Colors.grey,
                ),
              );
            },
          ),
        );
      } else {
        // Asset image
        return Hero(
          tag: 'event-image-${_event.id}',
          child: Image.asset(
            _event.image!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[300],
                child: const Icon(
                  Icons.broken_image,
                  size: 50,
                  color: Colors.grey,
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading event image: $e');
      return Container(
        color: AppColors.primary.withOpacity(0.2),
        child: const Center(
          child: Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.white,
          ),
        ),
      );
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String content,
    String? subContent,
    required Color primaryColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                content,
                style: const TextStyle(fontSize: 16),
              ),
              if (subContent != null) ...[
                const SizedBox(height: 2),
                Text(
                  subContent,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
