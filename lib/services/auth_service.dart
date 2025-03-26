// lib/services/auth_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/services/database_service.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:developer' as developer;

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  User? _currentUser;
  bool _isAuthenticated = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;

  /// Initialize the authentication service
  Future<void> init() async {
    try {
      String? userJson = await _storage.read(key: 'user');
      if (userJson != null) {
        _currentUser = User.fromMap(jsonDecode(userJson));
        _isAuthenticated = true;
        notifyListeners();
      } else {
        _isAuthenticated = false;
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error initializing auth service: $e',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      // Handle initialization errors gracefully
      await _storage.delete(key: 'user');
      _currentUser = null;
      _isAuthenticated = false;
    }
  }

  /// Hash a password using SHA-256
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Register a new user
  Future<bool> register(String name, String email, String password) async {
    try {
      // Check if user already exists
      final existingUser = await DatabaseService().getUserByEmail(email);
      if (existingUser != null) {
        return false; // User already exists
      }

      final hashedPassword = _hashPassword(password);
      final now = DateTime.now().toIso8601String();

      final userId = await DatabaseService().insertUser({
        'name': name,
        'email': email,
        'password': hashedPassword,
        'createdAt': now,
        'updatedAt': now,
      });

      if (userId > 0) {
        final user = await DatabaseService().getUserById(userId);
        if (user != null) {
          _currentUser = user;
          _isAuthenticated = true;
          await _storage.write(key: 'user', value: jsonEncode(user.toMap()));
          notifyListeners();
          return true;
        }
      }

      return false;
    } catch (e, stackTrace) {
      developer.log(
        'Registration error: $e',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Log in a user
  Future<bool> login(String email, String password) async {
    try {
      final hashedPassword = _hashPassword(password);
      final db = await DatabaseService().database;

      // Check user with email and password
      final List<Map<String, dynamic>> results = await db.query(
        'users',
        where: 'email = ? AND password = ?',
        whereArgs: [email, hashedPassword],
      );

      if (results.isNotEmpty) {
        final user = User.fromMap(results.first);
        _currentUser = user;
        _isAuthenticated = true;

        // Update login timestamp
        await db.update(
          'users',
          {'updatedAt': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [user.id],
        );

        await _storage.write(key: 'user', value: jsonEncode(user.toMap()));
        notifyListeners();
        return true;
      }

      return false;
    } catch (e, stackTrace) {
      developer.log(
        'Login error: $e',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Log out the current user
  Future<void> logout() async {
    try {
      await _storage.delete(key: 'user');
      _currentUser = null;
      _isAuthenticated = false;
      notifyListeners();
    } catch (e, stackTrace) {
      developer.log(
        'Logout error: $e',
        name: 'AuthService',
        error: e,
        stackTrace: stackTrace,
      );
      // Ensure user is logged out in the app
      _currentUser = null;
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> userData) async {
    try {
      if (_currentUser != null) {
        userData['id'] = _currentUser!.id;
        userData['updatedAt'] = DateTime.now().toIso8601String();

        final result = await DatabaseService().updateUser(userData);
        if (result > 0) {
          final updatedUser =
              await DatabaseService().getUserById(_currentUser!.id);
          if (updatedUser != null) {
            _currentUser = updatedUser;
            await _storage.write(
                key: 'user', value: jsonEncode(updatedUser.toMap()));
            notifyListeners();
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      print('Update profile error: $e');
      return false;
    }
  }

  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    try {
      if (_currentUser == null) {
        return false;
      }

      final hashedCurrentPassword = _hashPassword(currentPassword);
      final db = await DatabaseService().database;

      // Verify current password
      final List<Map<String, dynamic>> results = await db.query(
        'users',
        where: 'id = ? AND password = ?',
        whereArgs: [_currentUser!.id, hashedCurrentPassword],
      );

      if (results.isEmpty) {
        return false; // Current password is incorrect
      }

      // Update password
      final hashedNewPassword = _hashPassword(newPassword);
      final result = await db.update(
        'users',
        {
          'password': hashedNewPassword,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
      );

      return result > 0;
    } catch (e) {
      print('Change password error: $e');
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      if (_currentUser == null) {
        return false;
      }

      final db = await DatabaseService().database;

      // In a real app, you would handle related data deletion
      // For example, deleting user's posts, comments, etc.
      // or implementing a soft delete mechanism

      // Delete user
      final result = await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
      );

      if (result > 0) {
        await logout();
        return true;
      }

      return false;
    } catch (e) {
      print('Delete account error: $e');
      return false;
    }
  }

  Future<bool> isAdmin() async {
    try {
      if (_currentUser == null) {
        return false;
      }

      final db = await DatabaseService().database;

      final List<Map<String, dynamic>> results = await db.query(
        'users',
        columns: ['isAdmin'],
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
      );

      if (results.isNotEmpty) {
        return results.first['isAdmin'] == 1;
      }

      return false;
    } catch (e) {
      print('Admin check error: $e');
      return false;
    }
  }
}
