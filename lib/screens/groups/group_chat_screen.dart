// lib/screens/groups/group_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/models/message.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class GroupChatScreen extends StatefulWidget {
  final Group group;

  const GroupChatScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Message> _messages = [];
  final Map<int, User> _users = {}; // Cache of users by ID
  bool _isLoading = true;
  User? _currentUser;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    _loadMessages();
    
    // Set up periodic refresh
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _loadMessages(showLoading: false);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Load group messages
      final messages = await DatabaseService().getMessages(groupId: widget.group.id);
      
      // Load user data for all message senders
      final Set<int> userIds = messages.map((m) => m.senderId).toSet();
      
      for (final userId in userIds) {
        if (!_users.containsKey(userId)) {
          final user = await DatabaseService().getUserById(userId);
          if (user != null) {
            _users[userId] = user;
          }
        }
      }
      
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      
      // Scroll to bottom on new messages
      if (_messages.isNotEmpty && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (e) {
      print('Error loading messages: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _currentUser == null) return;

    _messageController.clear();

    try {
      final message = {
        'senderId': _currentUser!.id,
        'receiverId': 0, // 0 for group messages
        'groupId': widget.group.id,
        'content': messageText,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': 0,
      };

      await DatabaseService().insertMessage(message);
      _loadMessages(showLoading: false);
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Failed to send message',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: widget.group.image != null ? NetworkImage(widget.group.image!) : null,
              child: widget.group.image == null
                  ? const Icon(Icons.group, size: 16, color: AppColors.primary)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.group.name,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${widget.group.membersCount} members',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show group info
            },
          ),
        ],
      ),
      body: _isLoading && _messages.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyChatState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = _currentUser != null && message.senderId == _currentUser!.id;
                            final sender = _users[message.senderId];
                            
                            // Check if we need to show a date separator
                            final showDateSeparator = index == 0 || 
                                !_isSameDay(
                                  _messages[index].timestamp, 
                                  _messages[index - 1].timestamp
                                );
                            
                            return Column(
                              children: [
                                if (showDateSeparator)
                                  _buildDateSeparator(message.timestamp),
                                _buildMessageBubble(message, isMe, sender),
                              ],
                            );
                          },
                        ),
                ),
                
                // Message input
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        onPressed: () {
                          // Implement attachment functionality
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade200,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          minLines: 1,
                          maxLines: 5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.send,
                          color: AppColors.primary,
                        ),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyChatState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to start the conversation!',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime dateTime) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatMessageDate(dateTime),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe, User? sender) {
    final dateFormat = DateFormat('h:mm a');
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Show sender name for messages from others
              if (!isMe && sender != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Text(
                    sender.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              
              // Message bubble
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.primary : Colors.grey[200],
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMessageDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, y').format(date);
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }
}