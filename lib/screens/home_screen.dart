// lib/screens/home_screen.dart - Update the bottom sheet to link to create event
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/constants/app_strings.dart';
import 'package:turikumwe/screens/create_event_screen.dart'; // Import the create event screen
import 'package:turikumwe/screens/events_screen.dart';
import 'package:turikumwe/screens/groups_screen.dart';
import 'package:turikumwe/screens/home_feed_screen.dart';
import 'package:turikumwe/screens/messages_screen.dart';
import 'package:turikumwe/screens/profile_screen.dart';
import 'package:turikumwe/screens/stories_screen.dart';
import 'package:turikumwe/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const HomeFeedScreen(),
    const GroupsScreen(),
    const EventsScreen(),
    const MessagesScreen(),
    const StoriesScreen(),
  ];
  
  final List<String> _titles = [
    AppStrings.home,
    AppStrings.groups,
    AppStrings.events,
    AppStrings.messages,
    AppStrings.stories,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Navigate to notifications screen
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
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
            icon: Icon(Icons.chat_outlined),
            activeIcon: Icon(Icons.chat),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_stories_outlined),
            activeIcon: Icon(Icons.auto_stories),
            label: 'Stories',
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
  
  void _showCreateOptionsModal(BuildContext context) {
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
                    backgroundColor: AppColors.secondary,
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
                    backgroundColor: AppColors.accent,
                    child: Icon(Icons.auto_stories, color: Colors.white),
                  ),
                  title: const Text('Share Story'),
                  subtitle: const Text('Share an inspiring community story'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to create story screen
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