// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/post.dart';
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

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Post> _userPosts = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the user's posts
      final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
      if (currentUser != null) {
        final userId = widget.userId ?? currentUser.id;
        final posts = await DatabaseService().getPosts(userId: userId);
        
        setState(() {
          _userPosts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _logout() async {
    await Provider.of<AuthService>(context, listen: false).logout();
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context).currentUser;
    final bool isCurrentUser = widget.userId == null || (currentUser != null && widget.userId == currentUser.id);
    
    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please login to view profile'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isCurrentUser ? 'My Profile' : 'User Profile'),
        actions: [
          if (isCurrentUser)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  _logout();
                } else if (value == 'edit') {
                  // Navigate to edit profile
                } else if (value == 'settings') {
                  // Navigate to settings
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit Profile'),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Text('Settings'),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Text('Logout'),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: _buildProfileHeader(currentUser),
                  ),
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        controller: _tabController,
                        indicatorColor: AppColors.primary,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: Colors.grey,
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
                  // Posts Tab
                  _userPosts.isEmpty
                      ? _buildEmptyPosts()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _userPosts.length,
                          itemBuilder: (context, index) {
                            return PostCard(post: _userPosts[index]);
                          },
                        ),
                  
                  // Groups Tab
                  _buildEmptyGroups(),
                  
                  // Events Tab
                  _buildEmptyEvents(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(user) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile picture
          CircleAvatar(
            radius: 50,
            backgroundImage: user.profilePicture != null
                ? NetworkImage(user.profilePicture)
                : null,
            child: user.profilePicture == null
                ? Text(
                    user.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 36),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          
          // Name
          Text(
            user.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // District
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
          if (user.bio != null)
            Text(
              user.bio!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          const SizedBox(height: 20),
          
          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('Posts', _userPosts.length.toString()),
              _buildStatItem('Groups', '0'),
              _buildStatItem('Events', '0'),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
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

  Widget _buildEmptyPosts() {
    return Center(
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
          if (widget.userId == null)
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to create post
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyGroups() {
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
              Navigator.popUntil(context, ModalRoute.withName('/'));
              // Then select groups tab
            },
            icon: const Icon(Icons.search),
            label: const Text('Find Groups'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyEvents() {
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
          if (widget.userId == null)
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

// SliverAppBarDelegate for the TabBar
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