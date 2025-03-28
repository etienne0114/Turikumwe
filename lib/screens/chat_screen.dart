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
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  final int chatId;
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
  List<Message> _messages = [];
  File? _selectedFile;
  String? _selectedFileName;
  bool _isFileAttached = false;
  String? _fileType;
  String? _fileMimeType;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // In a real app, load messages from database
      final messages = await _databaseService.getMessages(
        groupId: widget.isGroup ? widget.chatId : null,
        senderId: widget.isGroup ? null : Provider.of<AuthService>(context, listen: false).currentUser?.id,
        receiverId: widget.isGroup ? null : widget.chatId,
      );
      
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

  Future<void> _markMessagesAsRead() async {
    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    if (currentUser == null) return;

    try {
      await _databaseService.markAllMessagesAsRead(
        groupId: widget.isGroup ? widget.chatId : null,
        senderId: widget.isGroup ? null : widget.chatId,
        receiverId: currentUser.id,
      );
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

  void _showUnsupportedPlatformMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File picking is currently only supported on Android and iOS'),
      ),
    );
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
    if ((_messageController.text.trim().isEmpty && !_isFileAttached) || _isSending) return;

    final currentUser = Provider.of<AuthService>(context, listen: false).currentUser;
    if (currentUser == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final String messageContent = _messageController.text.trim();
      
      // If a file is attached, upload it first
      if (_isFileAttached && _selectedFile != null && _selectedFileName != null) {
        final fileResult = FileResult(
          file: _selectedFile!,
          fileName: _selectedFileName!,
          fileType: _fileType ?? 'file',
          mimeType: _fileMimeType ?? 'application/octet-stream',
        );
        
        final fileUrl = await _fileService.uploadFileAndSaveMessage(
          fileResult: fileResult,
          senderId: currentUser.id,
          receiverId: widget.chatId,
          groupId: widget.isGroup ? widget.chatId : null,
          message: messageContent,
        );
        
        if (fileUrl != null) {
          // Create a new message with file attachment
          final newMessage = Message(
            id: 0, // Database will assign real ID
            senderId: currentUser.id,
            receiverId: widget.chatId,
            groupId: widget.isGroup ? widget.chatId : null,
            content: messageContent.isEmpty 
                ? '[$_fileType] $_selectedFileName' 
                : '$messageContent\n[$_fileType] $_selectedFileName',
            timestamp: DateTime.now(),
            isRead: false,
            fileUrl: fileUrl,
            fileType: _fileType,
            fileName: _selectedFileName,
          );
          
          setState(() {
            _messages.add(newMessage);
            _messageController.clear();
            _clearAttachment();
          });
        }
      } else if (messageContent.isNotEmpty) {
        // Text-only message
        final messageData = {
          'senderId': currentUser.id,
          'receiverId': widget.chatId,
          'groupId': widget.isGroup ? widget.chatId : null,
          'content': messageContent,
          'timestamp': DateTime.now().toIso8601String(),
          'isRead': 0,
        };
        
        final messageId = await _databaseService.insertMessage(messageData);
        
        // Create a new message for the UI
        final newMessage = Message(
          id: messageId,
          senderId: currentUser.id,
          receiverId: widget.chatId,
          groupId: widget.isGroup ? widget.chatId : null,
          content: messageContent,
          timestamp: DateTime.now(),
          isRead: false,
        );
        
        setState(() {
          _messages.add(newMessage);
          _messageController.clear();
        });
      }
      
      // Scroll to the bottom
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
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final result = await _fileService.pickImage(fromCamera: false);
                if (result != null) {
                  setState(() {
                    _selectedFile = result.file;
                    _selectedFileName = result.fileName;
                    _isFileAttached = true;
                    _fileType = result.fileType;
                    _fileMimeType = result.mimeType;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.pop(context);
                final result = await _fileService.pickImage(fromCamera: true);
                if (result != null) {
                  setState(() {
                    _selectedFile = result.file;
                    _selectedFileName = result.fileName;
                    _isFileAttached = true;
                    _fileType = result.fileType;
                    _fileMimeType = result.mimeType;
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video'),
              onTap: () async {
                Navigator.pop(context);
                final result = await _fileService.pickVideo(fromCamera: true);
                if (result != null) {
                  setState(() {
                    _selectedFile = result.file;
                    _selectedFileName = result.fileName;
                    _isFileAttached = true;
                    _fileType = result.fileType;
                    _fileMimeType = result.mimeType;
                  });
                }
              },
            ),
            if (_fileService.isMobilePlatform) // Only show file option on mobile platforms
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Document'),
                onTap: () async {
                  Navigator.pop(context);
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
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile(Message message) async {
    if (message.fileUrl == null) return;
    
    try {
      // In a real app, download the file first if needed
      // For this demo, we'll just show a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening ${message.fileName ?? "file"}')),
      );
      
      // Launch URL (in a real app, this would open the file)
      final url = Uri.parse(message.fileUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (e) {
      print('Error opening file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthService>(context).currentUser;

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
              // Show chat info
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
                            final isMe = currentUser != null && message.senderId == currentUser.id;
                            
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
            const SizedBox(height: 2),
            Text(
              dateFormat.format(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white.withOpacity(0.8) : Colors.black54,
              ),
              textAlign: TextAlign.right,
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
          InkWell(
            onTap: () => _openFile(message),
            child: _buildFilePreview(message, isMe),
          ),
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