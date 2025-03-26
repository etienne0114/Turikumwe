// lib/widgets/group_membership_button.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';

class GroupMembershipButton extends StatefulWidget {
  final Group group;
  final bool isMember;
  final bool isAdmin;
  final VoidCallback onMembershipChanged;

  const GroupMembershipButton({
    Key? key,
    required this.group,
    required this.isMember,
    required this.isAdmin,
    required this.onMembershipChanged,
  }) : super(key: key);

  @override
  State<GroupMembershipButton> createState() => _GroupMembershipButtonState();
}

class _GroupMembershipButtonState extends State<GroupMembershipButton> {
  bool _isLoading = false;

  Future<void> _joinGroup() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final databaseService = Provider.of<DatabaseService>(context, listen: false);

    if (authService.currentUser == null) {
      DialogUtils.showErrorSnackBar(context, message: 'Please login to join groups');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await databaseService.addGroupMember({
        'groupId': widget.group.id,
        'userId': authService.currentUser!.id,
        'isAdmin': 0,
        'joinedAt': DateTime.now().toIso8601String(),
      });

      await databaseService.incrementGroupMembersCount(widget.group.id);

      setState(() => _isLoading = false);
      
      if (mounted) {
        DialogUtils.showSuccessSnackBar(context, message: 'Joined group successfully');
        widget.onMembershipChanged();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        DialogUtils.showErrorSnackBar(context, message: 'Failed to join group: ${e.toString()}');
      }
    }
  }

  Future<void> _leaveGroup() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    
    if (authService.currentUser == null) return;

    if (widget.isAdmin) {
      DialogUtils.showErrorSnackBar(
        context, 
        message: 'Admins cannot leave the group. Transfer admin role first.'
      );
      return;
    }

    final confirm = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Leave Group',
      message: 'Are you sure you want to leave this group?',
      confirmText: 'Leave',
      cancelText: 'Cancel',
      // Using isDangerous parameter with correct spelling
      isDangerous: true,
    );

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      await databaseService.removeGroupMember(
        widget.group.id, 
        authService.currentUser!.id
      );

      await databaseService.decrementGroupMembersCount(widget.group.id);

      setState(() => _isLoading = false);
      
      if (mounted) {
        DialogUtils.showSnackBar(context, message: 'You left the group');
        widget.onMembershipChanged();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        DialogUtils.showErrorSnackBar(context, message: 'Failed to leave group: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: double.infinity,
        height: 45,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (widget.isMember) {
      return SizedBox(
        width: double.infinity,
        height: 45,
        child: OutlinedButton.icon(
          onPressed: _leaveGroup,
          icon: const Icon(Icons.exit_to_app),
          label: const Text('Leave Group'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 45,
        child: ElevatedButton.icon(
          onPressed: _joinGroup,
          icon: const Icon(Icons.group_add),
          label: const Text('Join Group'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }
  }
}