// lib/screens/messages_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/chat_screen.dart';
import 'package:turikumwe/screens/user_search_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _directChats = [];
  List<Map<String, dynamic>> _groupChats = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadConversations();
    
    // Set up listener to refresh when returning to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNavListener();
    });
  }
  
  void _setupNavListener() {
    // Listen for navigation events to refresh data when returning to this screen
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) {
        if (route.settings.name == '/messages') {
          _loadConversations();
        }
        return true;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final conversations = await _databaseService.getChatConversations(currentUser.id);
      
      // Separate direct chats and group chats
      final directChats = conversations.where((chat) => chat['isGroup'] != 1).toList();
      final groupChats = conversations.where((chat) => chat['isGroup'] == 1).toList();
      
      setState(() {
        _conversations = conversations;
        _directChats = directChats;
        _groupChats = groupChats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading conversations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToUserSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/user_search'),
        builder: (context) => const UserSearchScreen(),
      ),
    ).then((_) {
      // Refresh conversations when returning from user search
      _loadConversations();
    });
  }

  void _openChat(int userId, String name, bool isGroup) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/chat'),
        builder: (context) => ChatScreen(
          chatId: userId,
          chatName: name,
          isGroup: isGroup,
        ),
      ),
    ).then((_) {
      // Refresh conversations when returning from chat
      _loadConversations();
    });
  }

  String _formatLastMessageTime(String isoTimeString) {
    final dateTime = DateTime.parse(isoTimeString);
    final now = DateTime.now();
    
    if (now.difference(dateTime).inHours < 24) {
      // Today, show time
      return DateFormat('h:mm a').format(dateTime);
    } else if (now.difference(dateTime).inDays < 7) {
      // Within a week, show day name
      return DateFormat('E').format(dateTime);
    } else {
      // Older, show date
      return DateFormat('M/d/yy').format(dateTime);
    }
  }

  Widget _buildConversationItem(Map<String, dynamic> conversation, bool isGroup) {
    final unreadCount = conversation['unreadCount'] ?? 0;
    final hasUnread = unreadCount > 0;
    final lastMessage = conversation['lastMessage'] ?? '';
    final isSentByMe = conversation['lastMessageSenderId'] == 
        Provider.of<AuthService>(context, listen: false).currentUser?.id;
    final isRead = conversation['isLastMessageRead'] == 1;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isGroup ? AppColors.primary.withOpacity(0.2) : Colors.grey.shade300,
        backgroundImage: conversation['profilePicture'] != null
            ? NetworkImage(conversation['profilePicture']) as ImageProvider
            : null,
        child: conversation['profilePicture'] == null
            ? Text(
                (conversation['name'] ?? 'U')[0].toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isGroup ? AppColors.primary : null,
                ),
              )
            : null,
      ),
      title: Text(
        conversation['name'] ?? 'Unknown',
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Row(
        children: [
          // Message status indicator (for messages sent by current user)
          if (isSentByMe) ...[
            Icon(
              isRead ? Icons.done_all : Icons.done,
              size: 16,
              color: isRead ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 4),
          ],
          // Last message preview
          Expanded(
            child: Text(
              lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                color: hasUnread ? Colors.black87 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatLastMessageTime(conversation['lastMessageTime']),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        final id = isGroup ? conversation['groupId'] : conversation['otherUserId'];
        _openChat(
          id,
          conversation['name'] ?? 'Chat',
          isGroup,
        );
      },
    );
  }

  Widget _buildEmptyState({required String title, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey,
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
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToUserSearch,
            icon: const Icon(Icons.person_add),
            label: const Text('Find People to Chat With'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectChatsTab() {
    if (_directChats.isEmpty) {
      return _buildEmptyState(
        title: 'No Direct Messages',
        message: 'Start a conversation with someone',
      );
    }

    return ListView.separated(
      itemCount: _directChats.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return _buildConversationItem(_directChats[index], false);
      },
    );
  }

  Widget _buildGroupChatsTab() {
    if (_groupChats.isEmpty) {
      return _buildEmptyState(
        title: 'No Group Chats',
        message: 'Join or create a group to chat with multiple people',
      );
    }

    return ListView.separated(
      itemCount: _groupChats.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return _buildConversationItem(_groupChats[index], true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = Provider.of<AuthService>(context).currentUser != null;

    if (!isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Login to see your messages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Navigate to login screen
              },
              child: const Text('Login'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _navigateToUserSearch,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDirectChatsTab(),
                _buildGroupChatsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToUserSearch,
        backgroundColor: AppColors.primary,
        tooltip: 'New Message',
        child: const Icon(Icons.chat),
      ),
    );
  }
}