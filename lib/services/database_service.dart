import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:turikumwe/models/story.dart';
import 'package:turikumwe/models/user.dart';
import 'package:flutter/foundation.dart';

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
      version: 3,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE events ADD COLUMN district TEXT');
      await db.execute('ALTER TABLE events ADD COLUMN category TEXT');
      await db.execute('ALTER TABLE events ADD COLUMN createdAt TEXT');
      await db.execute('ALTER TABLE events ADD COLUMN updatedAt TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE story_likes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          storyId INTEGER NOT NULL,
          userId INTEGER NOT NULL,
          createdAt TEXT NOT NULL,
          FOREIGN KEY (storyId) REFERENCES stories (id),
          FOREIGN KEY (userId) REFERENCES users (id)
        )
      ''');
      await db.execute('CREATE INDEX idx_stories_user ON stories(userId)');
      await db.execute('CREATE INDEX idx_stories_category ON stories(category)');
      await db.execute('CREATE INDEX idx_story_likes_composite ON story_likes(storyId, userId)');
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
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

    await db.execute('''
      CREATE TABLE story_likes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        storyId INTEGER NOT NULL,
        userId INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (storyId) REFERENCES stories (id),
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_stories_user ON stories(userId)');
    await db.execute('CREATE INDEX idx_stories_category ON stories(category)');
    await db.execute('CREATE INDEX idx_story_likes_composite ON story_likes(storyId, userId)');
  }

  // Story Methods
  Future<int> insertStory(Story story) async {
    try {
      final db = await database;
      return await db.insert('stories', story.toMap());
    } catch (e) {
      debugPrint('Error inserting story: $e');
      rethrow;
    }
  }

  Future<List<Story>> getStories({String? category}) async {
    try {
      final db = await database;
      final maps = await db.query(
        'stories',
        where: category != null ? 'category = ?' : null,
        whereArgs: category != null ? [category] : null,
        orderBy: 'createdAt DESC',
      );
      return maps.map((map) => Story.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting stories: $e');
      rethrow;
    }
  }

  Future<List<Story>> getStoriesWithUserInfo({String? category}) async {
    try {
      final db = await database;
      final query = '''
        SELECT s.*, u.name as userName, u.profilePicture as userProfile
        FROM stories s
        JOIN users u ON s.userId = u.id
        ${category != null ? "WHERE s.category = ?" : ""}
        ORDER BY s.createdAt DESC
      ''';
      final results = await db.rawQuery(query, category != null ? [category] : []);
      return results.map((map) => Story.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting stories with user info: $e');
      rethrow;
    }
  }

  Future<Story?> getStoryById(int id) async {
    try {
      final db = await database;
      final query = '''
        SELECT s.*, u.name as userName, u.profilePicture as userProfile
        FROM stories s
        JOIN users u ON s.userId = u.id
        WHERE s.id = ?
      ''';
      final results = await db.rawQuery(query, [id]);
      return results.isNotEmpty ? Story.fromMap(results.first) : null;
    } catch (e) {
      debugPrint('Error getting story by ID: $e');
      rethrow;
    }
  }

  Future<bool> likeStory(int storyId, int userId) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        final existing = await txn.query(
          'story_likes',
          where: 'storyId = ? AND userId = ?',
          whereArgs: [storyId, userId],
        );

        if (existing.isEmpty) {
          await txn.rawUpdate(
            'UPDATE stories SET likesCount = likesCount + 1 WHERE id = ?',
            [storyId],
          );
          await txn.insert('story_likes', {
            'storyId': storyId,
            'userId': userId,
            'createdAt': DateTime.now().toIso8601String(),
          });
        }
      });
      return true;
    } catch (e) {
      debugPrint('Error liking story: $e');
      return false;
    }
  }

  Future<bool> unlikeStory(int storyId, int userId) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.rawUpdate(
          'UPDATE stories SET likesCount = likesCount - 1 WHERE id = ?',
          [storyId],
        );
        await txn.delete(
          'story_likes',
          where: 'storyId = ? AND userId = ?',
          whereArgs: [storyId, userId],
        );
      });
      return true;
    } catch (e) {
      debugPrint('Error unliking story: $e');
      return false;
    }
  }

  Future<bool> hasUserLikedStory(int storyId, int userId) async {
    try {
      final db = await database;
      final result = await db.query(
        'story_likes',
        where: 'storyId = ? AND userId = ?',
        whereArgs: [storyId, userId],
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking story like: $e');
      return false;
    }
  }

  Future<List<Story>> getStoriesByUser(int userId) async {
    try {
      final db = await database;
      final results = await db.rawQuery('''
        SELECT s.*, u.name as userName, u.profilePicture as userProfile
        FROM stories s
        JOIN users u ON s.userId = u.id
        WHERE s.userId = ?
        ORDER BY s.createdAt DESC
      ''', [userId]);
      return results.map((map) => Story.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting user stories: $e');
      rethrow;
    }
  }

  Future<bool> deleteStory(int id) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete(
          'story_likes',
          where: 'storyId = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'stories',
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      return true;
    } catch (e) {
      debugPrint('Error deleting story: $e');
      return false;
    }
  }

  // User Methods
  Future<User?> getUserById(int id) async {
    try {
      final db = await database;
      final maps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );
      return maps.isNotEmpty ? User.fromMap(maps.first) : null;
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      rethrow;
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}