// lib/services/database_service.dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/models/post.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/models/story.dart';
import 'package:turikumwe/models/message.dart';
import 'package:turikumwe/models/notification.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }
  // Add this method to your DatabaseService class

// Method to completely reset database - USE WITH CAUTION
  Future<void> resetDatabase() async {
    try {
      // Close database if it's open
      if (_database != null && _database!.isOpen) {
        await _database!.close();
        _database = null;
      }

      // Delete the database file
      String path = join(await getDatabasesPath(), 'turikumwe.db');
      print("Deleting database at: $path");
      await deleteDatabase(path);

      // Reinitialize database
      await initDatabase();
      print("Database has been reset successfully");
    } catch (e) {
      print("Error resetting database: $e");
      rethrow;
    }
  }

  Future<Database> initDatabase() async {
    String path = join(await getDatabasesPath(), 'turikumwe.db');

    return await openDatabase(
      path,
      version: 4, // Increment from 3 to 4 to trigger upgrade
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _upgradeDatabase(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add missing columns
      await db.execute('ALTER TABLE events ADD COLUMN district TEXT');
      await db.execute('ALTER TABLE events ADD COLUMN category TEXT');
      await db.execute('ALTER TABLE events ADD COLUMN createdAt TEXT');
      await db.execute('ALTER TABLE events ADD COLUMN updatedAt TEXT');
    }
    if (oldVersion < 3) {
      // Add isPublic column to groups table
      await db
          .execute('ALTER TABLE groups ADD COLUMN isPublic INTEGER DEFAULT 1');
    }
    if (oldVersion < 4) {
      // Add file attachment columns to messages table
      await db.execute('ALTER TABLE messages ADD COLUMN fileUrl TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN fileType TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN fileName TEXT');
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        phoneNumber TEXT,
        district TEXT,
        profilePicture TEXT,
        bio TEXT,
        isAdmin INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Posts table
    await db.execute('''
      CREATE TABLE posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        groupId INTEGER,
        content TEXT NOT NULL,
        images TEXT,
        createdAt TEXT NOT NULL,
        likesCount INTEGER DEFAULT 0,
        commentsCount INTEGER DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES users (id),
        FOREIGN KEY (groupId) REFERENCES groups (id)
      )
    ''');

    // Comments table
    await db.execute('''
      CREATE TABLE comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        postId INTEGER NOT NULL,
        userId INTEGER NOT NULL,
        content TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (postId) REFERENCES posts (id),
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');

    // Groups table
    await db.execute('''
      CREATE TABLE groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        image TEXT,
        category TEXT NOT NULL,
        district TEXT,
        membersCount INTEGER DEFAULT 0,
        isPublic INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL
      )
    ''');

    // Group Members table
    await db.execute('''
      CREATE TABLE group_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        groupId INTEGER NOT NULL,
        userId INTEGER NOT NULL,
        isAdmin INTEGER DEFAULT 0,
        joinedAt TEXT NOT NULL,
        FOREIGN KEY (groupId) REFERENCES groups (id),
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');

    // Events table
    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        date TEXT NOT NULL,
        location TEXT NOT NULL,
        image TEXT,
        groupId INTEGER,
        organizerId INTEGER NOT NULL,
        attendeesIds TEXT,
        district TEXT,
        category TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (groupId) REFERENCES groups (id),
        FOREIGN KEY (organizerId) REFERENCES users (id)
      )
    ''');

    // Stories table
    await db.execute('''
      CREATE TABLE stories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        images TEXT,
        category TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        likesCount INTEGER DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');

    // Messages table
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        senderId INTEGER NOT NULL,
        receiverId INTEGER NOT NULL,
        groupId INTEGER,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        isRead INTEGER DEFAULT 0,
        fileUrl TEXT,
        fileType TEXT,
        fileName TEXT,
        FOREIGN KEY (senderId) REFERENCES users (id),
        FOREIGN KEY (receiverId) REFERENCES users (id),
        FOREIGN KEY (groupId) REFERENCES groups (id)
      )
    ''');

    // Notifications table
    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        type TEXT NOT NULL,
        relatedId INTEGER,
        timestamp TEXT NOT NULL,
        isRead INTEGER DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');
  }

  // User methods
  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user);
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.update(
      'users',
      user,
      where: 'id = ?',
      whereArgs: [user['id']],
    );
  }

  // Post methods
  Future<int> insertPost(Map<String, dynamic> post) async {
    final db = await database;
    return await db.insert('posts', post);
  }

  Future<List<Post>> getPosts({int? userId, int? groupId}) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (userId != null) {
      whereClause = 'userId = ?';
      whereArgs.add(userId);
    }

    if (groupId != null) {
      whereClause =
          whereClause.isEmpty ? 'groupId = ?' : '$whereClause AND groupId = ?';
      whereArgs.add(groupId);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'posts',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) {
      return Post.fromMap(maps[i]);
    });
  }

  //Get all groups a user is a member of
  Future<List<Group>> fetchUserGroups(int userId) async {
    final db = await database;

    // Join group_members with groups to get groups where user is a member
    final List<Map<String, dynamic>> results = await db.rawQuery('''
    SELECT g.*
    FROM groups g
    JOIN group_members gm ON g.id = gm.groupId
    WHERE gm.userId = ?
    ORDER BY g.name ASC
  ''', [userId]);

    return results.map((map) => Group.fromMap(map)).toList();
  }

// Get latest posts for feed with user details
  Future<List<Map<String, dynamic>>> getHomeFeeds() async {
    final db = await database;

    // Join posts with users to get user details
    final List<Map<String, dynamic>> results = await db.rawQuery('''
    SELECT p.*, u.name as userName, u.profilePicture,
           g.name as groupName, g.id as groupId
    FROM posts p
    LEFT JOIN users u ON p.userId = u.id
    LEFT JOIN groups g ON p.groupId = g.id
    ORDER BY p.createdAt DESC
    LIMIT 50
  ''');

    return results;
  }

// Get a specific post by ID with author and group details
  Future<Map<String, dynamic>?> getPostWithDetails(int postId) async {
    final db = await database;

    final List<Map<String, dynamic>> results = await db.rawQuery('''
    SELECT p.*, u.name as userName, u.profilePicture,
           g.name as groupName, g.id as groupId 
    FROM posts p
    LEFT JOIN users u ON p.userId = u.id
    LEFT JOIN groups g ON p.groupId = g.id
    WHERE p.id = ?
  ''', [postId]);

    if (results.isEmpty) {
      return null;
    }

    return results.first;
  }

  Future<int> insertGroup(Map<String, dynamic> group) async {
    final db = await database;

    final Map<String, dynamic> insertData = Map<String, dynamic>.from(group);

    if (insertData.containsKey('isPublic')) {
      try {
        await db.rawQuery('SELECT isPublic FROM groups LIMIT 1');
      } catch (e) {
        print("isPublic column doesn't exist yet, removing field from insert");
        insertData.remove('isPublic');
      }
    }

    return await db.insert('groups', insertData);
  }

  Future<List<Group>> getGroups({String? category, String? district}) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (category != null) {
      whereClause = 'category = ?';
      whereArgs.add(category);
    }

    if (district != null) {
      whereClause = whereClause.isEmpty
          ? 'district = ?'
          : '$whereClause AND district = ?';
      whereArgs.add(district);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'groups',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return Group.fromMap(maps[i]);
    });
  }

  // Get a specific group by ID
  Future<Group?> getGroupById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'groups',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Group.fromMap(maps.first);
    }
    return null;
  }

  // Update a group
  Future<bool> updateGroup(Map<String, dynamic> group) async {
    final db = await database;
    final result = await db.update(
      'groups',
      group,
      where: 'id = ?',
      whereArgs: [group['id']],
    );

    return result > 0;
  }

  // Delete a group
  Future<bool> deleteGroup(int id) async {
    final db = await database;

    // Start transaction to delete all related data
    await db.transaction((txn) async {
      // Delete group members
      await txn.delete(
        'group_members',
        where: 'groupId = ?',
        whereArgs: [id],
      );

      // Delete group posts
      await txn.delete(
        'posts',
        where: 'groupId = ?',
        whereArgs: [id],
      );

      // Delete group messages
      await txn.delete(
        'messages',
        where: 'groupId = ?',
        whereArgs: [id],
      );

      // Delete group events
      await txn.delete(
        'events',
        where: 'groupId = ?',
        whereArgs: [id],
      );

      // Finally delete the group itself
      await txn.delete(
        'groups',
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    return true;
  }

  // Add a member to a group
  Future<int> addGroupMember(Map<String, dynamic> member) async {
    final db = await database;
    return await db.insert('group_members', member);
  }

  // Get all members of a group
  Future<List<Map<String, dynamic>>> getGroupMembers(int groupId) async {
    final db = await database;

    // Join group_members with users to get user details
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT gm.*, u.*
      FROM group_members gm
      JOIN users u ON gm.userId = u.id
      WHERE gm.groupId = ?
      ORDER BY gm.isAdmin DESC, u.name ASC
    ''', [groupId]);

    // Convert to more usable format with User objects
    return results.map((row) {
      final user = User.fromMap({
        'id': row['userId'],
        'name': row['name'],
        'email': row['email'],
        'phoneNumber': row['phoneNumber'],
        'district': row['district'],
        'profilePicture': row['profilePicture'],
        'bio': row['bio'],
        'createdAt': row['createdAt'],
        'updatedAt': row['updatedAt'],
      });

      return {
        'id': row['id'],
        'groupId': row['groupId'],
        'userId': row['userId'],
        'isAdmin': row['isAdmin'],
        'joinedAt': row['joinedAt'],
        'user': user,
      };
    }).toList();
  }

  // Check if a user is a member of a group
  Future<Map<String, dynamic>?> getGroupMembership(
      int groupId, int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'group_members',
      where: 'groupId = ? AND userId = ?',
      whereArgs: [groupId, userId],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Remove a member from a group
  Future<int> removeGroupMember(int groupId, int userId) async {
    final db = await database;
    return await db.delete(
      'group_members',
      where: 'groupId = ? AND userId = ?',
      whereArgs: [groupId, userId],
    );
  }

  // Update a member's role in a group
  Future<int> updateGroupMemberRole(
      int groupId, int userId, bool isAdmin) async {
    final db = await database;
    return await db.update(
      'group_members',
      {'isAdmin': isAdmin ? 1 : 0},
      where: 'groupId = ? AND userId = ?',
      whereArgs: [groupId, userId],
    );
  }

  // Increment group members count
  Future<Group?> incrementGroupMembersCount(int groupId) async {
    final db = await database;

    // Get current group
    final group = await getGroupById(groupId);
    if (group == null) return null;

    // Increment members count
    final newCount = group.membersCount + 1;
    await db.update(
      'groups',
      {'membersCount': newCount},
      where: 'id = ?',
      whereArgs: [groupId],
    );

    // Return updated group
    return await getGroupById(groupId);
  }

  // Decrement group members count
  Future<Group?> decrementGroupMembersCount(int groupId) async {
    final db = await database;

    // Get current group
    final group = await getGroupById(groupId);
    if (group == null) return null;

    // Ensure count doesn't go below 0
    final newCount = group.membersCount > 0 ? group.membersCount - 1 : 0;
    await db.update(
      'groups',
      {'membersCount': newCount},
      where: 'id = ?',
      whereArgs: [groupId],
    );

    // Return updated group
    return await getGroupById(groupId);
  }

  // Get user's groups
  Future<List<Group>> getUserGroups(int userId) async {
    final db = await database;

    // Join group_members with groups to get groups where user is a member
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT g.*
      FROM groups g
      JOIN group_members gm ON g.id = gm.groupId
      WHERE gm.userId = ?
      ORDER BY g.name ASC
    ''', [userId]);

    return results.map((map) => Group.fromMap(map)).toList();
  }

  // Get groups where user is admin
  Future<List<Group>> getUserAdminGroups(int userId) async {
    final db = await database;

    // Join group_members with groups to get groups where user is admin
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT g.*
      FROM groups g
      JOIN group_members gm ON g.id = gm.groupId
      WHERE gm.userId = ? AND gm.isAdmin = 1
      ORDER BY g.name ASC
    ''', [userId]);

    return results.map((map) => Group.fromMap(map)).toList();
  }

  // Search groups by name or description
  Future<List<Group>> searchGroups(String query) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'groups',
      where: 'name LIKE ? OR description LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return Group.fromMap(maps[i]);
    });
  }

  Future<void> likePost(int postId, int userId) async {
    final db = await database;

    // Start a transaction
    await db.transaction((txn) async {
      // Check if there's a likes table, create if it doesn't exist
      // Fix the SQL syntax by removing extra parentheses
      await txn.execute('''
      CREATE TABLE IF NOT EXISTS post_likes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        postId INTEGER NOT NULL,
        userId INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (postId) REFERENCES posts (id),
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');

      // Add like record
      await txn.insert('post_likes', {
        'postId': postId,
        'userId': userId,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Increment likes count
      await txn.rawUpdate(
        'UPDATE posts SET likesCount = likesCount + 1 WHERE id = ?',
        [postId],
      );
    });
  }

  // Event methods
  Future<int> insertEvent(Map<String, dynamic> event) async {
    final db = await database;

    // Add creation timestamps if not provided
    if (!event.containsKey('createdAt')) {
      event['createdAt'] = DateTime.now().toIso8601String();
    }
    if (!event.containsKey('updatedAt')) {
      event['updatedAt'] = DateTime.now().toIso8601String();
    }

    return await db.insert('events', event);
  }

  Future<List<Event>> getEvents({
    int? groupId,
    DateTime? fromDate,
    String? district,
    String? category,
    int? organizerId,
    bool upcoming = true,
  }) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (groupId != null) {
      whereClause = 'groupId = ?';
      whereArgs.add(groupId);
    }

    if (fromDate != null && upcoming) {
      final dateStr = fromDate.toIso8601String();
      whereClause =
          whereClause.isEmpty ? 'date >= ?' : '$whereClause AND date >= ?';
      whereArgs.add(dateStr);
    } else if (fromDate != null && !upcoming) {
      final dateStr = fromDate.toIso8601String();
      whereClause =
          whereClause.isEmpty ? 'date < ?' : '$whereClause AND date < ?';
      whereArgs.add(dateStr);
    }

    if (district != null) {
      whereClause = whereClause.isEmpty
          ? 'district = ?'
          : '$whereClause AND district = ?';
      whereArgs.add(district);
    }

    if (category != null) {
      whereClause = whereClause.isEmpty
          ? 'category = ?'
          : '$whereClause AND category = ?';
      whereArgs.add(category);
    }

    if (organizerId != null) {
      whereClause = whereClause.isEmpty
          ? 'organizerId = ?'
          : '$whereClause AND organizerId = ?';
      whereArgs.add(organizerId);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: upcoming ? 'date ASC' : 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return Event.fromMap(maps[i]);
    });
  }

  // Get a specific event by ID
  Future<Event?> getEventById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Event.fromMap(maps.first);
    }
    return null;
  }

  // Update an event
  Future<int> updateEvent(Map<String, dynamic> event) async {
    final db = await database;

    // Add update timestamp
    event['updatedAt'] = DateTime.now().toIso8601String();

    return await db.update(
      'events',
      event,
      where: 'id = ?',
      whereArgs: [event['id']],
    );
  }

  // Delete an event
  Future<int> deleteEvent(int id) async {
    final db = await database;
    return await db.delete(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get events a user is attending
  Future<List<Event>> getEventsUserIsAttending(int userId) async {
    final db = await database;

    // This query searches for the userId in the attendeesIds field
    // It's a bit complex as we need to search in a comma-separated list
    final List<Map<String, dynamic>> maps = await db.rawQuery(
        "SELECT * FROM events WHERE attendeesIds LIKE ? OR attendeesIds LIKE ? OR attendeesIds LIKE ? OR attendeesIds = ? ORDER BY date ASC",
        [
          "%,$userId,%", // Middle attendee
          "$userId,%", // First attendee
          "%,$userId", // Last attendee
          "$userId" // Only attendee
        ]);

    return List.generate(maps.length, (i) {
      return Event.fromMap(maps[i]);
    });
  }

  // Get popular events (most attendees)
  Future<List<Event>> getPopularEvents(
      {int limit = 10, DateTime? fromDate}) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (fromDate != null) {
      whereClause = 'date >= ?';
      whereArgs.add(fromDate.toIso8601String());
    }

    // Custom function to count commas in attendeesIds + 1 (for number of attendees)
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT *, 
      CASE 
        WHEN attendeesIds IS NULL THEN 0
        WHEN attendeesIds = '' THEN 0
        ELSE (LENGTH(attendeesIds) - LENGTH(REPLACE(attendeesIds, ',', '')) + 1) 
      END AS attendee_count
      FROM events
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
      ORDER BY attendee_count DESC, date ASC
      LIMIT ?
      ''', [...whereArgs, limit]);

    return List.generate(maps.length, (i) {
      return Event.fromMap(maps[i]);
    });
  }

  // Get events happening today
  Future<List<Event>> getTodayEvents({String? district}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final db = await database;

    String whereClause = 'date >= ? AND date < ?';
    List<dynamic> whereArgs = [
      today.toIso8601String(),
      tomorrow.toIso8601String()
    ];

    if (district != null) {
      whereClause += ' AND district = ?';
      whereArgs.add(district);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date ASC',
    );

    return List.generate(maps.length, (i) {
      return Event.fromMap(maps[i]);
    });
  }

  // Get events for the current week
  Future<List<Event>> getWeekEvents({String? district}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Calculate start of week (Sunday) and end of week (Saturday)
    final daysToStartOfWeek = now.weekday % 7; // 0 = Sunday, 1 = Monday, etc.
    final startOfWeek = today.subtract(Duration(days: daysToStartOfWeek));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final db = await database;

    String whereClause = 'date >= ? AND date < ?';
    List<dynamic> whereArgs = [
      startOfWeek.toIso8601String(),
      endOfWeek.toIso8601String()
    ];

    if (district != null) {
      whereClause += ' AND district = ?';
      whereArgs.add(district);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date ASC',
    );

    return List.generate(maps.length, (i) {
      return Event.fromMap(maps[i]);
    });
  }

  // Check if a user is attending an event
  Future<bool> isUserAttendingEvent(int userId, int eventId) async {
    final event = await getEventById(eventId);
    if (event == null ||
        event.attendeesIds == null ||
        event.attendeesIds!.isEmpty) {
      return false;
    }

    // Check if userId exists in the comma-separated string
    final String attendeesString = event.attendeesIds!;
    final List<String> attendeesStrList = attendeesString.split(',');
    final List<int> attendeesList =
        attendeesStrList.map((id) => int.parse(id.trim())).toList();

    return attendeesList.contains(userId);
  }

  // Add a user to event attendees
  Future<bool> addUserToEventAttendees(int userId, int eventId) async {
    final event = await getEventById(eventId);
    if (event == null) {
      return false;
    }

    List<int> attendeesList = [];
    if (event.attendeesIds != null && event.attendeesIds!.isNotEmpty) {
      final List<String> attendeesStrList = event.attendeesIds!.split(',');
      attendeesList =
          attendeesStrList.map((id) => int.parse(id.trim())).toList();
    }

    if (!attendeesList.contains(userId)) {
      attendeesList.add(userId);

      final result = await updateEvent({
        'id': eventId,
        'attendeesIds': attendeesList.join(','),
      });

      return result > 0;
    }

    return true; // User already attending
  }

  // Remove a user from event attendees
  Future<bool> removeUserFromEventAttendees(int userId, int eventId) async {
    final event = await getEventById(eventId);
    if (event == null ||
        event.attendeesIds == null ||
        event.attendeesIds!.isEmpty) {
      return false;
    }

    final List<String> attendeesStrList = event.attendeesIds!.split(',');
    final List<int> attendeesList =
        attendeesStrList.map((id) => int.parse(id.trim())).toList();

    if (attendeesList.contains(userId)) {
      attendeesList.remove(userId);

      final result = await updateEvent({
        'id': eventId,
        'attendeesIds': attendeesList.isEmpty ? '' : attendeesList.join(','),
      });

      return result > 0;
    }

    return true; // User wasn't attending
  }

  // Story methods
  Future<int> insertStory(Map<String, dynamic> story) async {
    final db = await database;
    return await db.insert('stories', story);
  }

  Future<List<Story>> getStories({String? category}) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'stories',
      where: category != null ? 'category = ?' : null,
      whereArgs: category != null ? [category] : null,
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) {
      return Story.fromMap(maps[i]);
    });
  }

  // Message methods
  Future<int> insertMessage(Map<String, dynamic> message) async {
    final db = await database;
    return await db.insert('messages', message);
  }

  Future<List<Message>> getMessages(
      {int? senderId, int? receiverId, int? groupId}) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (senderId != null && receiverId != null) {
      // Direct messages between two users
      whereClause =
          '(senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)';
      whereArgs.add(senderId);
      whereArgs.add(receiverId);
      whereArgs.add(receiverId);
      whereArgs.add(senderId);
    } else if (groupId != null) {
      // Group messages
      whereClause = 'groupId = ?';
      whereArgs.add(groupId);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return Message.fromMap(maps[i]);
    });
  }
  
  // Mark message as read
  Future<int> markMessageAsRead(int messageId) async {
    final db = await database;
    return await db.update(
      'messages',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // Mark all messages in a conversation as read
  Future<int> markAllMessagesAsRead({int? senderId, int? receiverId, int? groupId}) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (senderId != null && receiverId != null) {
      // Direct messages between two users, where the current user is the receiver
      whereClause = 'senderId = ? AND receiverId = ? AND isRead = 0';
      whereArgs.add(senderId);
      whereArgs.add(receiverId);
    } else if (groupId != null) {
      // Group messages where current user is not the sender
      whereClause = 'groupId = ? AND receiverId = ? AND isRead = 0';
      whereArgs.add(groupId);
      whereArgs.add(receiverId); // receiverId here would be the current user ID
    }

    return await db.update(
      'messages',
      {'isRead': 1},
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );
  }
  
  // Get unread messages count
  Future<int> getUnreadMessagesCount(int userId) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM messages
      WHERE receiverId = ? AND isRead = 0
    ''', [userId]);
    
    return Sqflite.firstIntValue(result) ?? 0;
  }
  
  // Store file attachments with messages
  Future<int> storeFileAttachment(Map<String, dynamic> message) async {
    // This function is similar to insertMessage but ensures file fields are present
    final db = await database;
    
    // Make sure timestamp is in proper format
    if (message['timestamp'] is DateTime) {
      message['timestamp'] = message['timestamp'].toIso8601String();
    }
    
    return await db.insert('messages', message);
  }
  
  // Get chat conversations list
  Future<List<Map<String, dynamic>>> getChatConversations(int userId) async {
    final db = await database;
    
    // This query gets the most recent message for each conversation
    // and counts unread messages
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 
        m.groupId,
        CASE 
          WHEN m.groupId IS NULL THEN 
            CASE 
              WHEN m.senderId = ? THEN m.receiverId 
              ELSE m.senderId 
            END
          ELSE NULL
        END as otherUserId,
        MAX(m.timestamp) as lastMessageTime,
        (SELECT content FROM messages WHERE 
          ((senderId = ? AND receiverId = otherUserId) OR 
           (senderId = otherUserId AND receiverId = ?)) OR
          (groupId = m.groupId)
          ORDER BY timestamp DESC LIMIT 1) as lastMessage,
        (SELECT COUNT(*) FROM messages WHERE 
          ((senderId = otherUserId AND receiverId = ? AND isRead = 0) OR
           (groupId = m.groupId AND receiverId = ? AND isRead = 0))) 
          as unreadCount,
        CASE 
          WHEN m.groupId IS NULL THEN 
            (SELECT name FROM users WHERE id = otherUserId)
          ELSE
            (SELECT name FROM groups WHERE id = m.groupId)
        END as name,
        CASE
          WHEN m.groupId IS NULL THEN 0
          ELSE 1
        END as isGroup
      FROM messages m
      WHERE 
        m.senderId = ? OR m.receiverId = ? OR 
        m.groupId IN (SELECT groupId FROM group_members WHERE userId = ?)
      GROUP BY 
        CASE 
          WHEN m.groupId IS NULL THEN 
            CASE WHEN m.senderId = ? THEN m.receiverId ELSE m.senderId END
          ELSE m.groupId
        END
      ORDER BY lastMessageTime DESC
    ''', [
      userId, // For determining otherUserId
      userId, userId, // For getting the last message
      userId, userId, // For counting unread messages
      userId, userId, userId, // For filtering messages related to the user
      userId // For grouping
    ]);
    
    return results;
  }

  // Notification methods
  Future<int> insertNotification(Map<String, dynamic> notification) async {
    final db = await database;
    return await db.insert('notifications', notification);
  }

  Future<List<Notification>> getNotifications(int userId,
      {bool? isRead}) async {
    final db = await database;

    String whereClause = 'userId = ?';
    List<dynamic> whereArgs = [userId];

    if (isRead != null) {
      whereClause = '$whereClause AND isRead = ?';
      whereArgs.add(isRead ? 1 : 0);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'notifications',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return Notification.fromMap(maps[i]);
    });
  }

  Future<int> markNotificationAsRead(int id) async {
    final db = await database;
    return await db.update(
      'notifications',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}