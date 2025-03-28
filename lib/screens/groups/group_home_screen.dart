// lib/screens/groups/group_home_screen.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/models/post.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/groups/create_group_post_screen.dart';
import 'package:turikumwe/screens/groups/group_chat_screen.dart';
import 'package:turikumwe/screens/groups/group_detail_screen.dart';
import 'package:turikumwe/screens/groups/group_members_screen.dart';
import 'package:turikumwe/screens/groups/group_settings_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
// Import the GroupPostCard widget
import 'package:turikumwe/widgets/group_post_card.dart';

class GroupHomeScreen extends StatefulWidget {
  final Group group;

  const GroupHomeScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<GroupHomeScreen> createState() => _GroupHomeScreenState();
}

class _GroupHomeScreenState extends State<GroupHomeScreen> {
  late Group _group;
  bool _isLoading = true;
  bool _isMember = false;
  bool _isAdmin = false;
  List<Post> _groupPosts = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final databaseService =
          Provider.of<DatabaseService>(context, listen: false);

      // Check membership status if user is logged in
      if (authService.currentUser != null) {
        final membership = await databaseService.getGroupMembership(
            _group.id, authService.currentUser!.id);

        if (mounted) {
          setState(() {
            _isMember = membership != null;
            _isAdmin = membership != null && membership['isAdmin'] == 1;
          });
        }
      }

      // Redirect to group detail screen if not a member
      if (!_isMember && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GroupDetailScreen(group: _group),
          ),
        );
        return;
      }

      // Refresh group data
      final updatedGroup = await databaseService.getGroupById(_group.id);
      if (updatedGroup != null && mounted) {
        setState(() => _group = updatedGroup);
      }

      // Load group posts
      final posts = await databaseService.getPosts(groupId: _group.id);

      if (mounted) {
        setState(() {
          _groupPosts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Failed to load group data: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser == null) return;

    // Check if user is the only admin
    if (_isAdmin) {
      final databaseService =
          Provider.of<DatabaseService>(context, listen: false);
      final members = await databaseService.getGroupMembers(_group.id);
      final adminCount = members.where((m) => m['isAdmin'] == 1).length;

      if (adminCount <= 1) {
        // User is the only admin
        final action = await _showLeaveAdminDialog();

        if (action == null || action == 'cancel') {
          return;
        } else if (action == 'transfer') {
          // Navigate to members screen to transfer admin role
          _navigateTo(GroupMembersScreen(group: _group), refresh: true);
          return;
        }
        // If 'leave' is selected, continue with leaving
      }
    }

    final confirm = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Leave Group',
      message: 'Are you sure you want to leave this group?',
      confirmText: 'Leave',
      cancelText: 'Cancel',
      isDangerous: true,
    );

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      final databaseService =
          Provider.of<DatabaseService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      await databaseService.removeGroupMember(
          _group.id, authService.currentUser!.id);

      await databaseService.decrementGroupMembersCount(_group.id);

      if (mounted) {
        DialogUtils.showSnackBar(context, message: 'You left the group');
        // Navigate back to previous screen
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        DialogUtils.showErrorSnackBar(context,
            message: 'Failed to leave group: ${e.toString()}');
      }
    }
  }

  Future<String?> _showLeaveAdminDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('You are the only admin'),
        content: const Text(
            'If you leave, you should first make someone else an admin. What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'transfer'),
            child: const Text('Make Someone Admin'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'leave'),
            child:
                const Text('Leave Anyway', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _navigateTo(Widget page, {bool refresh = false}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page))
        .then((_) => refresh ? _loadGroupData() : null);
  }

  void _shareGroup() {
    // Implement share functionality
    DialogUtils.showSnackBar(context,
        message: 'Share functionality coming soon');
        
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context).currentUser;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_group.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareGroup,
            tooltip: 'Share Group',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'leave') {
                _leaveGroup();
              } else if (value == 'settings' && _isAdmin) {
                _navigateTo(GroupSettingsScreen(group: _group), refresh: true);
              }
            },
            itemBuilder: (context) => [
              if (_isAdmin)
                const PopupMenuItem(
                  value: 'settings',
                  child: Text('Group Settings'),
                ),
              const PopupMenuItem(
                value: 'leave',
                child: Text('Leave Group', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: _buildCurrentView(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Members',
          ),
          if (_isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => _navigateTo(
                CreateGroupPostScreen(group: _group),
                refresh: true,
              ),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildCurrentView() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeView();
      case 1:
        return _buildChatView();
      case 2:
        return _buildMembersView();
      case 3:
        if (_isAdmin) return _buildSettingsView();
        return _buildHomeView();
      default:
        return _buildHomeView();
    }
  }

  Widget _buildHomeView() {
    final currentUser = Provider.of<AuthService>(context).currentUser;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildGroupHeader()),
        SliverToBoxAdapter(child: _buildCreatePostSection(currentUser)),
        _buildPostsSection(),
      ],
    );
  }

  Widget _buildChatView() {
    return GroupChatScreen(group: _group);
  }

  Widget _buildMembersView() {
    return GroupMembersScreen(group: _group);
  }

  Widget _buildSettingsView() {
    return GroupSettingsScreen(group: _group);
  }

  Widget _buildGroupHeader() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildGroupImage(),
                const SizedBox(width: 16),
                _buildGroupInfo(),
              ],
            ),
            if (_group.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _group.description,
                style: TextStyle(color: Colors.grey[800]),
              ),
            ],
            if (_group.district != null) _buildDistrictInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        image: _group.image != null
            ? DecorationImage(
                image: NetworkImage(_group.image!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: _group.image == null
          ? const Center(
              child: Icon(
                Icons.group,
                size: 40,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }

  Widget _buildGroupInfo() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _group.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _group.category,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _group.isPublic
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _group.isPublic ? 'Public' : 'Private',
                  style: TextStyle(
                    color: _group.isPublic ? Colors.green : Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.people, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${_group.membersCount} member${_group.membersCount != 1 ? 's' : ''}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictInfo() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              _group.district!,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCreatePostSection(User? currentUser) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton(
        onPressed: () => _navigateTo(
          CreateGroupPostScreen(group: _group),
          refresh: true,
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundImage: currentUser?.profilePicture != null
                    ? NetworkImage(currentUser!.profilePicture!)
                    : null,
                child: currentUser?.profilePicture == null
                    ? const Icon(Icons.person, size: 15)
                    : null,
              ),
              const SizedBox(width: 12),
              const Text('Write something...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostsSection() {
    return _groupPosts.isEmpty
        ? SliverFillRemaining(child: _buildEmptyPosts())
        : SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: GroupPostCard(
                  post: _groupPosts[index],
                  isGroupMember: _isMember,
                  onPostUpdated: _loadGroupData,
                ),
              ),
              childCount: _groupPosts.length,
            ),
          );
  }

  Widget _buildEmptyPosts() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.post_add,
            size: 60,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share something with the group!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateTo(
              CreateGroupPostScreen(group: _group),
              refresh: true,
            ),
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
