// lib/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/notification.dart' as app_notification;
import 'package:turikumwe/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<app_notification.Notification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
      if (currentUser != null) {
        final notifications = await DatabaseService().getNotifications(
          currentUser.id,
        );
        
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
      if (currentUser != null) {
        // In a real app, we would have a method to mark all as read in one go
        // For this implementation, we'll update each one individually
        for (final notification in _notifications) {
          if (!notification.isRead) {
            await DatabaseService().markNotificationAsRead(notification.id);
          }
        }
        
        // Refresh notifications list
        _loadNotifications();
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  Future<void> _markAsRead(int id) async {
    try {
      await DatabaseService().markNotificationAsRead(id);
      setState(() {
        _notifications = _notifications.map((notification) {
          if (notification.id == id) {
            return app_notification.Notification(
              id: notification.id,
              userId: notification.userId,
              title: notification.title,
              content: notification.content,
              type: notification.type,
              relatedId: notification.relatedId,
              timestamp: notification.timestamp,
              isRead: true,
            );
          }
          return notification;
        }).toList();
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _notifications.isEmpty ? null : _markAllAsRead,
            child: const Text('Mark all as read'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return _buildNotificationTile(notification);
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
            Icons.notifications_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'When you receive notifications, they will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(app_notification.Notification notification) {
    IconData iconData;
    Color iconColor;
    
    switch (notification.type) {
      case 'like':
        iconData = Icons.favorite;
        iconColor = Colors.red;
        break;
      case 'comment':
        iconData = Icons.chat_bubble;
        iconColor = Colors.blue;
        break;
      case 'group':
        iconData = Icons.group;
        iconColor = AppColors.primary;
        break;
      case 'event':
        iconData = Icons.event;
        iconColor = AppColors.secondary;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }
    
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.1),
        child: Icon(iconData, color: iconColor),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.content),
          const SizedBox(height: 4),
          Text(
            timeago.format(notification.timestamp),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      trailing: notification.isRead
          ? null
          : Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
            ),
      onTap: () {
        // Navigate to related content
        // For example, if type is 'post', navigate to that post
        
        // Mark as read if not already
        if (!notification.isRead) {
          _markAsRead(notification.id);
        }
      },
    );
  }
}