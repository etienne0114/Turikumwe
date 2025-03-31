// lib/screens/events_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/screens/create_event_screen.dart';
import 'package:turikumwe/screens/event_detail_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
import 'package:turikumwe/widgets/event_card.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({Key? key}) : super(key: key);

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Event> _allEvents = [];
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

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      // Clear search when changing tabs
      if (_searchQuery.isNotEmpty) {
        setState(() {
          _searchQuery = '';
          _searchController.clear();
        });
        _loadEvents();
      }
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the current user
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      // Parameters for filtering events
      DateTime? fromDate = _upcomingOnly ? DateTime.now() : null;

      List<Event> events = [];

      if (_searchQuery.isNotEmpty) {
        // Search events - implement using existing methods
        events = await _searchEvents(_searchQuery);
      } else if (_selectedCategory != null) {
        // Filter by category
        events = await _getEventsByCategory(_selectedCategory!);
      } else if (_selectedDistrict != null) {
        // Filter by district
        events = await _getEventsByDistrict(_selectedDistrict!);
      } else {
        // Get all events
        events = await DatabaseService().getEvents(
          fromDate: fromDate,
          district: currentUser?.district,
        );
      }

      if (mounted) {
        setState(() {
          _allEvents = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading events: $e');
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

  // Helper method to get events by category
  Future<List<Event>> _getEventsByCategory(String category) async {
    final db = DatabaseService();
    final allEvents = await db.getEvents();

    // Filter events by category
    return allEvents
        .where(
            (event) => event.category?.toLowerCase() == category.toLowerCase())
        .toList();
  }

  // Helper method to get events by district
  Future<List<Event>> _getEventsByDistrict(String district) async {
    final db = DatabaseService();
    final allEvents = await db.getEvents();

    // Filter events by district
    return allEvents
        .where(
            (event) => event.district?.toLowerCase() == district.toLowerCase())
        .toList();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildFilterSheet(),
    );
  }

  Widget _buildFilterSheet() {
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Events',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = null;
                        _selectedDistrict = null;
                        _upcomingOnly = true;
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),

              const Divider(),

              // Upcoming toggle
              SwitchListTile(
                title: const Text('Show upcoming events only'),
                value: _upcomingOnly,
                onChanged: (value) {
                  setState(() {
                    _upcomingOnly = value;
                  });
                },
                activeColor: AppColors.primary,
              ),

              const Divider(),

              // Category selection
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _selectedCategory == null,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = null;
                      });
                    },
                    selectedColor: AppColors.primary.withOpacity(0.2),
                  ),
                  ..._eventCategories.map((category) {
                    return FilterChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = selected ? category : null;
                        });
                      },
                      selectedColor: AppColors.primary.withOpacity(0.2),
                    );
                  }).toList(),
                ],
              ),

              const SizedBox(height: 16),

              // District selection
              const Text(
                'District',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String?>(
                decoration: const InputDecoration(
                  hintText: 'Select district',
                  border: OutlineInputBorder(),
                ),
                value: _selectedDistrict,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All districts'),
                  ),
                  ..._rwandanDistricts.map((district) {
                    return DropdownMenuItem<String>(
                      value: district,
                      child: Text(district),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDistrict = value;
                  });
                },
              ),

              const SizedBox(height: 24),

              // Apply button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    this.setState(() {
                      // Update main state with filter values
                      _selectedCategory = _selectedCategory;
                      _selectedDistrict = _selectedDistrict;
                      _upcomingOnly = _upcomingOnly;
                    });
                    _loadEvents();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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

  Future<void> _refreshEvents() async {
    await _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    final isUserLoggedIn =
        Provider.of<AuthService>(context).currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: _searchQuery.isEmpty
            ? const Text('Events')
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
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
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
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
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
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  Widget _buildAllEventsTab() {
    return RefreshIndicator(
      onRefresh: _refreshEvents,
      child: _allEvents.isEmpty
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
                );
              },
            ),
    );
  }

  Widget _buildCalendarTab() {
    // For now, display a placeholder message about calendar view
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'Calendar View',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Calendar implementation coming soon',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

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
                // Navigate to login screen
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

    // For logged in users, load their events
    return FutureBuilder<List<Event>>(
      future: DatabaseService().getEventsUserIsAttending(currentUser.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final userEvents = snapshot.data ?? [];

        if (userEvents.isEmpty) {
          return Center(
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
                ElevatedButton(
                  onPressed: () => _tabController.animateTo(0),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Find Events'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: userEvents.length,
          itemBuilder: (context, index) {
            return EventCard(
              event: userEvents[index],
              onAttend: () => _navigateToEventDetail(userEvents[index]),
            );
          },
        );
      },
    );
  }

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
}
