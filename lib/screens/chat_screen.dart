// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/message.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/services/file_service.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ChatScreen extends StatefulWidget {
  final int chatId;   // Ensure this is explicitly typed as int
  final String chatName;
  final bool isGroup;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.chatName,
    this.isGroup = false,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseService _databaseService = DatabaseService();
  final FileService _fileService = FileService();
  
  bool _isLoading = true;
  bool _isSending = false;
  List<Message> _messages = [];
  File? _selectedFile;
  String? _selectedFileName;
  bool _isFileAttached = false;
  String? _fileType;
  String? _fileMimeType;
  int? _currentUserId;
  
  // Timer for periodically checking for new messages
  // In a real app, this would be replaced with a socket or push notification system
  bool _isCheckingNewMessages = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.id;
    _loadMessages();
    
    // Start checking for new messages every 5 seconds
    _setupMessagePolling();
  }
  
  void _setupMessagePolling() {
    // In a real app, you would use sockets or push notifications instead of polling
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _checkForNewMessages();
        _setupMessagePolling();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _isCheckingNewMessages = false;
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (_currentUserId == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      List<Message> messages;
      
      if (widget.isGroup) {
        // For group chats, get messages for that group
        messages = await _databaseService.getMessages(
          groupId: widget.chatId,
        );
      } else {
        // For direct chats, get messages between these two users
        messages = await _databaseService.getMessages(
          senderId: _currentUserId,
          receiverId: widget.chatId,
        );
      }
      
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      
      // Mark messages as read
      _markMessagesAsRead();
      
      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      print('Error loading messages: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _checkForNewMessages() async {
    if (_isCheckingNewMessages || !mounted || _currentUserId == null) return;
    
    _isCheckingNewMessages = true;
    try {
      List<Message> latestMessages;
      
      if (widget.isGroup) {
        latestMessages = await _databaseService.getMessages(
          groupId: widget.chatId,
        );
      } else {
        latestMessages = await _databaseService.getMessages(
          senderId: _currentUserId,
          receiverId: widget.chatId,
        );
      }
      
      // Check if there are new messages
      if (latestMessages.length > _messages.length) {
        setState(() {
          _messages = latestMessages;
        });
        
        // Mark new messages as read
        _markMessagesAsRead();
        
        // If user is already at the bottom, scroll to the new messages
        if (_isScrolledToBottom()) {
          _scrollToBottom();
        } else {
          // Show a "new message" indicator
          _showNewMessageNotification();
        }
      }
    } catch (e) {
      print('Error checking for new messages: $e');
    } finally {
      _isCheckingNewMessages = false;
    }
  }
  
  bool _isScrolledToBottom() {
    if (!_scrollController.hasClients) return true;
    
    final position = _scrollController.position;
    return position.pixels >= position.maxScrollExtent - 10;
  }
  
  void _showNewMessageNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('New messages'),
        action: SnackBarAction(
          label: 'View',
          onPressed: _scrollToBottom,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _markMessagesAsRead() async {
    if (_currentUserId == null) return;
    
    try {
      // Find unread messages from the other user
      final unreadMessages = _messages.where((msg) => 
        !msg.isRead && msg.senderId != _currentUserId
      ).toList();
      
      if (unreadMessages.isNotEmpty) {
        // Mark messages as read in database
        for (var message in unreadMessages) {
          await _databaseService.markMessageAsRead(message.id);
        }
        
        // Update messages in state
        setState(() {
          for (var i = 0; i < _messages.length; i++) {
            if (!_messages[i].isRead && _messages[i].senderId != _currentUserId) {
              _messages[i] = Message(
                id: _messages[i].id,
                senderId: _messages[i].senderId,
                receiverId: _messages[i].receiverId,
                groupId: _messages[i].groupId,
                content: _messages[i].content,
                timestamp: _messages[i].timestamp,
                isRead: true,
                fileUrl: _messages[i].fileUrl,
                fileType: _messages[i].fileType,
                fileName: _messages[i].fileName,
              );
            }
          }
        });
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickFile() async {
    if (!_fileService.isMobilePlatform) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File picking is currently only supported on mobile devices')),
      );
      return;
    }

    try {
      final result = await _fileService.pickFile();
      if (result != null) {
        setState(() {
          _selectedFile = result.file;
          _selectedFileName = result.fileName;
          _isFileAttached = true;
          _fileType = result.fileType;
          _fileMimeType = result.mimeType;
        });
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _pickImage({bool fromCamera = false}) async {
    try {
      final result = await _fileService.pickImage(fromCamera: fromCamera);
      if (result != null) {
        setState(() {
          _selectedFile = result.file;
          _selectedFileName = result.fileName;
          _isFileAttached = true;
          _fileType = result.fileType;
          _fileMimeType = result.mimeType;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _pickVideo({bool fromCamera = false}) async {
    try {
      final result = await _fileService.pickVideo(fromCamera: fromCamera);
      if (result != null) {
        setState(() {
          _selectedFile = result.file;
          _selectedFileName = result.fileName;
          _isFileAttached = true;
          _fileType = result.fileType;
          _fileMimeType = result.mimeType;
        });
      }
    } catch (e) {
      print('Error picking video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking video: $e')),
      );
    }
  }

  void _clearAttachment() {
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
      _isFileAttached = false;
      _fileType = null;
      _fileMimeType = null;
    });
  }

  Future<void> _sendMessage() async {
    if ((_messageController.text.trim().isEmpty && !_isFileAttached) || _isSending || _currentUserId == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
      if (currentUser == null) return;

      final messageText = _messageController.text.trim();
      Message newMessage;
      int messageId = 0;
      
      // Ensure chatId is an int
      final recipientId = widget.chatId;
      
      if (_isFileAttached && _selectedFile != null && _selectedFileName != null) {
        // Send message with file attachment
        final fileResult = FileResult(
          file: _selectedFile!,
          fileName: _selectedFileName!,
          fileType: _fileType ?? 'file',
          mimeType: _fileMimeType ?? 'application/octet-stream',
        );
        
        try {
          // Upload file and save message
          final result = await _fileService.uploadFileAndSaveMessage(
            fileResult: fileResult,
            senderId: currentUser.id,
            receiverId: recipientId, // Use the ensured int value
            groupId: widget.isGroup ? recipientId : null,
            message: messageText,
          );
          
          // TYPE FIX: Ensure result is treated as int
          if (result is int) {
            messageId = int.tryParse(result ?? '0') ?? 0;
          } else if (result != null) {
            // Try to parse the result as int
            messageId = int.tryParse(result.toString()) ?? 0;
          }
        } catch(e) {
          print('Error uploading file: $e');
          messageId = 0;
        }
        
        // Create new message object
        newMessage = Message(
          id: messageId,
          senderId: currentUser.id,
          receiverId: recipientId, // Use the ensured int value
          groupId: widget.isGroup ? recipientId : null,
          content: messageText.isEmpty 
              ? '[${_fileType}] ${_selectedFileName}' 
              : '$messageText\n[${_fileType}] ${_selectedFileName}',
          timestamp: DateTime.now(),
          isRead: false,
          fileUrl: 'pending_upload', // Will be updated when upload is complete
          fileType: _fileType,
          fileName: _selectedFileName,
        );
      } else {
        // Send text-only message
        final messageData = {
          'senderId': currentUser.id,
          'receiverId': recipientId, // Use the ensured int value
          'groupId': widget.isGroup ? recipientId : null,
          'content': messageText,
          'timestamp': DateTime.now().toIso8601String(),
          'isRead': 0,
        };
        
        // Save message to database
        try {
          final result = await _databaseService.insertMessage(messageData);
          // TYPE FIX: Ensure result is treated as int
          if (result is int) {
            messageId = result;
          } else if (result != null) {
            // Try to parse the result as int
            messageId = int.tryParse(result.toString()) ?? 0;
          }
        } catch (e) {
          print('Error inserting message: $e');
          messageId = 0;
        }
        
        // Create new message object
        newMessage = Message(
          id: messageId,
          senderId: currentUser.id,
          receiverId: recipientId, // Use the ensured int value
          groupId: widget.isGroup ? recipientId : null,
          content: messageText,
          timestamp: DateTime.now(),
          isRead: false,
        );
      }
      
      // Add message to local state
      setState(() {
        _messages.add(newMessage);
        _messageController.clear();
        _clearAttachment();
      });
      
      // Scroll to bottom to show new message
      _scrollToBottom();
      
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Share Content',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.purple,
                child: Icon(Icons.photo_library, color: Colors.white),
              ),
              title: const Text('Photo from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(fromCamera: false);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.photo_camera, color: Colors.white),
              ),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(fromCamera: true);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.videocam, color: Colors.white),
              ),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(fromCamera: true);
              },
            ),
            if (_fileService.isMobilePlatform) // Only show document option on mobile platforms
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.insert_drive_file, color: Colors.white),
                ),
                title: const Text('Document'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: widget.isGroup ? AppColors.primary.withOpacity(0.2) : null,
              child: widget.isGroup
                  ? const Icon(Icons.group, color: AppColors.primary)
                  : Text(widget.chatName[0]),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.isGroup ? '${_messages.length} messages' : 'Online',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show profile or group info
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyChat()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = message.senderId == _currentUserId;
                            
                            return _buildMessageBubble(message, isMe);
                          },
                        ),
                ),
                if (_isFileAttached) _buildAttachmentPreview(),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation with ${widget.chatName}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    final dateFormat = DateFormat('h:mm a');
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isGroup && !isMe)
              Text(
                'User ${message.senderId}', // In a real app, get the actual sender name
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isMe ? Colors.white.withOpacity(0.8) : Colors.black54,
                ),
              ),
            _buildMessageContent(message, isMe),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  dateFormat.format(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white.withOpacity(0.8) : Colors.black54,
                  ),
                ),
                const SizedBox(width: 4),
                // Show read receipts only for messages sent by the current user
                if (isMe)
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead 
                        ? Colors.blue.withOpacity(0.8) 
                        : (isMe ? Colors.white.withOpacity(0.8) : Colors.black54),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(Message message, bool isMe) {
    // Check if the message contains file information
    if (message.fileType != null && message.fileName != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.content.isNotEmpty && !message.content.startsWith('['))
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                message.content.split('\n').first,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black,
                ),
              ),
            ),
          _buildFilePreview(message, isMe),
        ],
      );
    } else {
      return Text(
        message.content,
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black,
        ),
      );
    }
  }

  Widget _buildFilePreview(Message message, bool isMe) {
    // Here we'd normally check the actual file type and display appropriate preview
    // For the demo, we're using the fileType string to determine the icon
    
    IconData iconData;
    String displayText = message.fileName ?? 'File';
    
    switch (message.fileType) {
      case 'image':
        iconData = Icons.image;
        break;
      case 'video':
        iconData = Icons.video_file;
        break;
      case 'audio':
        iconData = Icons.audio_file;
        break;
      case 'document':
        iconData = Icons.insert_drive_file;
        break;
      default:
        iconData = Icons.attachment;
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          iconData,
          color: isMe ? Colors.white : AppColors.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            displayText,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentPreview() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _fileType == 'image' ? Icons.image : 
              _fileType == 'video' ? Icons.videocam :
              _fileType == 'document' ? Icons.insert_drive_file :
              Icons.attach_file,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _selectedFileName ?? 'Attachment',
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _clearAttachment,
            color: Colors.grey,
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _showAttachmentOptions,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 5,
              enabled: !_isSending,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: _isSending 
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2)
                  )
                : const Icon(Icons.send),
            color: AppColors.primary,
            onPressed: _isSending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}