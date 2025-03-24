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
  
  Future<Database> initDatabase() async {
    String path = join(await getDatabasesPath(), 'turikumwe.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
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
      whereClause = whereClause.isEmpty ? 'groupId = ?' : '$whereClause AND groupId = ?';
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
  
  // Group methods
  Future<int> insertGroup(Map<String, dynamic> group) async {
    final db = await database;
    return await db.insert('groups', group);
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
      whereClause = whereClause.isEmpty ? 'district = ?' : '$whereClause AND district = ?';
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
  
  // Event methods
  Future<int> insertEvent(Map<String, dynamic> event) async {
    final db = await database;
    return await db.insert('events', event);
  }
  
  Future<List<Event>> getEvents({int? groupId, DateTime? fromDate}) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (groupId != null) {
      whereClause = 'groupId = ?';
      whereArgs.add(groupId);
    }
    
    if (fromDate != null) {
      whereClause = whereClause.isEmpty ? 'date >= ?' : '$whereClause AND date >= ?';
      whereArgs.add(fromDate.toIso8601String());
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'date ASC',
    );
    
    return List.generate(maps.length, (i) {
      return Event.fromMap(maps[i]);
    });
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
  
  Future<List<Message>> getMessages({int? senderId, int? receiverId, int? groupId}) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (senderId != null && receiverId != null) {
      // Direct messages between two users
      whereClause = '(senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)';
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
  
  // Notification methods
  Future<int> insertNotification(Map<String, dynamic> notification) async {
    final db = await database;
    return await db.insert('notifications', notification);
  }
  
  Future<List<Notification>> getNotifications(int userId, {bool? isRead}) async {
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