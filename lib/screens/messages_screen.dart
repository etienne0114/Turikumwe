// lib/screens/messages_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/chat_screen.dart';
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
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSearching = false;
  List<Map<String, dynamic>> _conversations = [];
  List<User> _searchResults = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadConversations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
      
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading conversations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      // This is a placeholder. You need to implement a searchUsers method in your DatabaseService
      // For now, we'll simulate with some dummy data
      await Future.delayed(const Duration(milliseconds: 500));
      
      // In a real implementation, you'd call something like:
      // final users = await _databaseService.searchUsers(query);
      
      // Simulate search results
      final List<User> users = [];
      
      // Instead of this simulation, you should implement and call the actual database search
      if (query.toLowerCase().contains('a')) {
        users.add(User(
          id: 2,
          name: 'Alice Smith',
          email: 'alice@example.com',
          phoneNumber: '123456789',
          district: 'Kigali',
          profilePicture: null,
          bio: 'Community leader',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
      
      if (query.toLowerCase().contains('b')) {
        users.add(User(
          id: 3,
          name: 'Bob Johnson',
          email: 'bob@example.com',
          phoneNumber: '987654321',
          district: 'Rubavu',
          profilePicture: null,
          bio: 'Teacher',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
      
      setState(() {
        _searchResults = users;
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _startChat(User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: user.id,
          chatName: user.name,
          isGroup: false,
        ),
      ),
    ).then((_) {
      // Refresh conversations when returning from chat
      _loadConversations();
    });
  }

  void _openChat(int userId, String name, bool isGroup) {
    Navigator.push(
      context,
      MaterialPageRoute(
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
    
    if (now.difference(dateTime).inDays < 1) {
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

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search for people to chat...',
          prefixIcon: const Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _searchUsers('');
                  },
                )
              : null,
        ),
        onChanged: _searchUsers,
      ),
    );
  }

  Widget _buildConversationList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conversations.isEmpty) {
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
              'No conversations yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Search for people to start chatting!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final isGroup = conversation['isGroup'] == 1;
        final unreadCount = conversation['unreadCount'] ?? 0;
        final lastMessage = conversation['lastMessage'] ?? '';
        final hasUnread = unreadCount > 0;
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isGroup ? AppColors.primary.withOpacity(0.2) : Colors.grey.shade300,
            child: isGroup
                ? const Icon(Icons.group, color: AppColors.primary)
                : Text(
                    conversation['name'][0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
          title: Text(
            conversation['name'] ?? 'Unknown',
            style: TextStyle(
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              color: hasUnread ? Colors.black87 : Colors.grey,
            ),
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
            _openChat(
              isGroup ? conversation['groupId'] : conversation['otherUserId'],
              conversation['name'] ?? 'Chat',
              isGroup,
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No users found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No results for "$_searchQuery"',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.shade300,
            backgroundImage: user.profilePicture != null
                ? NetworkImage(user.profilePicture!)
                : null,
            child: user.profilePicture == null
                ? Text(
                    user.name[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          title: Text(user.name),
          subtitle: Text(user.district ?? ''),
          trailing: const Icon(Icons.chat_bubble_outline),
          onTap: () => _startChat(user),
        );
      },
    );
  }

  Widget _buildGroupsTab() {
    return ListView.builder(
      itemCount: _conversations.where((c) => c['isGroup'] == 1).length,
      itemBuilder: (context, index) {
        final groups = _conversations.where((c) => c['isGroup'] == 1).toList();
        if (index >= groups.length) return const SizedBox.shrink();
        
        final group = groups[index];
        final unreadCount = group['unreadCount'] ?? 0;
        final lastMessage = group['lastMessage'] ?? '';
        final hasUnread = unreadCount > 0;
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.2),
            child: const Icon(Icons.group, color: AppColors.primary),
          ),
          title: Text(
            group['name'] ?? 'Unknown Group',
            style: TextStyle(
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              color: hasUnread ? Colors.black87 : Colors.grey,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatLastMessageTime(group['lastMessageTime']),
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
            _openChat(
              group['groupId'],
              group['name'] ?? 'Group Chat',
              true,
            );
          },
        );
      },
    );
  }

  Widget _buildDirectMessagesTab() {
    return ListView.builder(
      itemCount: _conversations.where((c) => c['isGroup'] != 1).length,
      itemBuilder: (context, index) {
        final directMessages = _conversations.where((c) => c['isGroup'] != 1).toList();
        if (index >= directMessages.length) return const SizedBox.shrink();
        
        final conversation = directMessages[index];
        final unreadCount = conversation['unreadCount'] ?? 0;
        final lastMessage = conversation['lastMessage'] ?? '';
        final hasUnread = unreadCount > 0;
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.shade300,
            child: Text(
              (conversation['name'] ?? 'U')[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            conversation['name'] ?? 'Unknown',
            style: TextStyle(
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              color: hasUnread ? Colors.black87 : Colors.grey,
            ),
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
            _openChat(
              conversation['otherUserId'],
              conversation['name'] ?? 'Chat',
              false,
            );
          },
        );
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            _buildSearchBar(),
            if (_searchController.text.isEmpty) ...[
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'Chats'),
                  Tab(text: 'Groups'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDirectMessagesTab(),
                    _buildGroupsTab(),
                  ],
                ),
              ),
            ] else ...[
              Expanded(
                child: _buildSearchResults(),
              ),
            ],
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              if (_searchController.text.isEmpty) {
                _searchController.text = '';
                FocusScope.of(context).requestFocus(FocusNode());
              } else {
                _searchController.clear();
                _searchUsers('');
              }
            });
          },
          backgroundColor: AppColors.primary,
          child: Icon(_searchController.text.isEmpty ? Icons.search : Icons.clear),
        ),
      ),
    );
  }
}