// lib/screens/stories_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/story.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/screens/create_story_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/widgets/story_card.dart';

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({Key? key}) : super(key: key);

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  List<Story> _stories = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  
  final List<String> _categories = [
    'All',
    'Success',
    'Innovation',
    'Community',
    'Education',
    'Health',
    'Agriculture',
  ];

  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stories = await _databaseService.getStories(
        category: _selectedCategory == 'All' ? null : _selectedCategory,
      );
      
      // Enhance stories with author information if needed
      List<Story> enhancedStories = [];
      for (var story in stories) {
        final author = await _databaseService.getUserById(story.userId);
        if (author != null) {
          // Create a new Story with author info
          final enhancedStory = Story(
            id: story.id,
            userId: story.userId,
            title: story.title,
            content: story.content,
            category: story.category,
            createdAt: story.createdAt,
            likesCount: story.likesCount,
            images: story.images,
          );
          enhancedStories.add(enhancedStory);
        } else {
          enhancedStories.add(story);
        }
      }
      
      setState(() {
        _stories = enhancedStories;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stories: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createStory() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (!authService.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to share stories')),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateStoryScreen(),
      ),
    );

    if (result == true) {
      // Reload stories if a new one was created
      _loadStories();
    }
  }

  Future<void> _deleteStory(Story story) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story'),
        content: const Text('Are you sure you want to delete this story? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final result = await _databaseService.deleteStory(story.id);
      
      if (result > 0) {
        // Reload stories
        _loadStories();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story deleted successfully')),
        );
      } else {
        throw Exception('Failed to delete story');
      }
    } catch (e) {
      print('Error deleting story: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _editStory(Story story) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateStoryScreen(storyToEdit: story),
      ),
    );

    if (result == true) {
      // Reload stories if updated
      _loadStories();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      body: Column(
        children: [
          // Category filter
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = category;
                            // Reload stories with the new filter
                            _loadStories();
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Stories list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _stories.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadStories,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _stories.length,
                          itemBuilder: (context, index) {
                            final Story story = _stories[index];
                            final User? currentUser = authService.currentUser;
                            final bool isOwner = currentUser != null && currentUser.id == story.userId;
                            
                            return StoryCard(
                              story: story,
                              onDelete: isOwner ? () => _deleteStory(story) : null,
                              onEdit: isOwner ? () => _editStory(story) : null,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createStory,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.auto_stories_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No stories yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Share your success stories to inspire others',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _createStory,
            icon: const Icon(Icons.add),
            label: const Text('Share Your Story'),
          ),
        ],
      ),
    );
  }
}