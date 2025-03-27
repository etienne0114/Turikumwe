// lib/screens/groups/groups_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/screens/groups/create_group_screen.dart';
import 'package:turikumwe/screens/groups/group_detail_screen.dart';
import 'package:turikumwe/screens/groups/group_home_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/utils/dialog_utils.dart';

class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({Key? key}) : super(key: key);

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Group> _allGroups = [];
  List<Group> _myGroups = [];
  List<Group> _filteredGroups = [];
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedDistrict;

  final List<String> _categories = [
    'All Categories',
    'Community',
    'Education',
    'Health',
    'Business',
    'Technology',
    'Environment',
    'Arts & Culture',
    'Sports',
    'Religion',
    'Other'
  ];

  final List<String> _rwandanDistricts = [
    'All Districts',
    'Bugesera', 'Burera', 'Gakenke', 'Gasabo', 'Gatsibo', 'Gicumbi',
    'Gisagara', 'Huye', 'Kamonyi', 'Karongi', 'Kayonza', 'Kicukiro',
    'Kirehe', 'Muhanga', 'Musanze', 'Ngoma', 'Ngororero', 'Nyabihu',
    'Nyagatare', 'Nyamagabe', 'Nyamasheke', 'Nyanza', 'Nyarugenge',
    'Nyaruguru', 'Rubavu', 'Ruhango', 'Rulindo', 'Rusizi', 'Rutsiro',
    'Rwamagana',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadGroups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _searchQuery = '';
        _selectedCategory = null;
        _selectedDistrict = null;
        _applyFilters();
      });
    }
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);

    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      
      List<Group> allGroups = await databaseService.getGroups();
      List<Group> myGroups = [];
      
      if (authService.currentUser != null) {
        myGroups = await databaseService.getUserGroups(authService.currentUser!.id);
      }

      if (mounted) {
        setState(() {
          _allGroups = allGroups;
          _myGroups = myGroups;
          _filteredGroups = _tabController.index == 0 ? allGroups : myGroups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Failed to load groups: ${e.toString()}',
        );
      }
    }
  }

  void _applyFilters() {
    List<Group> baseList = _tabController.index == 0 ? _allGroups : _myGroups;
    
    setState(() {
      _filteredGroups = baseList.where((group) {
        bool matchesSearch = _searchQuery.isEmpty || 
            group.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            group.description.toLowerCase().contains(_searchQuery.toLowerCase());
        
        bool matchesCategory = _selectedCategory == null || 
            _selectedCategory == 'All Categories' || 
            group.category == _selectedCategory;
        
        bool matchesDistrict = _selectedDistrict == null || 
            _selectedDistrict == 'All Districts' || 
            group.district == _selectedDistrict;
        
        return matchesSearch && matchesCategory && matchesDistrict;
      }).toList();
    });
  }

  void _navigateToGroupScreen(Group group) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    
    if (authService.currentUser == null) {
      // Navigate to group detail screen if not logged in
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GroupDetailScreen(group: group)),
      );
      return;
    }
    
    // Check if user is a member
    final membership = await databaseService.getGroupMembership(
      group.id, 
      authService.currentUser!.id,
    );
    
    if (membership != null) {
      // If member, navigate to group home screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GroupHomeScreen(group: group)),
      ).then((_) => _loadGroups());
    } else {
      // If not member, navigate to group detail screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GroupDetailScreen(group: group)),
      ).then((_) => _loadGroups());
    }
  }

  void _navigateToCreateGroup() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
    );
    
    if (result == true) {
      _loadGroups();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Groups'),
            Tab(text: 'My Groups'),
          ],
          indicatorColor: Colors.white,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search groups...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _applyFilters();
                      });
                    },
                  ),
                ),
                
                // Filters
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedCategory,
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value;
                              _applyFilters();
                            });
                          },
                          hint: const Text('All Categories'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'District',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedDistrict,
                          items: _rwandanDistricts.map((district) {
                            return DropdownMenuItem(
                              value: district,
                              child: Text(district),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDistrict = value;
                              _applyFilters();
                            });
                          },
                          hint: const Text('All Districts'),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // List of groups
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // All Groups Tab
                      _buildGroupsList(_filteredGroups),
                      
                      // My Groups Tab
                      _myGroups.isEmpty && _searchQuery.isEmpty && _selectedCategory == null && _selectedDistrict == null
                          ? _buildEmptyMyGroups()
                          : _buildGroupsList(_filteredGroups),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateGroup,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGroupsList(List<Group> groups) {
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No groups found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different filters or create a new group',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final isMember = _myGroups.any((g) => g.id == group.id);
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _navigateToGroupScreen(group),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group image
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      image: group.image != null
                          ? DecorationImage(
                              image: NetworkImage(group.image!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: group.image == null
                        ? const Center(
                            child: Icon(
                              Icons.group,
                              size: 30,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  
                  // Group details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isMember)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Member',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        // Group category and privacy
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                group.category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              group.isPublic ? Icons.public : Icons.lock,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              group.isPublic ? 'Public' : 'Private',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        // Group description (truncated)
                        Text(
                          group.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Group location and members count
                        Row(
                          children: [
                            if (group.district != null) ...[
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                group.district!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            Icon(
                              Icons.people,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${group.membersCount} member${group.membersCount != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyMyGroups() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'You haven\'t joined any groups yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join existing groups or create your own',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToCreateGroup,
            icon: const Icon(Icons.add),
            label: const Text('Create Group'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}