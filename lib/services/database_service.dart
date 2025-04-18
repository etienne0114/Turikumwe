// lib/services/database_service.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/models/post.dart';
import 'package:turikumwe/models/group.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/models/story.dart';
import 'package:turikumwe/models/message.dart';
import 'package:turikumwe/models/notification.dart' as custom_notification;
import 'package:turikumwe/models/event_analytics.dart';

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
      version: 5, // Increment to 5 to trigger upgrade
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
      await db.execute(
          'ALTER TABLE events ADD COLUMN hasQuestionnaire INTEGER DEFAULT 0');
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
    if (oldVersion < 5) {
      // Add the missing columns to events table
      try {
        await db.execute(
            'ALTER TABLE events ADD COLUMN isPrivate INTEGER DEFAULT 0');
        print("Added isPrivate column to events table");
      } catch (e) {
        print("Error adding isPrivate column: $e");
        // Column might already exist
      }

      try {
        await db.execute('ALTER TABLE events ADD COLUMN price REAL');
        print("Added price column to events table");
      } catch (e) {
        print("Error adding price column: $e");
        // Column might already exist
      }

      try {
        await db.execute('ALTER TABLE events ADD COLUMN paymentMethod TEXT');
        print("Added paymentMethod column to events table");
      } catch (e) {
        print("Error adding paymentMethod column: $e");
        // Column might already exist
      }

      // Create event_analytics table
      try {
        await db.execute('''
          CREATE TABLE event_analytics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            eventId INTEGER NOT NULL,
            viewCount INTEGER DEFAULT 0,
            shareCount INTEGER DEFAULT 0,
            clickCount INTEGER DEFAULT 0,
            lastUpdated TEXT NOT NULL,
            FOREIGN KEY (eventId) REFERENCES events (id)
          )
        ''');
        print("Created event_analytics table");
      } catch (e) {
        print("Error creating event_analytics table: $e");
        // Table might already exist
      }
    }
    if (oldVersion < 6) {
      // Add questionnaire columns to events table
      try {
        await db.execute(
            'ALTER TABLE events ADD COLUMN hasQuestionnaire INTEGER DEFAULT 0');
        await db
            .execute('ALTER TABLE events ADD COLUMN questionnaireData TEXT');
        print("Added questionnaire columns to events table");
      } catch (e) {
        print("Error adding questionnaire columns: $e");
      }

      // Create attendee_registrations table for tracking payments and questionnaire responses
      try {
        await db.execute('''
      CREATE TABLE attendee_registrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER NOT NULL,
        userId INTEGER NOT NULL,
        paymentStatus TEXT,
        paymentReference TEXT,
        paymentAmount REAL,
        paymentDate TEXT,
        questionnaireResponses TEXT,
        registrationDate TEXT NOT NULL,
        FOREIGN KEY (eventId) REFERENCES events (id),
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');
        print("Created attendee_registrations table");
      } catch (e) {
        print("Error creating attendee_registrations table: $e");
      }
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

    // Events table - updated with new columns
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
    district TEXT,
    category TEXT,
    createdAt TEXT,
    updatedAt TEXT,
    isPrivate INTEGER DEFAULT 0,
    price REAL,
    paymentMethod TEXT,
    hasQuestionnaire INTEGER DEFAULT 0,  // Make sure this column exists
    questionnaireData TEXT
  )
    ''');

    // Event Analytics table
    await db.execute('''
      CREATE TABLE event_analytics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER NOT NULL,
        viewCount INTEGER DEFAULT 0,
        shareCount INTEGER DEFAULT 0,
        clickCount INTEGER DEFAULT 0,
        lastUpdated TEXT NOT NULL,
        FOREIGN KEY (eventId) REFERENCES events (id)
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
  Future<int> addPost(Map<String, dynamic> post) async {
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
  Future<List<Map<String, dynamic>>> fetchHomeFeeds() async {
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

  Future<int> addGroupMember(Map<String, dynamic> member) async {
    final db = await database;
    return await db.insert('group_members', member);
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(int groupId) async {
    final db = await database;

    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT gm.*, u.*
      FROM group_members gm
      JOIN users u ON gm.userId = u.id
      WHERE gm.groupId = ?
      ORDER BY gm.isAdmin DESC, u.name ASC
    ''', [groupId]);

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

    final newCount = group.membersCount + 1;
    await db.update(
      'groups',
      {'membersCount': newCount},
      where: 'id = ?',
      whereArgs: [groupId],
    );

    return await getGroupById(groupId);
  }

  Future<Group?> decrementGroupMembersCount(int groupId) async {
    final db = await database;

    final group = await getGroupById(groupId);
    if (group == null) return null;

    final newCount = group.membersCount > 0 ? group.membersCount - 1 : 0;
    await db.update(
      'groups',
      {'membersCount': newCount},
      where: 'id = ?',
      whereArgs: [groupId],
    );

    return await getGroupById(groupId);
  }

  Future<List<Group>> getUserGroups(int userId) async {
    final db = await database;

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

    await db.transaction((txn) async {
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

  // Event methods - updated to handle schema changes
  Future<int> insertEvent(Map<String, dynamic> event) async {
    final db = await database;

    // Add creation timestamps if not provided
    if (!event.containsKey('createdAt')) {
      event['createdAt'] = DateTime.now().toIso8601String();
    }
    if (!event.containsKey('updatedAt')) {
      event['updatedAt'] = DateTime.now().toIso8601String();
    }

    // Check and update the database schema if needed
    await _ensureEventSchemaUpdated(db);

    // Convert boolean isPrivate to integer (SQLite doesn't have boolean type)
    if (event.containsKey('isPrivate') && event['isPrivate'] is bool) {
      event['isPrivate'] = event['isPrivate'] ? 1 : 0;
    }

    return await db.insert('events', event);
  }

  Future<void> _ensureEventSchemaUpdated(Database db) async {
    try {
      await db.rawQuery('SELECT hasQuestionnaire FROM events LIMIT 1');
      print('hasQuestionnaire column already exists');
    } catch (e) {
      try {
        await db.execute(
            'ALTER TABLE events ADD COLUMN hasQuestionnaire INTEGER DEFAULT 0');
        print('Added hasQuestionnaire column to events table');
      } catch (alterError) {
        print('Error adding hasQuestionnaire column: $alterError');
      }
    }

    try {
      await db.rawQuery('SELECT isPrivate FROM events LIMIT 1');
      print('isPrivate column already exists');
    } catch (e) {
      try {
        await db.execute(
            'ALTER TABLE events ADD COLUMN isPrivate INTEGER DEFAULT 0');
        print('Added isPrivate column to events table');
      } catch (alterError) {
        print('Error adding isPrivate column: $alterError');
      }
    }

    try {
      await db.rawQuery('SELECT price FROM events LIMIT 1');
      print('price column already exists');
    } catch (e) {
      try {
        await db.execute('ALTER TABLE events ADD COLUMN price REAL');
        print('Added price column to events table');
      } catch (alterError) {
        print('Error adding price column: $alterError');
      }
    }

    try {
      await db.rawQuery('SELECT paymentMethod FROM events LIMIT 1');
      print('paymentMethod column already exists');
    } catch (e) {
      try {
        await db.execute('ALTER TABLE events ADD COLUMN paymentMethod TEXT');
        print('Added paymentMethod column to events table');
      } catch (alterError) {
        print('Error adding paymentMethod column: $alterError');
      }
    }

    // Check for questionnaireData column
    try {
      await db.rawQuery('SELECT questionnaireData FROM events LIMIT 1');
      print('questionnaireData column already exists');
    } catch (e) {
      try {
        await db
            .execute('ALTER TABLE events ADD COLUMN questionnaireData TEXT');
        print('Added questionnaireData column to events table');
      } catch (alterError) {
        print('Error adding questionnaireData column: $alterError');
      }
    }
  }

  // Safe method to insert event - includes schema checking
  Future<int> safeInsertEventWithSchemaCheck(Map<String, dynamic> event) async {
    try {
      return await insertEvent(event);
    } catch (e) {
      print('Error inserting event: $e');
      // Check if the error is related to missing columns
      if (e.toString().contains('no column named')) {
        print('Attempting to fix database schema...');
        final db = await database;
        await _ensureEventSchemaUpdated(db);
        // Try again
        return await insertEvent(event);
      } else {
        rethrow;
      }
    }
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
    try {
      final db = await database;

      // Create a copy to avoid modifying the original map
      final Map<String, dynamic> sanitizedEvent = Map.from(event);

      // Add update timestamp
      sanitizedEvent['updatedAt'] = DateTime.now().toIso8601String();

      // Ensure questionnaireData is properly formatted as a string
      if (sanitizedEvent.containsKey('questionnaireData')) {
        final questionnaireData = sanitizedEvent['questionnaireData'];
        if (questionnaireData != null) {
          // If it's already a string, validate it's proper JSON
          if (questionnaireData is String) {
            try {
              jsonDecode(questionnaireData);
            } catch (e) {
              debugPrint('Invalid JSON in questionnaireData: $e');
              // If invalid, set to null to avoid database errors
              sanitizedEvent['questionnaireData'] = null;
            }
          }
          // If it's a Map or other object, convert to JSON string
          else {
            try {
              sanitizedEvent['questionnaireData'] =
                  jsonEncode(questionnaireData);
            } catch (e) {
              debugPrint('Error encoding questionnaireData: $e');
              sanitizedEvent['questionnaireData'] = null;
            }
          }
        }
      }

      // Convert boolean fields to integers for SQLite
      for (final key in ['isPrivate', 'hasQuestionnaire']) {
        if (sanitizedEvent.containsKey(key)) {
          final value = sanitizedEvent[key];
          if (value is bool) {
            sanitizedEvent[key] = value ? 1 : 0;
          }
        }
      }

      return await db.update(
        'events',
        sanitizedEvent,
        where: 'id = ?',
        whereArgs: [sanitizedEvent['id']],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error in updateEvent: $e');
      return 0; // Return 0 to indicate failure
    }
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

  Future<List<Event>> getEventsUserIsAttending(int userId) async {
    try {
      final db = await database;

      // Get all registrations for this user
      final registrations = await db.query(
        'event_registrations',
        where: 'userId = ?',
        whereArgs: [userId],
      );

      // If no registrations, return empty list
      if (registrations.isEmpty) {
        return [];
      }

      // Get event IDs from registrations
      final eventIds =
          registrations.map((reg) => reg['eventId'] as int).toSet().toList();

      // Get events for these IDs
      final events = <Event>[];
      for (final eventId in eventIds) {
        final event = await getEventById(eventId);
        if (event != null) {
          events.add(event);
        }
      }

      // Sort events by date
      events.sort((a, b) => a.date.compareTo(b.date));

      return events;
    } catch (e) {
      debugPrint('Error getting events user is attending: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserEventRegistrations(
      int userId) async {
    try {
      final db = await database;

      // Get all registrations for this user
      final registrations = await db.query(
        'event_registrations',
        where: 'userId = ?',
        whereArgs: [userId],
      );

      // Enhance with event details
      List<Map<String, dynamic>> enhancedRegistrations = [];

      for (final reg in registrations) {
        final eventId = reg['eventId'] as int;
        final event = await getEventById(eventId);

        if (event != null) {
          enhancedRegistrations.add({
            ...Map<String, dynamic>.from(reg),
            'event': event,
          });
        }
      }

      return enhancedRegistrations;
    } catch (e) {
      debugPrint('Error getting user event registrations: $e');
      return [];
    }
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

  Future<bool> addUserToEventAttendees(int userId, int eventId) async {
    try {
      final db = await database;

      // Get the current event
      final events = await db.query(
        'events',
        where: 'id = ?',
        whereArgs: [eventId],
      );

      if (events.isEmpty) {
        return false;
      }

      final event = events.first;
      String attendeesIds = event['attendeesIds'] as String? ?? '';

      // Parse current attendees
      List<String> attendeesList = attendeesIds.isEmpty
          ? []
          : attendeesIds
              .split(',')
              .where((id) => id.trim().isNotEmpty)
              .toList();

      // Check if user is already in the list
      final userIdStr = userId.toString();
      if (!attendeesList.contains(userIdStr)) {
        attendeesList.add(userIdStr);
      }

      // Update the event with new attendees list
      final updatedAttendeesIds = attendeesList.join(',');
      final result = await db.update(
        'events',
        {'attendeesIds': updatedAttendeesIds},
        where: 'id = ?',
        whereArgs: [eventId],
      );

      // Also update the registration status to 'registered'
      if (result > 0) {
        await db.update(
          'event_registrations',
          {
            'status': 'registered',
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'eventId = ? AND userId = ?',
          whereArgs: [eventId, userId],
        );
      }

      return result > 0;
    } catch (e) {
      debugPrint('Error adding user to event attendees: $e');
      return false;
    }
  }

  Future<bool> removeUserFromEventAttendees(int userId, int eventId) async {
    try {
      final db = await database;

      // Get the current event
      final events = await db.query(
        'events',
        where: 'id = ?',
        whereArgs: [eventId],
      );

      if (events.isEmpty) {
        return false;
      }

      final event = events.first;
      String attendeesIds = event['attendeesIds'] as String? ?? '';

      // Parse current attendees
      List<String> attendeesList = attendeesIds.isEmpty
          ? []
          : attendeesIds
              .split(',')
              .where((id) => id.trim().isNotEmpty)
              .toList();

      // Remove the user
      final userIdStr = userId.toString();
      attendeesList.remove(userIdStr);

      // Update the event with new attendees list
      final updatedAttendeesIds = attendeesList.join(',');
      final result = await db.update(
        'events',
        {'attendeesIds': updatedAttendeesIds},
        where: 'id = ?',
        whereArgs: [eventId],
      );

      // Also update the registration status to 'canceled'
      if (result > 0) {
        await db.update(
          'event_registrations',
          {
            'status': 'canceled',
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'eventId = ? AND userId = ?',
          whereArgs: [eventId, userId],
        );
      }

      return result > 0;
    } catch (e) {
      debugPrint('Error removing user from event attendees: $e');
      return false;
    }
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

  Future<Story?> getStoryById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'stories',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Story.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateStory(Map<String, dynamic> story) async {
    final db = await database;
    return await db.update(
      'stories',
      story,
      where: 'id = ?',
      whereArgs: [story['id']],
    );
  }

  Future<int> deleteStory(int id) async {
    final db = await database;
    return await db.delete(
      'stories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Message methods
  Future<List<Message>> getMessages(
      {int? senderId, int? receiverId, int? groupId}) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (groupId != null) {
      // Group messages
      whereClause = 'groupId = ?';
      whereArgs.add(groupId);
    } else if (senderId != null && receiverId != null) {
      // Direct messages between two users
      whereClause =
          '(senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)';
      whereArgs.add(senderId);
      whereArgs.add(receiverId);
      whereArgs.add(receiverId);
      whereArgs.add(senderId);
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

  Future<int> insertMessage(Map<String, dynamic> message) async {
    final db = await database;
    return await db.insert('messages', message);
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
  Future<int> markAllMessagesAsRead(
      {int? senderId, int? receiverId, int? groupId}) async {
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

  Future<List<custom_notification.Notification>> getNotifications(int userId,
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
      return custom_notification.Notification.fromMap(maps[i]);
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

  // Implementation for story likes functionality
  Future<void> toggleLikeStory(int storyId, int userId) async {
    final db = await database;

    // Check if there's a story_likes table, create if it doesn't exist
    await db.execute('''
    CREATE TABLE IF NOT EXISTS story_likes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      storyId INTEGER NOT NULL,
      userId INTEGER NOT NULL,
      createdAt TEXT NOT NULL,
      FOREIGN KEY (storyId) REFERENCES stories (id),
      FOREIGN KEY (userId) REFERENCES users (id)
    )
  ''');

    // Start a transaction
    await db.transaction((txn) async {
      // Check if user already liked this story
      final List<Map<String, dynamic>> existingLikes = await txn.query(
        'story_likes',
        where: 'storyId = ? AND userId = ?',
        whereArgs: [storyId, userId],
      );

      if (existingLikes.isEmpty) {
        // User hasn't liked the story yet, add like
        await txn.insert('story_likes', {
          'storyId': storyId,
          'userId': userId,
          'createdAt': DateTime.now().toIso8601String(),
        });

        // Increment likes count
        await txn.rawUpdate(
          'UPDATE stories SET likesCount = likesCount + 1 WHERE id = ?',
          [storyId],
        );
      } else {
        // User already liked the story, remove like
        await txn.delete(
          'story_likes',
          where: 'storyId = ? AND userId = ?',
          whereArgs: [storyId, userId],
        );

        // Decrement likes count (ensuring it doesn't go below 0)
        await txn.rawUpdate(
          'UPDATE stories SET likesCount = MAX(0, likesCount - 1) WHERE id = ?',
          [storyId],
        );
      }
    });
  }

  // Check if a user has liked a story
  Future<bool> hasUserLikedStory(int storyId, int userId) async {
    final db = await database;

    // Check if the story_likes table exists
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='story_likes'",
    );

    if (tables.isEmpty) {
      // Table doesn't exist yet, so user hasn't liked anything
      return false;
    }

    final List<Map<String, dynamic>> likes = await db.query(
      'story_likes',
      where: 'storyId = ? AND userId = ?',
      whereArgs: [storyId, userId],
    );

    return likes.isNotEmpty;
  }

  // Get stories liked by a user
  Future<List<Story>> getStoriesLikedByUser(int userId) async {
    final db = await database;

    // Check if the story_likes table exists
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='story_likes'",
    );

    if (tables.isEmpty) {
      // Table doesn't exist yet
      return [];
    }

    final List<Map<String, dynamic>> results = await db.rawQuery('''
    SELECT s.*
    FROM stories s
    JOIN story_likes sl ON s.id = sl.storyId
    WHERE sl.userId = ?
    ORDER BY sl.createdAt DESC
  ''', [userId]);

    return List.generate(results.length, (i) {
      return Story.fromMap(results[i]);
    });
  }

  // Get users who liked a story
  Future<List<User>> getUsersWhoLikedStory(int storyId) async {
    final db = await database;

    // Check if the story_likes table exists
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='story_likes'",
    );

    if (tables.isEmpty) {
      // Table doesn't exist yet
      return [];
    }

    final List<Map<String, dynamic>> results = await db.rawQuery('''
    SELECT u.*
    FROM users u
    JOIN story_likes sl ON u.id = sl.userId
    WHERE sl.storyId = ?
    ORDER BY sl.createdAt DESC
  ''', [storyId]);

    return List.generate(results.length, (i) {
      return User.fromMap(results[i]);
    });
  }

  // For testing - reset likes for a story
  Future<void> resetStoryLikes(int storyId) async {
    final db = await database;

    await db.transaction((txn) async {
      // Delete all likes for this story
      await txn.delete(
        'story_likes',
        where: 'storyId = ?',
        whereArgs: [storyId],
      );

      // Reset like count to 0
      await txn.update(
        'stories',
        {'likesCount': 0},
        where: 'id = ?',
        whereArgs: [storyId],
      );
    });
  }

  Future<int> safeInsertEvent(Map<String, dynamic> event) async {
    try {
      // Ensure database schema is up to date
      await updateEventTableIfNeeded();

      // Make a copy of the event data to avoid modifying the original
      final Map<String, dynamic> sanitizedEvent = Map.from(event);

      // Check if hasQuestionnaire exists in the map
      if (!sanitizedEvent.containsKey('hasQuestionnaire')) {
        // Add it with default value if the questionnaire data exists
        sanitizedEvent['hasQuestionnaire'] =
            (sanitizedEvent.containsKey('questionnaireData') &&
                    sanitizedEvent['questionnaireData'] != null)
                ? 1
                : 0;
      }

      // Ensure questionnaireData is properly formatted as a string
      if (sanitizedEvent.containsKey('questionnaireData')) {
        final questionnaireData = sanitizedEvent['questionnaireData'];
        if (questionnaireData != null) {
          // If it's already a string, keep it as is
          if (questionnaireData is String) {
            // Validate it's proper JSON
            try {
              jsonDecode(questionnaireData);
            } catch (e) {
              debugPrint('Invalid JSON in questionnaireData: $e');
              // If invalid, set to null to avoid database errors
              sanitizedEvent['questionnaireData'] = null;
              sanitizedEvent['hasQuestionnaire'] = 0;
            }
          }
          // If it's a Map or other object, convert to JSON string
          else {
            try {
              sanitizedEvent['questionnaireData'] =
                  jsonEncode(questionnaireData);
              sanitizedEvent['hasQuestionnaire'] = 1;
            } catch (e) {
              debugPrint('Error encoding questionnaireData: $e');
              sanitizedEvent['questionnaireData'] = null;
              sanitizedEvent['hasQuestionnaire'] = 0;
            }
          }
        } else {
          sanitizedEvent['hasQuestionnaire'] = 0;
        }
      }

      // Handle boolean values (convert to 1/0 for SQLite)
      for (final key in ['isPrivate', 'hasQuestionnaire']) {
        if (sanitizedEvent.containsKey(key)) {
          final value = sanitizedEvent[key];
          if (value is bool) {
            sanitizedEvent[key] = value ? 1 : 0;
          }
        }
      }
      final db = await database;
      return await db.insert(
        'events',
        sanitizedEvent,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error in safeInsertEvent: $e');
      return 0;
    }
  }

  Future<int> registerForEvent(Map<String, dynamic> registration) async {
    try {
      final db = await database;

      // Check if registration already exists
      final existingRegistration = await db.query(
        'event_registrations',
        where: 'eventId = ? AND userId = ?',
        whereArgs: [registration['eventId'], registration['userId']],
      );

      if (existingRegistration.isNotEmpty) {
        // Update existing registration
        return await db.update(
          'event_registrations',
          registration,
          where: 'eventId = ? AND userId = ?',
          whereArgs: [registration['eventId'], registration['userId']],
        );
      } else {
        // Insert new registration
        return await db.insert(
          'event_registrations',
          registration,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      debugPrint('Error registering for event: $e');
      return 0;
    }
  }

  Future<int> updateEventRegistration(
      int eventId, int userId, String status, String paymentStatus) async {
    try {
      final db = await database;
      return await db.update(
        'event_registrations',
        {
          'status': status,
          'paymentStatus': paymentStatus,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'eventId = ? AND userId = ?',
        whereArgs: [eventId, userId],
      );
    } catch (e) {
      debugPrint('Error updating event registration: $e');
      return 0;
    }
  }

  Future<Map<String, dynamic>?> getEventRegistration(
      int eventId, int userId) async {
    try {
      final db = await database;

      // Query for registration
      final List<Map<String, dynamic>> registrations = await db.query(
        'event_registrations',
        where: 'eventId = ? AND userId = ?',
        whereArgs: [eventId, userId],
      );

      if (registrations.isNotEmpty) {
        return registrations.first;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting event registration: $e');
      return null;
    }
  }

  // Event Analytics methods
  Future<int> insertEventAnalytics(Map<String, dynamic> analytics) async {
    final db = await database;

    // Ensure the table exists
    try {
      await db.query('event_analytics', limit: 1);
    } catch (e) {
      // Table doesn't exist, create it
      await db.execute('''
        CREATE TABLE IF NOT EXISTS event_analytics (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          eventId INTEGER NOT NULL,
          viewCount INTEGER DEFAULT 0,
          shareCount INTEGER DEFAULT 0,
          clickCount INTEGER DEFAULT 0,
          lastUpdated TEXT NOT NULL,
          FOREIGN KEY (eventId) REFERENCES events (id)
        )
      ''');
    }

    // Set lastUpdated if not provided
    if (!analytics.containsKey('lastUpdated')) {
      analytics['lastUpdated'] = DateTime.now().toIso8601String();
    }

    return await db.insert('event_analytics', analytics);
  }

  Future<EventAnalytics?> getEventAnalytics(int eventId) async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'event_analytics',
        where: 'eventId = ?',
        whereArgs: [eventId],
      );

      if (maps.isNotEmpty) {
        return EventAnalytics.fromMap(maps.first);
      }

      // If no analytics exist for this event, create default entry
      final id = await insertEventAnalytics({
        'eventId': eventId,
        'viewCount': 0,
        'shareCount': 0,
        'clickCount': 0,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      final newMaps = await db.query(
        'event_analytics',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (newMaps.isNotEmpty) {
        return EventAnalytics.fromMap(newMaps.first);
      }
    } catch (e) {
      print('Error getting event analytics: $e');
      // The table might not exist yet
    }

    return null;
  }

  Future<void> incrementEventViewCount(int eventId) async {
    final db = await database;

    try {
      // First check if analytics exist for this event
      final analytics = await getEventAnalytics(eventId);

      if (analytics != null) {
        // Update existing record
        await db.update(
          'event_analytics',
          {
            'viewCount': analytics.viewCount + 1,
            'lastUpdated': DateTime.now().toIso8601String(),
          },
          where: 'eventId = ?',
          whereArgs: [eventId],
        );
      } else {
        // Create new record
        await insertEventAnalytics({
          'eventId': eventId,
          'viewCount': 1,
          'shareCount': 0,
          'clickCount': 0,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }

  Future<void> incrementEventShareCount(int eventId) async {
    final db = await database;

    try {
      // First check if analytics exist for this event
      final analytics = await getEventAnalytics(eventId);

      if (analytics != null) {
        // Update existing record
        await db.update(
          'event_analytics',
          {
            'shareCount': analytics.shareCount + 1,
            'lastUpdated': DateTime.now().toIso8601String(),
          },
          where: 'eventId = ?',
          whereArgs: [eventId],
        );
      } else {
        // Create new record
        await insertEventAnalytics({
          'eventId': eventId,
          'viewCount': 0,
          'shareCount': 1,
          'clickCount': 0,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Error incrementing share count: $e');
    }
  }

  Future<void> incrementEventClickCount(int eventId) async {
    final db = await database;

    try {
      // First check if analytics exist for this event
      final analytics = await getEventAnalytics(eventId);

      if (analytics != null) {
        // Update existing record
        await db.update(
          'event_analytics',
          {
            'clickCount': analytics.clickCount + 1,
            'lastUpdated': DateTime.now().toIso8601String(),
          },
          where: 'eventId = ?',
          whereArgs: [eventId],
        );
      } else {
        // Create new record
        await insertEventAnalytics({
          'eventId': eventId,
          'viewCount': 0,
          'shareCount': 0,
          'clickCount': 1,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Error incrementing click count: $e');
    }
  }

  Future<void> updateEventTableIfNeeded() async {
    final db = await database;
    await _ensureEventSchemaUpdated(db);
  }

  // Get users by IDs
  Future<List<User>> getUsersByIds(List<int> userIds) async {
    if (userIds.isEmpty) {
      return [];
    }

    final db = await database;
    final List<User> users = [];

    // Process each ID individually to avoid SQL injection issues
    for (final userId in userIds) {
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (maps.isNotEmpty) {
        users.add(User.fromMap(maps.first));
      }
    }

    return users;
  }

  Future<int> insertPost(Map<String, dynamic> post) async {
    final db = await database;
    return await db.insert('posts', post);
  }

  // Get a post by ID
  Future<Post?> getPostById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'posts',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Post.fromMap(maps.first);
    }
    return null;
  }

  // Delete a post
  Future<int> deletePost(int id) async {
    final db = await database;

    // Start a transaction to delete associated data
    return await db.transaction((txn) async {
      // Delete comments associated with this post
      await txn.delete(
        'comments',
        where: 'postId = ?',
        whereArgs: [id],
      );

      // Delete post likes (if you have a post_likes table)
      try {
        await txn.delete(
          'post_likes',
          where: 'postId = ?',
          whereArgs: [id],
        );
      } catch (e) {
        // Table might not exist, that's okay
        print('No post_likes table found: $e');
      }

      // Delete the post itself
      return await txn.delete(
        'posts',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  // Get posts for the home feed - personal posts and group posts
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

  // Add a comment to a post
  Future<int> addComment(Map<String, dynamic> comment) async {
    final db = await database;

    // Insert the comment
    final commentId = await db.insert('comments', comment);

    // Increment the comments count on the post
    if (commentId > 0) {
      await db.rawUpdate(
        'UPDATE posts SET commentsCount = commentsCount + 1 WHERE id = ?',
        [comment['postId']],
      );
    }

    return commentId;
  }

  // Get comments for a post
  Future<List<Map<String, dynamic>>> getCommentsForPost(int postId) async {
    final db = await database;

    final List<Map<String, dynamic>> results = await db.rawQuery('''
    SELECT c.*, u.name as userName, u.profilePicture
    FROM comments c
    LEFT JOIN users u ON c.userId = u.id
    WHERE c.postId = ?
    ORDER BY c.createdAt ASC
  ''', [postId]);

    return results;
  }

  // Toggle like on a post
  Future<bool> toggleLikePost(int postId, int userId) async {
    final db = await database;

    // Check if post_likes table exists, create if it doesn't
    await db.execute('''
    CREATE TABLE IF NOT EXISTS post_likes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      postId INTEGER NOT NULL,
      userId INTEGER NOT NULL,
      createdAt TEXT NOT NULL,
      FOREIGN KEY (postId) REFERENCES posts (id),
      FOREIGN KEY (userId) REFERENCES users (id)
    )
  ''');

    // Check if user already liked the post
    final List<Map<String, dynamic>> existingLikes = await db.query(
      'post_likes',
      where: 'postId = ? AND userId = ?',
      whereArgs: [postId, userId],
    );

    // If user has already liked the post, unlike it
    if (existingLikes.isNotEmpty) {
      await db.transaction((txn) async {
        // Delete the like record
        await txn.delete(
          'post_likes',
          where: 'postId = ? AND userId = ?',
          whereArgs: [postId, userId],
        );

        // Decrement the likes count
        await txn.rawUpdate(
          'UPDATE posts SET likesCount = MAX(0, likesCount - 1) WHERE id = ?',
          [postId],
        );
      });

      return false; // Returning false means the post is now unliked
    }
    // Otherwise, like the post
    else {
      await db.transaction((txn) async {
        // Insert like record
        await txn.insert('post_likes', {
          'postId': postId,
          'userId': userId,
          'createdAt': DateTime.now().toIso8601String(),
        });

        // Increment the likes count
        await txn.rawUpdate(
          'UPDATE posts SET likesCount = likesCount + 1 WHERE id = ?',
          [postId],
        );
      });

      return true; // Returning true means the post is now liked
    }
  }

  // Check if user has liked a post
  Future<bool> hasUserLikedPost(int postId, int userId) async {
    final db = await database;

    // Check if post_likes table exists
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='post_likes'",
    );

    if (tables.isEmpty) {
      return false; // Table doesn't exist yet
    }

    // Check for like record
    final List<Map<String, dynamic>> likes = await db.query(
      'post_likes',
      where: 'postId = ? AND userId = ?',
      whereArgs: [postId, userId],
    );

    return likes.isNotEmpty;
  }

  Future<bool> deleteComment(int commentId) async {
    final db = await database;

    try {
      // Start a transaction to update post comment count and delete the comment
      return await db.transaction((txn) async {
        // Get the comment to find the associated post
        final List<Map<String, dynamic>> comments = await txn.query(
          'comments',
          where: 'id = ?',
          whereArgs: [commentId],
        );

        if (comments.isEmpty) {
          return false;
        }

        final postId = comments.first['postId'] as int;

        // Delete the comment
        final deleteResult = await txn.delete(
          'comments',
          where: 'id = ?',
          whereArgs: [commentId],
        );

        if (deleteResult > 0) {
          // Decrement the comments count on the post
          await txn.rawUpdate(
            'UPDATE posts SET commentsCount = MAX(0, commentsCount - 1) WHERE id = ?',
            [postId],
          );
          return true;
        }

        return false;
      });
    } catch (e) {
      print('Error deleting comment: $e');
      return false;
    }
  }

  // Get user's comments
  Future<List<Map<String, dynamic>>> getUserComments(int userId) async {
    final db = await database;

    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT c.*, p.content as postContent, p.userId as postUserId,
             u.name as postAuthorName, u.profilePicture as postAuthorPicture
      FROM comments c
      JOIN posts p ON c.postId = p.id
      JOIN users u ON p.userId = u.id
      WHERE c.userId = ?
      ORDER BY c.createdAt DESC
    ''', [userId]);

    return results;
  }

  // Get popular posts (most comments and likes)
  Future<List<Post>> getPopularPosts({int limit = 10}) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM posts
      ORDER BY (likesCount + commentsCount) DESC
      LIMIT ?
    ''', [limit]);

    return List.generate(maps.length, (i) {
      return Post.fromMap(maps[i]);
    });
  }

  // Search for posts by content
  Future<List<Post>> searchPosts(String query) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'posts',
      where: 'content LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) {
      return Post.fromMap(maps[i]);
    });
  }

  // Get detailed post data including author and group info
  Future<Map<String, dynamic>?> getPostDetails(int postId) async {
    final db = await database;

    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT p.*, u.name as authorName, u.profilePicture as authorProfilePicture,
             g.name as groupName, g.id as groupId, g.image as groupImage
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

  // Get recent comments for a post
  Future<List<Map<String, dynamic>>> getRecentCommentsForPost(int postId,
      {int limit = 3}) async {
    final db = await database;

    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT c.*, u.name as userName, u.profilePicture as userProfilePicture
      FROM comments c
      JOIN users u ON c.userId = u.id
      WHERE c.postId = ?
      ORDER BY c.createdAt DESC
      LIMIT ?
    ''', [postId, limit]);

    return results;
  }

  Future<void> incrementShareCount(int postId) async {
    final db = await database;

    try {
      // Update the share count in a dedicated analytics table if it exists
      try {
        await db.rawQuery('SELECT * FROM post_analytics LIMIT 1');

        // Check if this post has an analytics entry
        final List<Map<String, dynamic>> analytics = await db.query(
          'post_analytics',
          where: 'postId = ?',
          whereArgs: [postId],
        );

        if (analytics.isEmpty) {
          // Create new analytics entry
          await db.insert('post_analytics', {
            'postId': postId,
            'shareCount': 1,
            'viewCount': 0,
            'lastUpdated': DateTime.now().toIso8601String(),
          });
        } else {
          // Update existing entry
          await db.update(
            'post_analytics',
            {
              'shareCount': analytics.first['shareCount'] + 1,
              'lastUpdated': DateTime.now().toIso8601String(),
            },
            where: 'postId = ?',
            whereArgs: [postId],
          );
        }
      } catch (e) {
        // Table doesn't exist, create it
        print('Creating post_analytics table');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS post_analytics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            postId INTEGER NOT NULL,
            viewCount INTEGER DEFAULT 0,
            shareCount INTEGER DEFAULT 0,
            lastUpdated TEXT NOT NULL,
            FOREIGN KEY (postId) REFERENCES posts (id)
          )
        ''');

        // Then create the entry
        await db.insert('post_analytics', {
          'postId': postId,
          'shareCount': 1,
          'viewCount': 0,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      }

      // Also update the likes count in the post itself if you want to track it there
      // This is optional but can be useful for quick access
      await db.rawUpdate(
        'UPDATE posts SET sharesCount = COALESCE(sharesCount, 0) + 1 WHERE id = ?',
        [postId],
      );
    } catch (e) {
      print('Error incrementing share count: $e');
      // Don't rethrow, as this is a non-critical operation
    }
  }

  // Share a post
  Future<bool> sharePost(int postId, int userId, String shareType) async {
    final db = await database;

    try {
      // Record the share activity
      await db.insert('share_activity', {
        'postId': postId,
        'userId': userId,
        'shareType': shareType, // e.g., 'external', 'internal'
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Increment the share count
      await incrementShareCount(postId);

      return true;
    } catch (e) {
      print('Error recording share: $e');

      // Try to create the table if it doesn't exist
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS share_activity (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            postId INTEGER NOT NULL,
            userId INTEGER NOT NULL,
            shareType TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            FOREIGN KEY (postId) REFERENCES posts (id),
            FOREIGN KEY (userId) REFERENCES users (id)
          )
        ''');

        // Try again after creating the table
        await db.insert('share_activity', {
          'postId': postId,
          'userId': userId,
          'shareType': shareType,
          'timestamp': DateTime.now().toIso8601String(),
        });

        await incrementShareCount(postId);

        return true;
      } catch (e2) {
        print('Error creating share_activity table: $e2');
        return false;
      }
    }
  }

  // Update posts table to include sharesCount if it doesn't exist
  Future<void> ensureSharesCountColumn() async {
    final db = await database;

    try {
      // Try to query the sharesCount column
      await db.rawQuery('SELECT sharesCount FROM posts LIMIT 1');
    } catch (e) {
      // Column doesn't exist, add it
      print('Adding sharesCount column to posts table');
      await db.execute(
          'ALTER TABLE posts ADD COLUMN sharesCount INTEGER DEFAULT 0');
    }
  }

  // Record payment for an event
  Future<bool> recordEventPayment(Map<String, dynamic> paymentData) async {
    final db = await database;

    try {
      // Check if there's already a registration
      final List<Map<String, dynamic>> existing = await db.query(
        'attendee_registrations',
        where: 'eventId = ? AND userId = ?',
        whereArgs: [paymentData['eventId'], paymentData['userId']],
      );

      if (existing.isEmpty) {
        // Create new registration with payment data
        await db.insert('attendee_registrations', {
          'eventId': paymentData['eventId'],
          'userId': paymentData['userId'],
          'paymentStatus': paymentData['paymentStatus'],
          'paymentReference': paymentData['paymentReference'],
          'paymentAmount': paymentData['paymentAmount'],
          'paymentDate':
              paymentData['paymentDate'] ?? DateTime.now().toIso8601String(),
          'registrationDate': DateTime.now().toIso8601String(),
        });
      } else {
        // Update existing registration with payment data
        await db.update(
          'attendee_registrations',
          {
            'paymentStatus': paymentData['paymentStatus'],
            'paymentReference': paymentData['paymentReference'],
            'paymentAmount': paymentData['paymentAmount'],
            'paymentDate':
                paymentData['paymentDate'] ?? DateTime.now().toIso8601String(),
          },
          where: 'eventId = ? AND userId = ?',
          whereArgs: [paymentData['eventId'], paymentData['userId']],
        );
      }

      // If payment is successful, also add user to event attendees
      if (paymentData['paymentStatus'] == 'completed') {
        await addUserToEventAttendees(
            paymentData['userId'], paymentData['eventId']);
      }

      return true;
    } catch (e) {
      print('Error recording event payment: $e');
      return false;
    }
  }

// Save questionnaire responses for an event
  Future<bool> saveQuestionnaireResponses(
      int eventId, int userId, String responses) async {
    final db = await database;

    try {
      // Check if there's already a registration
      final List<Map<String, dynamic>> existing = await db.query(
        'attendee_registrations',
        where: 'eventId = ? AND userId = ?',
        whereArgs: [eventId, userId],
      );

      if (existing.isEmpty) {
        // Create new registration with questionnaire data
        await db.insert('attendee_registrations', {
          'eventId': eventId,
          'userId': userId,
          'questionnaireResponses': responses,
          'registrationDate': DateTime.now().toIso8601String(),
        });
      } else {
        // Update existing registration with questionnaire data
        await db.update(
          'attendee_registrations',
          {
            'questionnaireResponses': responses,
          },
          where: 'eventId = ? AND userId = ?',
          whereArgs: [eventId, userId],
        );
      }

      return true;
    } catch (e) {
      print('Error saving questionnaire responses: $e');
      return false;
    }
  }

  Future<void> _ensureTablesExist(Database db) async {
    try {
      // Check if event_registrations table exists
      try {
        await db.query('event_registrations', limit: 1);
        print('event_registrations table exists');
      } catch (e) {
        print('Creating event_registrations table');
        await db.execute('''
      CREATE TABLE event_registrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        eventId INTEGER NOT NULL,
        userId INTEGER NOT NULL,
        registrationDate TEXT,
        status TEXT,
        paymentStatus TEXT,
        paymentReference TEXT,
        updatedAt TEXT,
        UNIQUE(eventId, userId)
      )
      ''');
      }

      // Other table checks...
    } catch (e) {
      print('Error ensuring tables exist: $e');
    }
  }

// Get attendee registration details including payment status and questionnaire responses
  Future<Map<String, dynamic>?> getAttendeeRegistration(
      int eventId, int userId) async {
    try {
      final db = await database;

      final registrations = await db.query(
        'event_registrations',
        where: 'eventId = ? AND userId = ?',
        whereArgs: [eventId, userId],
      );

      if (registrations.isNotEmpty) {
        return registrations.first;
      }

      // Then check if user is in attendees list
      final events = await db.query(
        'events',
        where: 'id = ?',
        whereArgs: [eventId],
      );

      if (events.isNotEmpty) {
        final event = events.first;
        final attendeesIds = event['attendeesIds'] as String? ?? '';

        if (attendeesIds.isNotEmpty) {
          final attendeesList = attendeesIds
              .split(',')
              .where((id) => id.trim().isNotEmpty)
              .map((id) => int.parse(id.trim()))
              .toList();

          if (attendeesList.contains(userId)) {
            // Create a synthetic registration
            return {
              'eventId': eventId,
              'userId': userId,
              'status': 'registered',
              'paymentStatus': 'completed',
              'registrationDate': event['createdAt'],
            };
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error getting attendee registration: $e');
      return null;
    }
  }

  Future<bool> hasUserPaidForEvent(int eventId, int userId) async {
    try {
      final db = await database;

      final payments = await db.query(
        'event_payments',
        where: 'eventId = ? AND userId = ? AND paymentStatus = ?',
        whereArgs: [eventId, userId, 'completed'],
      );
      if (payments.isEmpty) {
        final registrations = await db.query(
          'event_registrations',
          where: 'eventId = ? AND userId = ? AND paymentStatus = ?',
          whereArgs: [eventId, userId, 'completed'],
        );

        return registrations.isNotEmpty;
      }

      return payments.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if user paid for event: $e');
      return false;
    }
  }

// Get all registrations for an event (with user details)
  Future<List<Map<String, dynamic>>> getEventRegistrations(int eventId) async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT r.*, u.name, u.email, u.phoneNumber, u.profilePicture
      FROM attendee_registrations r
      JOIN users u ON r.userId = u.id
      WHERE r.eventId = ?
      ORDER BY r.registrationDate DESC
    ''', [eventId]);

      return results;
    } catch (e) {
      print('Error getting event registrations: $e');
      return [];
    }
  }
}
