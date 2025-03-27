// lib/screens/groups/group_members_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';

class GroupMembersScreen extends StatefulWidget {
  final Group group;

  const GroupMembersScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isCurrentUserAdmin = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
      
      // Get all group members with their admin status
      final members = await DatabaseService().getGroupMembers(widget.group.id);
      
      // Check if current user is admin
      if (_currentUser != null) {
        final membership = await DatabaseService().getGroupMembership(
          widget.group.id,
          _currentUser!.id,
        );
        
        setState(() {
          _isCurrentUserAdmin = membership != null && membership['isAdmin'] == 1;
        });
      }
      
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading group members: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Failed to load group members',
        );
      }
    }
  }
  
  Future<void> _makeAdmin(int userId) async {
    if (!_isCurrentUserAdmin) return;
    
    try {
      await DatabaseService().updateGroupMemberRole(
        widget.group.id,
        userId,
        true, // Make admin
      );
      
      await _loadMembers();
      
      if (mounted) {
        DialogUtils.showSuccessSnackBar(
          context,
          message: 'Member promoted to admin',
        );
      }
    } catch (e) {
      print('Error making member admin: $e');
      if (mounted) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Failed to update member role',
        );
      }
    }
  }
  
  Future<void> _removeAdmin(int userId) async {
    if (!_isCurrentUserAdmin) return;
    
    // Don't allow removing the last admin
    final adminCount = _members.where((m) => m['isAdmin'] == 1).length;
    if (adminCount <= 1) {
      DialogUtils.showErrorSnackBar(
        context,
        message: 'Cannot remove the only admin',
      );
      return;
    }
    
    try {
      await DatabaseService().updateGroupMemberRole(
        widget.group.id,
        userId,
        false, // Remove admin
      );
      
      await _loadMembers();
      
      if (mounted) {
        DialogUtils.showSnackBar(
          context,
          message: 'Admin role removed',
        );
      }
    } catch (e) {
      print('Error removing admin role: $e');
      if (mounted) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Failed to update member role',
        );
      }
    }
  }
  
  Future<void> _removeMember(int userId) async {
    if (!_isCurrentUserAdmin) return;
    
    // Don't allow removing yourself as admin
    if (userId == _currentUser?.id) {
      DialogUtils.showErrorSnackBar(
        context,
        message: 'You cannot remove yourself from the group. Use the leave group option instead.',
      );
      return;
    }
    
    // Show confirmation dialog
    final confirm = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Remove Member',
      message: 'Are you sure you want to remove this member from the group?',
      confirmText: 'Remove',
      cancelText: 'Cancel', isDangerous: false,
    );
    
    if (!confirm) return;
    
    try {
      await DatabaseService().removeGroupMember(widget.group.id, userId);
      await DatabaseService().decrementGroupMembersCount(widget.group.id);
      
      await _loadMembers();
      
      if (mounted) {
        DialogUtils.showSnackBar(
          context,
          message: 'Member removed from group',
        );
      }
    } catch (e) {
      print('Error removing group member: $e');
      if (mounted) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Failed to remove member',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Members (${widget.group.membersCount})'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final isAdmin = member['isAdmin'] == 1;
                    final user = member['user'] as User;
                    final isCurrentUser = user.id == _currentUser?.id;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.profilePicture != null 
                            ? NetworkImage(user.profilePicture!) 
                            : null,
                        child: user.profilePicture == null 
                            ? Text(user.name[0].toUpperCase()) 
                            : null,
                      ),
                      title: Text(
                        user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          if (isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Admin',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          if (isCurrentUser && !isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: _isCurrentUserAdmin && !isCurrentUser
                          ? PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'make_admin':
                                    _makeAdmin(user.id);
                                    break;
                                  case 'remove_admin':
                                    _removeAdmin(user.id);
                                    break;
                                  case 'remove':
                                    _removeMember(user.id);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                if (!isAdmin)
                                  const PopupMenuItem(
                                    value: 'make_admin',
                                    child: Text('Make Admin'),
                                  ),
                                if (isAdmin)
                                  const PopupMenuItem(
                                    value: 'remove_admin',
                                    child: Text('Remove Admin Role'),
                                  ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove from Group'),
                                ),
                              ],
                            )
                          : null,
                    );
                  },
                ),
      floatingActionButton: _isCurrentUserAdmin
          ? FloatingActionButton(
              onPressed: () {
                // Navigate to invite members screen
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No members found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to join this group',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}