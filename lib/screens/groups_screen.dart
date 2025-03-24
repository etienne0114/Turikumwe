// lib/screens/groups_screen.dart
import 'package:flutter/material.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/widgets/group_card.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Group> _myGroups = [];
  List<Group> _discoverGroups = [];
  bool _isLoading = true;

  final List<String> _categories = [
    'All',
    'Agriculture',
    'Business',
    'Education',
    'Environment',
    'Health',
    'Technology',
    'Youth',
  ];
  
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGroups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // In a real app, you would filter groups based on user membership
      final allGroups = await DatabaseService().getGroups();
      
      // For demo purposes, we'll just split them
      setState(() {
        _myGroups = allGroups.take(3).toList();
        _discoverGroups = allGroups.skip(3).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading groups: $e');
      setState(() {
        _isLoading = false;
      });
    }
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
            Tab(text: 'My Groups'),
            Tab(text: 'Discover'),
          ],
        ),
        if (_selectedCategory != 'All' || _tabController.index == 1)
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
                            // TODO: Filter groups by category
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // My Groups Tab
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _myGroups.isEmpty
                      ? _buildEmptyMyGroupsState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _myGroups.length,
                          itemBuilder: (context, index) {
                            return GroupCard(group: _myGroups[index]);
                          },
                        ),
              
              // Discover Tab
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _discoverGroups.isEmpty
                      ? _buildEmptyDiscoverState()
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _discoverGroups.length,
                          itemBuilder: (context, index) {
                            return GroupCard(
                              group: _discoverGroups[index],
                              isGridView: true,
                            );
                          },
                        ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyMyGroupsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.group_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'You haven\'t joined any groups yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Join groups to connect with people who share your interests',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _tabController.animateTo(1);
            },
            child: const Text('Discover Groups'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDiscoverState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No groups found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try changing your search filters or create a new group',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to create group
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Group'),
          ),
        ],
      ),
    );
  }
}