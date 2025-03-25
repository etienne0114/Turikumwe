// lib/screens/events_screen.dart - Updated with Create Event functionality
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/screens/create_event_screen.dart'; // Import the create event screen
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
import 'package:turikumwe/widgets/event_card.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({Key? key}) : super(key: key);

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<Event> _upcomingEvents = [];
  List<Event> _myEvents = [];
  bool _isLoading = true;
  int _selectedFilter = 0;
  
  final List<String> _filters = ['All', 'This Week', 'This Month', 'My District'];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get events starting from today
      final events = await DatabaseService().getEvents(
        fromDate: DateTime.now(),
      );
      
      // For demo purposes, we'll just split them
      // In a real app, you'd filter based on user's RSVPs
      setState(() {
        _upcomingEvents = events;
        _myEvents = events.take(2).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to navigate to create event screen
  Future<void> _navigateToCreateEvent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateEventScreen()),
    );
    
    // If returned with a success result, reload events
    if (result == true) {
      _loadEvents();
    }
  }

  // Apply filters to events
  List<Event> _getFilteredEvents() {
    final now = DateTime.now();
    final endOfWeek = now.add(Duration(days: 7 - now.weekday + 1));
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    
    switch (_selectedFilter) {
      case 1: // This Week
        return _upcomingEvents.where((event) {
          return event.date.isBefore(endOfWeek);
        }).toList();
      case 2: // This Month
        return _upcomingEvents.where((event) {
          return event.date.isBefore(endOfMonth);
        }).toList();
      case 3: // My District (placeholder - would use user's district)
        // In a real app, you'd filter by user's district
        return _upcomingEvents.take(3).toList();
      default: // All
        return _upcomingEvents;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _getFilteredEvents();
    
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : filteredEvents.isEmpty && _myEvents.isEmpty
            ? _buildEmptyState()
            : CustomScrollView(
                slivers: [
                  // Filter chips
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(
                            _filters.length,
                            (index) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(_filters[index]),
                                selected: _selectedFilter == index,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedFilter = index;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // My events section
                  if (_myEvents.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Your Events',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 220,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _myEvents.length,
                          itemBuilder: (context, index) {
                            return EventCard(
                              event: _myEvents[index],
                              isHorizontal: true,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  
                  // Upcoming events section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Upcoming Events',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (filteredEvents.isEmpty)
                            TextButton.icon(
                              onPressed: _navigateToCreateEvent,
                              icon: const Icon(Icons.add),
                              label: const Text('Create'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Show filtered events or empty state
                  filteredEvents.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.event_outlined,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No events found for this filter',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _navigateToCreateEvent,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Event'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: EventCard(
                                  event: filteredEvents[index],
                                ),
                              );
                            },
                            childCount: filteredEvents.length,
                          ),
                        ),
                ],
              );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.event_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No upcoming events',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create an event or check back later for upcoming activities',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _navigateToCreateEvent,
            icon: const Icon(Icons.add),
            label: const Text('Create Event'),
          ),
        ],
      ),
    );
  }
}