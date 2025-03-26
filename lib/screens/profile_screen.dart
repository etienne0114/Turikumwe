// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/post.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/auth/login_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/widgets/post_card.dart';

class ProfileScreen extends StatefulWidget {
  final int? userId; // If null, show current user's profile

  const ProfileScreen({
    Key? key,
    this.userId,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Post> _userPosts = [];
  User? _profileUser;
  int _groupCount = 0;
  int _eventCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileUser == null) {
      _loadUserData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) return;

      // Determine which user's profile to show
      final userId = widget.userId ?? currentUser.id;
      _profileUser = await DatabaseService().getUserById(userId);

      if (_profileUser == null) return;

      // Load user posts
      _userPosts = await DatabaseService().getPosts(userId: userId);
      
      // TODO: Implement these methods in DatabaseService
      // _groupCount = await DatabaseService().getUserGroupCount(userId);
      // _eventCount = await DatabaseService().getUserEventCount(userId);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load profile data')),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      await Provider.of<AuthService>(context, listen: false).logout();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to logout')),
        );
      }
    }
  }

  bool get _isCurrentUserProfile {
    final currentUser = Provider.of<AuthService>(context).currentUser;
    return widget.userId == null || 
           (currentUser != null && widget.userId == currentUser.id);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context).currentUser;
    
    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login to view profile'),
        ),
      );
    }

    final user = _profileUser ?? currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCurrentUserProfile ? 'My Profile' : 'User Profile'),
        actions: [
          if (_isCurrentUserProfile)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showProfileActions(context),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: _ProfileHeader(
                        user: user,
                        postCount: _userPosts.length,
                        groupCount: _groupCount,
                        eventCount: _eventCount,
                        isCurrentUser: _isCurrentUserProfile,
                      ),
                    ),
                    SliverPersistentHeader(
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          controller: _tabController,
                          indicatorColor: AppColors.primary,
                          labelColor: AppColors.primary,
                          unselectedLabelColor: Colors.grey,
                          tabs: const [
                            Tab(icon: Icon(Icons.post_add),
                            Tab(icon: Icon(Icons.group)),
                            Tab(icon: Icon(Icons.event)),
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
                    // Posts Tab
                    _PostsTab(
                      posts: _userPosts,
                      isCurrentUser: _isCurrentUserProfile,
                    ),
                    
                    // Groups Tab
                    _GroupsTab(isCurrentUser: _isCurrentUserProfile),
                    
                    // Events Tab
                    _EventsTab(isCurrentUser: _isCurrentUserProfile),
                  ],
                ),
              ),
            ),
    );
  }

  void _showProfileActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Profile'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to edit profile
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to settings
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final User user;
  final int postCount;
  final int groupCount;
  final int eventCount;
  final bool isCurrentUser;

  const _ProfileHeader({
    required this.user,
    required this.postCount,
    required this.groupCount,
    required this.eventCount,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile picture with edit button
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: user.profilePicture != null
                    ? NetworkImage(user.profilePicture!)
                    : null,
                child: user.profilePicture == null
                    ? Text(
                        user.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 36),
                      )
                    : null,
              ),
              if (isCurrentUser)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    color: Colors.white,
                    onPressed: () {
                      // Edit profile picture
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Name and verification badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (user.isAdmin == true)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.verified, color: Colors.blue, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Location
          if (user.district != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  user.district!,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          const SizedBox(height: 16),
          
          // Bio
          if (user.bio != null && user.bio!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                user.bio!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          const SizedBox(height: 20),
          
          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(count: postCount, label: 'Posts'),
              _StatItem(count: groupCount, label: 'Groups'),
              _StatItem(count: eventCount, label: 'Events'),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final int count;
  final String label;

  const _StatItem({
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

class _PostsTab extends StatelessWidget {
  final List<Post> posts;
  final bool isCurrentUser;

  const _PostsTab({
    required this.posts,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return posts.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.post_add,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No posts yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share your thoughts with the community',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                if (isCurrentUser)
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to create post
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Post'),
                  ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return PostCard(post: posts[index]);
            },
          );
  }
}

class _GroupsTab extends StatelessWidget {
  final bool isCurrentUser;

  const _GroupsTab({
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.group_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No groups yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Join groups to connect with like-minded people',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to groups screen
            },
            icon: const Icon(Icons.search),
            label: const Text('Find Groups'),
          ),
        ],
      ),
    );
  }
}

class _EventsTab extends StatelessWidget {
  final bool isCurrentUser;

  const _EventsTab({
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
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
            'No events yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Join or create events to connect with your community',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          if (isCurrentUser)
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to create event
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Event'),
            ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}