// lib/screens/home_feed_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/post.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/widgets/group_post_card_home.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({Key? key}) : super(key: key);

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  List<Post> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final databaseService =
          Provider.of<DatabaseService>(context, listen: false);
      final currentUser =
          Provider.of<AuthService>(context, listen: false).currentUser;

      List<Post> posts = [];

      // If user is logged in, get posts from their groups too
      if (currentUser != null) {
        // Get user's groups
        final userGroups = await databaseService.getUserGroups(currentUser.id);

        // Get posts from those groups
        for (final group in userGroups) {
          final groupPosts = await databaseService.getPosts(groupId: group.id);
          posts.addAll(groupPosts);
        }

        // Also get general posts
        final generalPosts = await databaseService.getPosts();
        posts.addAll(generalPosts.where((post) => post.groupId == null));
      } else {
        // Just get all posts if not logged in
        posts = await databaseService.getPosts();
      }

      // Sort by date (newest first)
      posts.sort((a, b) =>
          DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading posts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    // Use the enhanced GroupPostCardHome for better display
                    return GroupPostCardHome(
                      post: _posts[index],
                      onPostUpdated: _loadPosts,
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.feed_outlined,
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
            'Be the first to post or join groups to see content',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to create post
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Post'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
