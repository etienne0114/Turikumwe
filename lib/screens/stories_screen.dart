
// lib/screens/stories_screen.dart
import 'package:flutter/material.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/story.dart';
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
      final stories = await DatabaseService().getStories(
        category: _selectedCategory == 'All' ? null : _selectedCategory,
      );
      
      setState(() {
        _stories = stories;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stories: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _stories.length,
                      itemBuilder: (context, index) {
                        return StoryCard(story: _stories[index]);
                      },
                    ),
        ),
      ],
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
            onPressed: () {
              // Navigate to create story
            },
            icon: const Icon(Icons.add),
            label: const Text('Share Your Story'),
          ),
        ],
      ),
    );
  }
}