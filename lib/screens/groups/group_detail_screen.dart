import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/models/post.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/groups/create_group_post_screen.dart';
import 'package:turikumwe/screens/groups/group_chat_screen.dart';
import 'package:turikumwe/screens/groups/group_members_screen.dart';
import 'package:turikumwe/screens/groups/group_settings_screen.dart';
import 'package:turikumwe/services/service_locator.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
import 'package:turikumwe/widgets/post_card.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;

  const GroupDetailScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late Group _group;
  bool _isLoading = true;
  bool _isMember = false;
  bool _isAdmin = false;
  List<Post> _groupPosts = [];
  
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
      final authService = ServiceLocator.auth;
      final databaseService = ServiceLocator.database;

      // Check membership status if user is logged in
      if (authService.currentUser != null) {
        final membership = await databaseService.getGroupMembership(
          _group.id, 
          authService.currentUser!.id
        );
        
        if (mounted) {
          setState(() {
            _isMember = membership != null;
            _isAdmin = membership != null && membership['isAdmin'] == 1;
          });
        }
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
          message: 'Failed to load group data',
        );
      }
    }
  }

  Future<void> _joinGroup() async {
    final authService = ServiceLocator.auth;
    final databaseService = ServiceLocator.database;

    if (authService.currentUser == null) {
      DialogUtils.showErrorSnackBar(context, message: 'Please login to join groups');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await databaseService.addGroupMember({
        'groupId': _group.id,
        'userId': authService.currentUser!.id,
        'isAdmin': 0,
        'joinedAt': DateTime.now().toIso8601String(),
      });

      final updatedGroup = await databaseService.incrementGroupMembersCount(_group.id);

      if (mounted) {
        setState(() {
          _isMember = true;
          if (updatedGroup != null) _group = updatedGroup;
          _isLoading = false;
        });
        DialogUtils.showSuccessSnackBar(context, message: 'Joined group successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        DialogUtils.showErrorSnackBar(context, message: 'Failed to join group');
      }
    }
  }

  Future<void> _leaveGroup() async {
    final authService = ServiceLocator.auth;
    if (authService.currentUser == null) return;

    final confirm = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Leave Group',
      message: 'Are you sure you want to leave this group?',
      confirmText: 'Leave',
      cancelText: 'Cancel',
    );

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      await ServiceLocator.database.removeGroupMember(
        _group.id, 
        authService.currentUser!.id
      );

      final updatedGroup = await ServiceLocator.database.decrementGroupMembersCount(_group.id);

      if (mounted) {
        setState(() {
          _isMember = false;
          _isAdmin = false;
          if (updatedGroup != null) _group = updatedGroup;
          _isLoading = false;
        });
        DialogUtils.showSnackBar(context, message: 'You left the group');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        DialogUtils.showErrorSnackBar(context, message: 'Failed to leave group');
      }
    }
  }

  void _showGroupOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Group Options',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildOptionTile(
                icon: Icons.people,
                color: Colors.blue,
                label: 'View Members',
                onTap: () => _navigateTo(GroupMembersScreen(group: _group)),
              ),
              if (_isAdmin)
                _buildOptionTile(
                  icon: Icons.settings,
                  color: Colors.purple,
                  label: 'Group Settings',
                  onTap: () => _navigateTo(
                    GroupSettingsScreen(group: _group),
                    refresh: true,
                  ),
                ),
              if (_isMember)
                _buildOptionTile(
                  icon: Icons.chat,
                  color: Colors.green,
                  label: 'Group Chat',
                  onTap: () => _navigateTo(GroupChatScreen(group: _group)),
                ),
              if (_isMember)
                _buildOptionTile(
                  icon: Icons.share,
                  color: Colors.orange,
                  label: 'Share Group',
                  onTap: _shareGroup,
                ),
              if (_isMember && !_isAdmin)
                _buildOptionTile(
                  icon: Icons.exit_to_app,
                  color: Colors.red,
                  label: 'Leave Group',
                  onTap: _leaveGroup,
                ),
              if (!_isMember)
                _buildOptionTile(
                  icon: Icons.group_add,
                  color: AppColors.primary,
                  label: 'Join Group',
                  onTap: _joinGroup,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _navigateTo(Widget page, {bool refresh = false}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page))
      .then((_) => refresh ? _loadGroupData() : null);
  }

  void _shareGroup() {
    // TODO: Implement share functionality
    DialogUtils.showSnackBar(context, message: 'Share functionality coming soon');
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ServiceLocator.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(_group.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showGroupOptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildGroupHeader()),
                if (_isMember) _buildCreatePostSection(currentUser),
                _buildPostsSection(),
              ],
            ),
      floatingActionButton: _isMember
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
              Text(_group.description),
            ],
            if (_group.district != null) _buildDistrictInfo(),
            if (!_isMember) _buildJoinButton(),
            if (_isMember) _buildActionButtons(),
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
          ? Center(
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
          ),
          const SizedBox(height: 4),
          Text(
            _group.category,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.people, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${_group.membersCount} members',
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

  Widget _buildJoinButton() {
    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _joinGroup,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Join Group'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.chat,
              label: 'Chat',
              onTap: () => _navigateTo(GroupChatScreen(group: _group)),
            ),
            _buildActionButton(
              icon: Icons.people,
              label: 'Members',
              onTap: () => _navigateTo(GroupMembersScreen(group: _group)),
            ),
            if (_isAdmin)
              _buildActionButton(
                icon: Icons.settings,
                label: 'Manage',
                onTap: () => _navigateTo(
                  GroupSettingsScreen(group: _group),
                  refresh: true,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatePostSection(User? currentUser) {
    return SliverToBoxAdapter(
      child: Padding(
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
                child: PostCard(post: _groupPosts[index]),
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
            _isMember
                ? 'Be the first to share something with the group!'
                : 'Join the group to see and create posts',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (_isMember) ...[
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
        ],
      ),
    );
  }
}