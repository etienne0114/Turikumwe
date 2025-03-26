// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/constants/app_strings.dart';
import 'package:turikumwe/screens/create_event_screen.dart';
import 'package:turikumwe/screens/events_screen.dart';
import 'package:turikumwe/screens/groups/groups_list_screen.dart';
import 'package:turikumwe/screens/home_feed_screen.dart';
import 'package:turikumwe/screens/notifications_screen.dart';
import 'package:turikumwe/screens/profile_screen.dart';
import 'package:turikumwe/services/auth_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  late List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    // Initialize screens here to ensure context is available for Provider
    _screens = [
      const HomeFeedScreen(),
      const GroupsListScreen(), // Changed from GroupsScreen to GroupsListScreen
      const EventsScreen(),
      const NotificationsScreen(), // Changed from MessagesScreen
      const ProfileScreen(), // Changed from StoriesScreen
    ];
  }
  
  final List<String> _titles = [
    'Home',
    'Groups',
    'Events',
    'Notifications',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = Provider.of<AuthService>(context).currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: isLoggedIn ? () {
              setState(() {
                _currentIndex = 3; // Switch to notifications tab
              });
            } : _showLoginPrompt,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: isLoggedIn ? () {
              setState(() {
                _currentIndex = 4; // Switch to profile tab
              });
            } : _showLoginPrompt,
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // If not logged in and trying to access notifications or profile,
          // show login prompt instead
          if (!isLoggedIn && (index == 3 || index == 4)) {
            _showLoginPrompt();
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            activeIcon: Icon(Icons.group),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show bottom sheet to create new post, event, or story
          _showCreateOptionsModal(context);
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('You need to login to access this feature.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to login screen
              // Replace with your login navigation code
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
  
  void _showCreateOptionsModal(BuildContext context) {
    final isLoggedIn = Provider.of<AuthService>(context, listen: false).currentUser != null;
    
    if (!isLoggedIn) {
      _showLoginPrompt();
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create New',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.post_add, color: Colors.white),
                  ),
                  title: const Text('Create Post'),
                  subtitle: const Text('Share your thoughts with the community'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to create post screen
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.group_add, color: Colors.white),
                  ),
                  title: const Text('Create Group'),
                  subtitle: const Text('Start a new community group'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to create group screen
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.event, color: Colors.white),
                  ),
                  title: const Text('Create Event'),
                  subtitle: const Text('Organize a community event'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to create event screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateEventScreen(),
                      ),
                    ).then((value) {
                      // If event was created successfully, show events tab
                      if (value == true) {
                        setState(() {
                          _currentIndex = 2; // Switch to Events tab
                        });
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}