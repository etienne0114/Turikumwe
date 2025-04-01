// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/constants/app_strings.dart';
import 'package:turikumwe/screens/create_event_screen.dart';
import 'package:turikumwe/screens/create_post_screen.dart';
import 'package:turikumwe/screens/events_screen.dart';
import 'package:turikumwe/screens/groups/create_group_screen.dart';
import 'package:turikumwe/screens/groups/groups_list_screen.dart';
import 'package:turikumwe/screens/home_feed_screen.dart';
import 'package:turikumwe/screens/messages_screen.dart';
import 'package:turikumwe/screens/notifications_screen.dart';
import 'package:turikumwe/screens/profile_screen.dart';
import 'package:turikumwe/screens/settings_screen.dart';
import 'package:turikumwe/screens/stories_screen.dart';
import 'package:turikumwe/screens/user_search_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late List<Widget> _screens;
  int _unreadMessagesCount = 0;
  int _unreadNotificationsCount = 0;
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    // Initialize screens here to ensure context is available for Provider
    _screens = [
      const HomeFeedScreen(),
      const GroupsListScreen(),
      const EventsScreen(),
      const StoriesScreen(),
      const MessagesScreen(),
    ];
    
    // Load unread counts
    _loadUnreadCounts();
  }
  
  Future<void> _loadUnreadCounts() async {
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    if (currentUser == null) return;
    
    try {
      // Get unread message count
      final unreadMessages = await _databaseService.getUnreadMessagesCount(currentUser.id);
      
      // Get unread notifications count - you would need to add this method to your DatabaseService
      const unreadNotifications = 0; // Replace with actual method call
      
      setState(() {
        _unreadMessagesCount = unreadMessages;
        _unreadNotificationsCount = unreadNotifications;
      });
    } catch (e) {
      print('Error loading unread counts: $e');
    }
  }

  // Refresh the Home Feed
  void _refreshHomeFeed() {
    if (_currentIndex == 0) {
      setState(() {
        // Replace the home feed screen with a new instance to force refresh
        _screens[0] = const HomeFeedScreen();
      });
    }
  }

  final List<String> _titles = [
    'Home',
    'Groups',
    'Events',
    'Stories',
    'Messages',
  ];

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = Provider.of<AuthService>(context).currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          if (_currentIndex == 4) // Only show search on Messages screen
            IconButton(
              icon: const Icon(Icons.person_search),
              onPressed: isLoggedIn
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const UserSearchScreen()),
                      ).then((_) {
                        // Refresh unread counts when returning
                        _loadUnreadCounts();
                      });
                    }
                  : _showLoginPrompt,
            ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined),
                if (_unreadNotificationsCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        _unreadNotificationsCount > 9 ? '9+' : _unreadNotificationsCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: isLoggedIn
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NotificationsScreen()),
                    ).then((_) {
                      // Refresh unread counts when returning
                      _loadUnreadCounts();
                    });
                  }
                : _showLoginPrompt,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: isLoggedIn
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfileScreen()),
                    );
                  }
                : _showLoginPrompt,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: isLoggedIn
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    );
                  }
                : _showLoginPrompt,
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          
          // When switching to messages tab, refresh unread counts
          if (index == 4) {
            _loadUnreadCounts();
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            activeIcon: Icon(Icons.group),
            label: 'Groups',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: 'Events',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.auto_stories_outlined),
            activeIcon: Icon(Icons.auto_stories),
            label: 'Stories',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.chat_outlined),
                if (_unreadMessagesCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        _unreadMessagesCount > 9 ? '9+' : _unreadMessagesCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: const Icon(Icons.chat),
            label: 'Messages',
          )
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
    final isLoggedIn =
        Provider.of<AuthService>(context, listen: false).currentUser != null;

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
                  subtitle:
                      const Text('Share your thoughts with the community'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to create post screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreatePostScreen(),
                      ),
                    ).then((value) {
                      // If post was created successfully, refresh home feed
                      if (value == true) {
                        _refreshHomeFeed();
                      }
                    });
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
                    Navigator.pop(context); // Close the modal first
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
                    );
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
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.purple,
                    child: Icon(Icons.message, color: Colors.white),
                  ),
                  title: const Text('New Message'),
                  subtitle: const Text('Start a conversation with someone'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserSearchScreen(),
                      ),
                    );
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