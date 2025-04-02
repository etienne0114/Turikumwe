// lib/screens/events_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/screens/auth/login_screen.dart';
import 'package:turikumwe/screens/create_event_screen.dart';
import 'package:turikumwe/screens/event_detail_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
import 'package:turikumwe/widgets/event_card.dart';
import 'package:turikumwe/widgets/event_calendar_view.dart';
import 'package:turikumwe/widgets/event_filter.dart';

class EventsScreen extends StatefulWidget {
  final int initialTabIndex;

  const EventsScreen({Key? key, this.initialTabIndex = 0}) : super(key: key);

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Event> _allEvents = [];
  List<Event> _myEvents = [];
  bool _isLoading = true;
  String? _selectedCategory;
  String? _selectedDistrict;
  bool _upcomingOnly = true;
  String _searchQuery = '';

  // Lists for categories and districts
  final List<String> _eventCategories = [
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

  final List<String> _rwandanDistricts = [
    'Bugesera', 'Burera', 'Gakenke', 'Gasabo', 'Gatsibo',
    'Gicumbi', 'Gisagara', 'Huye', 'Kamonyi', 'Karongi',
    'Kayonza', 'Kicukiro', 'Kirehe', 'Muhanga', 'Musanze',
    'Ngoma', 'Ngororero', 'Nyabihu', 'Nyagatare', 'Nyamagabe',
    'Nyamasheke', 'Nyanza', 'Nyarugenge', 'Nyaruguru', 'Rubavu',
    'Ruhango', 'Rulindo', 'Rusizi', 'Rutsiro', 'Rwamagana',
  ];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3, 
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(_handleTabChange); 
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Handle tab change events
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      // Clear search when changing tabs
      if (_searchQuery.isNotEmpty) {
        setState(() {
          _searchQuery = '';
          _searchController.clear();
        });
      }
      
      // Refresh data when switching tabs
      _loadEvents();
    }
  }

  // Load all events data
  Future<void> _loadEvents() async {
    // Set loading state at the beginning
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Get the current user
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      // Parameters for filtering events
      DateTime? fromDate = _upcomingOnly ? DateTime.now() : null;

      List<Event> events = [];

      if (_searchQuery.isNotEmpty) {
        // Search events
        events = await _searchEvents(_searchQuery);
      } else if (_selectedCategory != null) {
        // Filter by category
        events = await DatabaseService().getEvents(
          fromDate: fromDate,
          category: _selectedCategory,
        );
      } else if (_selectedDistrict != null) {
        // Filter by district
        events = await DatabaseService().getEvents(
          fromDate: fromDate,
          district: _selectedDistrict,
        );
      } else {
        // Get all events
        events = await DatabaseService().getEvents(
          fromDate: fromDate,
        );
      }
      
      // Make sure we actually have events loaded
      if (events.isEmpty && fromDate != null) {
        // Try without date filter as a fallback
        events = await DatabaseService().getEvents();
        debugPrint('Loaded ${events.length} events without filters');
      } else {
        debugPrint('Loaded ${events.length} events with filters');
      }
      
      // Sort events by date (upcoming first)
      events.sort((a, b) => a.date.compareTo(b.date));
      
      // Load "My Events" data if user is logged in
      List<Event> myEvents = [];
      if (currentUser != null) {
        try {
          myEvents = await DatabaseService().getEventsUserIsAttending(currentUser.id);
          debugPrint('Loaded ${myEvents.length} events for user ${currentUser.id}');
          
          // Sort my events by date (upcoming first)
          myEvents.sort((a, b) => a.date.compareTo(b.date));
        } catch (e) {
          debugPrint('Error loading user events: $e');
          // Continue with empty myEvents list
        }
      }

      // Always set loading to false at the end, regardless of success
      if (mounted) {
        setState(() {
          _allEvents = events;
          _myEvents = myEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading events: $e');
      // Always set loading to false in case of error
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        DialogUtils.showErrorSnackBar(
          context,
          message: 'Failed to load events. Please try again.',
        );
      }
    }
  }

  // Refresh events data
  Future<void> _refreshEvents() async {
    if (!_isLoading) {
      return _loadEvents();
    }
    return Future.value();
  }

  // Build the All Events tab
  Widget _buildAllEventsTab() {
    return RefreshIndicator(
      onRefresh: _refreshEvents,
      child: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _allEvents.isEmpty
          ? ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedCategory != null
                              ? 'No events found in $_selectedCategory category'
                              : _selectedDistrict != null
                                  ? 'No events found in $_selectedDistrict district'
                                  : 'No events found',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _navigateToCreateEvent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Create Event'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _allEvents.length,
              itemBuilder: (context, index) {
                return EventCard(
                  event: _allEvents[index],
                  onAttend: () => _navigateToEventDetail(_allEvents[index]),
                  showDeleteButton: _allEvents[index].isPast,
                  onDelete: () => _deleteEvent(_allEvents[index]),
                );
              },
            ),
    );
  }

  // Build the My Events tab
  Widget _buildMyEventsTab() {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

    // If user is not logged in, show login prompt
    if (currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Please log in to view your events',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                ).then((_) {
                  // Refresh after login
                  _loadEvents();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Log In'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshEvents,
      child: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _myEvents.isEmpty
          ? ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'You haven\'t joined any events yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _tabController.animateTo(0),
                          icon: const Icon(Icons.search),
                          label: const Text('Find Events'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _myEvents.length,
              itemBuilder: (context, index) {
                final event = _myEvents[index];
                return EventCard(
                  event: event,
                  onAttend: () => _navigateToEventDetail(event),
                  showDeleteButton: event.isPast && _isOrganizerOrAdmin(event),
                  onDelete: () => _deleteEvent(event),
                );
              },
            ),
    );
  }
  
  // Build Calendar Tab
  Widget _buildCalendarTab() {
    // Check if the events have been loaded
    if (_allEvents.isEmpty) {
      // If no events, show a message and trigger a load
      _loadEvents();
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No events found in the calendar',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshEvents,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Refresh Events'),
            ),
          ],
        ),
      );
    }
    
    // Implement calendar view with EventCalendarView widget
    return RefreshIndicator(
      onRefresh: _refreshEvents,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: EventCalendarView(
          events: _allEvents,
          onDaySelected: _onDaySelected,
        ),
      ),
    );
  }

  // Build search results list
  Widget _buildSearchResultsList() {
    if (_allEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "$_searchQuery"',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try different keywords or filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _clearSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Clear Search'),
            ),
          ],
        ),
      );
    }

    // Display search results
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allEvents.length,
      itemBuilder: (context, index) {
        return EventCard(
          event: _allEvents[index],
          onAttend: () => _navigateToEventDetail(_allEvents[index]),
        );
      },
    );
  }
  
  // Method to delete an event
  Future<void> _deleteEvent(Event event) async {
    // Confirm deletion with dialog
    final confirm = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Delete Event',
      message: 'Are you sure you want to delete this event?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDangerous: true,
    );
    
    if (!confirm) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Delete the event
      final result = await DatabaseService().deleteEvent(event.id);
      
      if (result > 0) {
        // Remove the event from our lists
        setState(() {
          _allEvents.removeWhere((e) => e.id == event.id);
          _myEvents.removeWhere((e) => e.id == event.id);
          _isLoading = false;
        });
        
        if (mounted) {
          DialogUtils.showSuccessSnackBar(
            context,
            message: 'Event deleted successfully',
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          DialogUtils.showErrorSnackBar(
            context,
            message: 'Failed to delete event',
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Error deleting event: ${e.toString()}',
        );
      }
    }
  }

  // Helper method to search events using existing DatabaseService methods
  Future<List<Event>> _searchEvents(String query) async {
    final db = DatabaseService();
    final events = await db.getEvents();

    // Filter events that match the query in title, description, or location
    return events.where((event) {
      final title = event.title.toLowerCase();
      final description = event.description.toLowerCase();
      final location = event.location.toLowerCase();
      final searchLower = query.toLowerCase();

      return title.contains(searchLower) ||
          description.contains(searchLower) ||
          location.contains(searchLower);
    }).toList();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventFilter(
        categories: _eventCategories,
        districts: _rwandanDistricts,
        selectedCategory: _selectedCategory,
        selectedDistrict: _selectedDistrict,
        upcomingOnly: _upcomingOnly,
        onFilterChanged: (category, district, upcoming) {
          setState(() {
            _selectedCategory = category;
            _selectedDistrict = district;
            _upcomingOnly = upcoming;
          });
          _loadEvents();
        },
      ),
    );
  }

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query.trim();
    });

    if (_searchQuery.isNotEmpty) {
      _loadEvents();
    }
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
    _loadEvents();
  }

  Future<void> _navigateToCreateEvent() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Check if user is logged in
    if (authService.currentUser == null) {
      DialogUtils.showErrorSnackBar(
        context,
        message: 'Please log in to create events',
      );
      
      // Navigate to login screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateEventScreen()),
    );

    // If returned with a success result, reload events
    if (result == true) {
      _loadEvents();
    }
  }

  void _onDaySelected(DateTime selectedDay) {
    // This method intentionally left empty for now
    // It will be implemented when needed for calendar functionality
  }

  // Check if current user is organizer or admin
  bool _isOrganizerOrAdmin(Event event) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (currentUser == null) return false;
    
    return event.organizerId == currentUser.id || (currentUser.isAdmin ?? false);
  }

  // Navigate to event detail screen
  void _navigateToEventDetail(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(event: event),
      ),
    ).then((_) {
      // Refresh events when returning from details
      _loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isUserLoggedIn =
        Provider.of<AuthService>(context).currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: _searchQuery.isEmpty
            ? const Text('All events details')
            : TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search events...',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _clearSearch,
                  ),
                ),
                style: const TextStyle(color: Color.fromARGB(255, 1, 8, 44)),
                cursorColor: const Color.fromARGB(255, 3, 39, 72),
                onSubmitted: _handleSearch,
              ),
        actions: [
          if (_searchQuery.isEmpty)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _searchQuery = ' '; // Set a space to show search field
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _searchController.text = '';
                  FocusScope.of(context).requestFocus(FocusNode());
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
        bottom: _searchQuery.isEmpty
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Calendar'),
                  Tab(text: 'My Events'),
                ],
                indicatorColor: const Color.fromARGB(255, 4, 164, 30),
                labelColor: const Color.fromARGB(255, 1, 3, 90),
                unselectedLabelColor: const Color.fromARGB(255, 1, 3, 90),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchQuery.isNotEmpty
              ? _buildSearchResultsList()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // All Events Tab
                    _buildAllEventsTab(),

                    // Calendar Tab
                    _buildCalendarTab(),

                    // My Events Tab
                    _buildMyEventsTab(),
                  ],
                ),
      floatingActionButton: isUserLoggedIn
          ? FloatingActionButton(
              onPressed: _navigateToCreateEvent,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}