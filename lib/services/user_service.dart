// lib/services/user_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/services/database_service.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final DatabaseService _databaseService = DatabaseService();

  // Get all users except the current user
  Future<List<User>> getAllUsers({int? exceptUserId}) async {
    final db = await _databaseService.database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (exceptUserId != null) {
      whereClause = 'id != ?';
      whereArgs.add(exceptUserId);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) {
      return User.fromMap(maps[i]);
    });
  }

  // Search users by name, email, or district
  Future<List<User>> searchUsers(String query, {int? exceptUserId}) async {
    if (query.isEmpty) return [];

    final db = await _databaseService.database;

    String whereClause = 'name LIKE ? OR email LIKE ? OR district LIKE ?';
    List<dynamic> whereArgs = [
      '%$query%',
      '%$query%',
      '%$query%',
    ];

    if (exceptUserId != null) {
      whereClause = '$whereClause AND id != ?';
      whereArgs.add(exceptUserId);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
      limit: 20, // Limit search results
    );

    return List.generate(maps.length, (i) {
      return User.fromMap(maps[i]);
    });
  }

  // Get users that the current user has chatted with before
  Future<List<User>> getRecentContacts(int userId) async {
    final db = await _databaseService.database;

    // Find all users that the current user has exchanged messages with
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT DISTINCT u.*
      FROM users u
      JOIN messages m ON (m.senderId = u.id OR m.receiverId = u.id)
      WHERE (m.senderId = ? OR m.receiverId = ?) AND u.id != ?
      ORDER BY (
        SELECT MAX(timestamp) FROM messages
        WHERE (senderId = ? AND receiverId = u.id) OR (senderId = u.id AND receiverId = ?)
      ) DESC
      LIMIT 10
    ''', [userId, userId, userId, userId, userId]);

    return List.generate(results.length, (i) {
      return User.fromMap(results[i]);
    });
  }

  // Get user's contacts based on group memberships
  Future<List<User>> getContactsFromGroups(int userId) async {
    final db = await _databaseService.database;

    // Find users who are in the same groups as the current user
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT DISTINCT u.*
      FROM users u
      JOIN group_members gm1 ON u.id = gm1.userId
      JOIN group_members gm2 ON gm1.groupId = gm2.groupId
      WHERE gm2.userId = ? AND u.id != ?
      ORDER BY u.name ASC
    ''', [userId, userId]);

    return List.generate(results.length, (i) {
      return User.fromMap(results[i]);
    });
  }

  // Check if a conversation exists between two users
  Future<bool> conversationExists(int user1Id, int user2Id) async {
    final db = await _databaseService.database;

    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM messages
      WHERE (senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)
    ''', [user1Id, user2Id, user2Id, user1Id]);

    // Fixed: Properly handle the count result and return a bool
    int count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  // Get user profile details including stats
  Future<Map<String, dynamic>> getUserProfileWithStats(int userId) async {
    final db = await _databaseService.database;
    final user = await _databaseService.getUserById(userId);
    
    if (user == null) {
      throw Exception('User not found');
    }

    // Get post count
    final postResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM posts WHERE userId = ?',
      [userId],
    );
    final postCount = Sqflite.firstIntValue(postResult) ?? 0;

    // Get groups count
    final groupResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM group_members WHERE userId = ?',
      [userId],
    );
    final groupCount = Sqflite.firstIntValue(groupResult) ?? 0;

    // Get events organized count
    final eventResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM events WHERE organizerId = ?',
      [userId],
    );
    final eventCount = Sqflite.firstIntValue(eventResult) ?? 0;

    return {
      'user': user,
      'stats': {
        'postCount': postCount,
        'groupCount': groupCount,
        'eventCount': eventCount,
      }
    };
  }
}