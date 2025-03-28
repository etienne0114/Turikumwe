// lib/screens/user_search_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/chat_screen.dart';
import 'package:turikumwe/screens/profile_screen.dart';
 // Make sure this import is corr
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/user_service.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({Key? key}) : super(key: key);

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  bool _isLoading = false;
  List<User> _searchResults = [];
  List<User> _recentContacts = [];
  List<User> _groupContacts = [];
  String _searchQuery = '';
  bool _showRecents = true;

  @override
  void initState() {
    super.initState();
    _loadInitialContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialContacts() async {
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Load recent contacts
      final recentContacts = await _userService.getRecentContacts(currentUser.id);
      
      // Load group contacts (people from same groups)
      final groupContacts = await _userService.getContactsFromGroups(currentUser.id);
      
      setState(() {
        _recentContacts = recentContacts;
        _groupContacts = groupContacts.where((contact) => 
          !_recentContacts.any((recent) => recent.id == contact.id)
        ).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading contacts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    if (currentUser == null) return;
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchQuery = '';
        _showRecents = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchQuery = query;
      _showRecents = false;
    });

    try {
      final results = await _userService.searchUsers(query, exceptUserId: currentUser.id);
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      print('Error searching users: $e');
      setState(() {
        _isLoading = false;
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
    );
  }

  void _viewProfile(User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        // Fixed: Changed parameter name to 'id' to match ProfileDetailsScreen constructor
        builder: (context) => ProfileScreen(id: user.id),
      ),
    );
  }

  Widget _buildUserItem(User user, {bool isRecent = false}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade300,
        backgroundImage: user.profilePicture != null
            ? NetworkImage(user.profilePicture!) as ImageProvider
            : null,
        child: user.profilePicture == null
            ? Text(
                user.name[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : null,
      ),
      title: Text(user.name),
      subtitle: Text(user.district ?? 'No district'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _viewProfile(user),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            color: AppColors.primary,
            onPressed: () => _startChat(user),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchQuery.isNotEmpty && _searchResults.isEmpty) {
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
        return _buildUserItem(user);
      },
    );
  }

  Widget _buildRecentContacts() {
    if (_recentContacts.isEmpty && _groupContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No contacts yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Search for people to chat with',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (_recentContacts.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Recent Chats',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
          ...List.generate(_recentContacts.length, (index) {
            return _buildUserItem(_recentContacts[index], isRecent: true);
          }),
        ],
        
        if (_groupContacts.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'People from Your Groups',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
          ...List.generate(_groupContacts.length, (index) {
            return _buildUserItem(_groupContacts[index]);
          }),
        ],
      ],
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
              Icons.person_search,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Login to search for people',
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
        title: const Text('Find People'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or district...',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchUsers('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onChanged: _searchUsers,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _showRecents
              ? _buildRecentContacts()
              : _buildSearchResults(),
    );
  }
}