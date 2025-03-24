// lib/screens/messages_screen.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/screens/chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final bool _isLoading = false;
  
  // Dummy data for chat previews
  final List<Map<String, dynamic>> _directChats = [
    {
      'id': 1,
      'name': 'Jean Mutoni',
      'avatar': 'assets/images/avatar1.png',
      'lastMessage': 'Hello, how are you doing today?',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
      'unread': 2,
    },
    {
      'id': 2,
      'name': 'Emmanuel Hakizimana',
      'avatar': 'assets/images/avatar2.png',
      'lastMessage': 'Are you coming to the community event tomorrow?',
      'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
      'unread': 0,
    },
    {
      'id': 3,
      'name': 'Alice Uwase',
      'avatar': 'assets/images/avatar3.png',
      'lastMessage': 'Thank you for your help with the project!',
      'timestamp': DateTime.now().subtract(const Duration(days: 1)),
      'unread': 0,
    },
  ];
  
  final List<Map<String, dynamic>> _groupChats = [
    {
      'id': 1,
      'name': 'Kigali Tech Community',
      'avatar': 'assets/images/group1.png',
      'lastMessage': 'Jean: Does anyone have experience with Flutter?',
      'timestamp': DateTime.now().subtract(const Duration(hours: 3)),
      'unread': 5,
    },
    {
      'id': 2,
      'name': 'Muhanga Agriculture Group',
      'avatar': 'assets/images/group2.png',
      'lastMessage': 'Alice: The next meeting is on Friday at 2pm',
      'timestamp': DateTime.now().subtract(const Duration(days: 2)),
      'unread': 0,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Direct Messages'),
            Tab(text: 'Group Chats'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Direct Messages Tab
              _buildChatList(_directChats, false),
              
              // Group Chats Tab
              _buildChatList(_groupChats, true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatList(List<Map<String, dynamic>> chats, bool isGroup) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : chats.isEmpty
            ? _buildEmptyState(isGroup)
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  return _buildChatTile(chat, isGroup);
                },
              );
  }

  Widget _buildChatTile(Map<String, dynamic> chat, bool isGroup) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: AssetImage(chat['avatar']),
        backgroundColor: isGroup ? AppColors.primary.withOpacity(0.2) : null,
        child: isGroup
            ? const Icon(Icons.group, color: AppColors.primary)
            : null,
      ),
      title: Text(
        chat['name'],
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        chat['lastMessage'],
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            timeago.format(chat['timestamp'], locale: 'en_short'),
            style: TextStyle(
              fontSize: 12,
              color: chat['unread'] > 0 ? AppColors.primary : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          if (chat['unread'] > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${chat['unread']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chat['id'],
              chatName: chat['name'],
              isGroup: isGroup,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isGroup) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isGroup ? Icons.group_outlined : Icons.chat_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            isGroup
                ? 'No group chats yet'
                : 'No messages yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isGroup
                ? 'Join groups to start chatting with members'
                : 'Connect with community members to start conversations',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
                   onPressed: () {
              if (isGroup) {
                // Navigate to groups screen
                Navigator.popUntil(context, ModalRoute.withName('/'));
                // Then select groups tab
              } else {
                // Show new message screen
              }
            },
            icon: Icon(isGroup ? Icons.group_add : Icons.chat),
            label: Text(isGroup ? 'Join Groups' : 'New Message'),
          ),
        ],
      ),
    );
  }
}