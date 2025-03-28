// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/models/post.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/events_screen.dart';
import 'package:turikumwe/screens/groups/groups_list_screen.dart';
import 'package:turikumwe/screens/edit_profile_screen.dart';
import 'package:turikumwe/screens/chat_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/services/user_service.dart'; // Add this import
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  final int? id; // Optional - if null, show current user's profile
  
  const ProfileScreen({Key? key, this.id}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final UserService _userService = UserService(); // Add this
  late TabController _tabController;
  bool _isLoading = true;
  User? _user;
  bool _isCurrentUser = false;
  List<Post> _userPosts = [];
  List<Group> _userGroups = [];
  List<Event> _userEvents = [];
  Map<String, int> _stats = {
    'postCount': 0,
    'groupCount': 0,
    'eventCount': 0,
    'groupsCreatedCount': 0,
    'eventsCreatedCount': 0,
  };
  bool _hasExistingConversation = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Determine if we're viewing current user's profile or another user's profile
      if (widget.id == null || widget.id == currentUser.id) {
        // Load current user's profile
        _user = currentUser;
        _isCurrentUser = true;
      } else {
        // Load another user's profile
        final profileData = await _userService.getUserProfileWithStats(widget.id!);
        _user = profileData['user'] as User;
        
        // Check if there's an existing conversation
        _hasExistingConversation = await _userService.conversationExists(
          currentUser.id,
          widget.id!,
        );
        
        _isCurrentUser = false;
      }

      // Get user's creation date for comparison
      DateTime userCreationDate = _user!.createdAt;
      
      // Load user posts
      final posts = await _databaseService.getPosts(userId: _user!.id);
      
      // Load user groups
      final groups = await _databaseService.getUserGroups(_user!.id);
      
      // Load user events (events the user is attending)
      final events = await _databaseService.getEventsUserIsAttending(_user!.id);
      
      // Count groups created by the user
      final adminGroups = await _databaseService.getUserAdminGroups(_user!.id);
      int groupsCreatedCount = 0;
      
      // Check each admin group to see if it was created after the user joined
      for (var group in adminGroups) {
        if (group.createdAt != null) {
          try {
            // FIX: Parse the group.createdAt string to DateTime before comparing
            DateTime groupCreationDate = group.createdAt;
            if (groupCreationDate.isAfter(userCreationDate)) {
              groupsCreatedCount++;
            }
          } catch (e) {
            print('Error parsing group creation date: $e');
          }
        }
      }
      
      // Count events organized by the user
      final eventsOrganized = await _databaseService.getEvents(organizerId: _user!.id);
      
      setState(() {
        _userPosts = posts;
        _userGroups = groups;
        _userEvents = events;
        _stats = {
          'postCount': posts.length,
          'groupCount': groups.length,
          'eventCount': events.length,
          'groupsCreatedCount': groupsCreatedCount,
          'eventsCreatedCount': eventsOrganized.length,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfileScreen(),
      ),
    );
    
    if (result == true) {
      // Profile was updated, reload the profile
      _loadUserProfile();
    }
  }
  
  void _startChat() {
    if (_user == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: _user!.id,
          chatName: _user!.name,
          isGroup: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isCurrentUser ? 'My Profile' : 'User Profile'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isCurrentUser ? 'My Profile' : 'User Profile'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'User not found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCurrentUser ? 'My Profile' : _user!.name),
        actions: [
          if (_isCurrentUser)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _navigateToEditProfile,
            )
          else
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: _startChat,
            ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile header with avatar
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: _user!.profilePicture != null
                              ? NetworkImage(_user!.profilePicture!) as ImageProvider
                              : null,
                          child: _user!.profilePicture == null
                              ? Text(
                                  _user!.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 30,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _user!.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_user!.district != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      _user!.district!,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Member since ${_formatJoinDate(_user!.createdAt)}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Activity stats
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildStatItem('Posts', _stats['postCount'] ?? 0),
                        _buildStatItem('Groups', _stats['groupCount'] ?? 0),
                        _buildStatItem('Events', _stats['eventCount'] ?? 0),
                        _buildStatItem('Groups Created', _stats['groupsCreatedCount'] ?? 0),
                        _buildStatItem('Events Organized', _stats['eventsCreatedCount'] ?? 0),
                      ],
                    ),
                  ),

                  const Divider(),

                  // Bio section
                  if (_user!.bio != null && _user!.bio!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'About',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_user!.bio!),
                        ],
                      ),
                    ),

                  // Contact information
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contact Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildContactItem(Icons.email, _user!.email),
                        if (_user!.phoneNumber != null)
                          _buildContactItem(Icons.phone, _user!.phoneNumber!),
                      ],
                    ),
                  ),

                  // Chat button (only if viewing another user's profile)
                  if (!_isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _startChat,
                          icon: const Icon(Icons.chat_bubble),
                          label: Text(_hasExistingConversation
                              ? 'Continue Conversation'
                              : 'Start Conversation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const Divider(),
                ],
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'Posts'),
                    Tab(text: 'Groups'),
                    Tab(text: 'Events'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostsTab(),
            _buildGroupsTab(),
            _buildEventsTab(),
          ],
        ),
      ),
    );
  }

  String _formatJoinDate(DateTime date) {
    return DateFormat('MMMM d, y').format(date);
  }

  Widget _buildStatItem(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildPostsTab() {
    if (_userPosts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.post_add,
        title: 'No Posts Yet',
        message: 'Share your thoughts with the community',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: _user!.profilePicture != null
                          ? NetworkImage(_user!.profilePicture!) as ImageProvider
                          : null,
                      child: _user!.profilePicture == null
                          ? Text(_user!.name[0].toUpperCase())
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _user!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('MMM d, y').format(DateTime.parse(post.createdAt)),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(post.content),
                if (post.images != null && post.images!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Display post images (simplified for now)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      post.images!.split(',')[0],
                      fit: BoxFit.cover,
                      height: 200,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          width: double.infinity,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.image, size: 50, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.grey, size: 18),
                        const SizedBox(width: 4),
                        Text('${post.likesCount}'),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        const Icon(Icons.comment, color: Colors.grey, size: 18),
                        const SizedBox(width: 4),
                        Text('${post.commentsCount}'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupsTab() {
    if (_userGroups.isEmpty) {
      return _buildEmptyState(
        icon: Icons.group,
        title: 'No Groups Joined',
        message: 'Join groups to connect with others',
        actionLabel: 'Find Groups',
        action: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GroupsListScreen()),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _userGroups.length,
      itemBuilder: (context, index) {
        final group = _userGroups[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.2),
              backgroundImage: group.image != null 
                  ? NetworkImage(group.image!) as ImageProvider
                  : null,
              child: group.image == null
                  ? Icon(Icons.group, color: AppColors.primary)
                  : null,
            ),
            title: Text(group.name),
            subtitle: Text(
              group.description.length > 50
                  ? '${group.description.substring(0, 50)}...'
                  : group.description,
            ),
            trailing: Text('${group.membersCount} members'),
            onTap: () {
              // Navigate to group details
            },
          ),
        );
      },
    );
  }

  Widget _buildEventsTab() {
    if (_userEvents.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event,
        title: 'No Events Joined',
        message: 'Join events to connect with the community',
        actionLabel: 'Find Events',
        action: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EventsScreen()),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _userEvents.length,
      itemBuilder: (context, index) {
        final event = _userEvents[index];
        // FIX: Parse the event.date string to DateTime
        final eventDate = event.date;
        final isPastEvent = eventDate.isBefore(DateTime.now());
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPastEvent
                  ? Colors.grey.shade300
                  : AppColors.primary.withOpacity(0.2),
              backgroundImage: event.image != null 
                  ? NetworkImage(event.image!) as ImageProvider
                  : null,
              child: event.image == null
                  ? Icon(
                      Icons.event,
                      color: isPastEvent ? Colors.grey : AppColors.primary,
                    )
                  : null,
            ),
            title: Text(
              event.title,
              style: TextStyle(
                color: isPastEvent ? Colors.grey : Colors.black,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('MMM d, y').format(eventDate)} • ${event.location}',
                  style: TextStyle(
                    color: isPastEvent ? Colors.grey : Colors.black87,
                  ),
                ),
                Text(
                  isPastEvent ? 'Past event' : 'Upcoming',
                  style: TextStyle(
                    color: isPastEvent ? Colors.grey : AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            isThreeLine: true,
            onTap: () {
              // Navigate to event details
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? action,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && action != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: action,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}