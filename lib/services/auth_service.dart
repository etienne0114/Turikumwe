// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:turikumwe/models/user.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:crypto/crypto.dart';

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final DatabaseService _databaseService = DatabaseService();
  User? _currentUser;
  bool _isAuthenticated = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;

  /// Initialize the authentication service
  Future<void> init() async {
    try {
      final userJson = await _storage.read(key: 'user');
      if (userJson != null) {
        _currentUser = User.fromMap(jsonDecode(userJson));
        _isAuthenticated = true;
        notifyListeners();
        
        // Verify the user still exists in the database
        final userExists = await _verifyUserExists(_currentUser!.id);
        if (!userExists) {
          await _clearAuthState();
        }
      }
    } catch (e, stackTrace) {
      developer.log(
        'Auth initialization error',
        error: e,
        stackTrace: stackTrace,
        name: 'AuthService',
      );
      await _clearAuthState();
    }
  }

  Future<bool> _verifyUserExists(int userId) async {
    try {
      final user = await _databaseService.getUserById(userId);
      return user != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> _clearAuthState() async {
    await _storage.delete(key: 'user');
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  /// Hash a password using SHA-256 with salt
  String _hashPassword(String password, {String? salt}) {
    final saltToUse = salt ?? _currentUser?.email ?? 'default_salt';
    final bytes = utf8.encode('$password$saltToUse');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Register a new user
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // Validate input
      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        return AuthResult.failure('All fields are required');
      }

      if (password.length < 8) {
        return AuthResult.failure('Password must be at least 8 characters');
      }

      // Check if user already exists
      final existingUser = await _databaseService.getUserByEmail(email);
      if (existingUser != null) {
        return AuthResult.failure('Email already in use');
      }

      final hashedPassword = _hashPassword(password, salt: email);
      final now = DateTime.now().toIso8601String();

      final userId = await _databaseService.insertUser({
        'name': name,
        'email': email,
        'password': hashedPassword,
        'createdAt': now,
        'updatedAt': now,
      });

      if (userId <= 0) {
        return AuthResult.failure('Failed to create user');
      }

      final user = await _databaseService.getUserById(userId);
      if (user == null) {
        return AuthResult.failure('Failed to retrieve created user');
      }

      await _setAuthState(user);
      return AuthResult.success();
    } catch (e, stackTrace) {
      developer.log(
        'Registration error',
        error: e,
        stackTrace: stackTrace,
        name: 'AuthService',
      );
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  /// Log in a user
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        return AuthResult.failure('Email and password are required');
      }

      final hashedPassword = _hashPassword(password, salt: email);
      final db = await _databaseService.database;

      final results = await db.query(
        'users',
        where: 'email = ? AND password = ?',
        whereArgs: [email, hashedPassword],
        limit: 1,
      );

      if (results.isEmpty) {
        return AuthResult.failure('Invalid email or password');
      }

      final user = User.fromMap(results.first);
      await _setAuthState(user);

      // Update last login time
      await db.update(
        'users',
        {'updatedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [user.id],
      );

      return AuthResult.success();
    } catch (e, stackTrace) {
      developer.log(
        'Login error',
        error: e,
        stackTrace: stackTrace,
        name: 'AuthService',
      );
      return AuthResult.failure('Login failed. Please try again.');
    }
  }

  Future<void> _setAuthState(User user) async {
    _currentUser = user;
    _isAuthenticated = true;
    await _storage.write(key: 'user', value: jsonEncode(user.toMap()));
    notifyListeners();
  }

  /// Log out the current user
  Future<void> logout() async {
    try {
      await _clearAuthState();
    } catch (e, stackTrace) {
      developer.log(
        'Logout error',
        error: e,
        stackTrace: stackTrace,
        name: 'AuthService',
      );
      // Ensure we're logged out even if storage fails
      _currentUser = null;
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  Future<AuthResult> updateProfile(Map<String, dynamic> userData) async {
    try {
      if (_currentUser == null) {
        return AuthResult.failure('Not authenticated');
      }

      // Don't allow updating sensitive fields directly
      userData.remove('password');
      userData.remove('isAdmin');

      userData['id'] = _currentUser!.id;
      userData['updatedAt'] = DateTime.now().toIso8601String();

      final result = await _databaseService.updateUser(userData);
      if (result <= 0) {
        return AuthResult.failure('Failed to update profile');
      }

      final updatedUser = await _databaseService.getUserById(_currentUser!.id);
      if (updatedUser == null) {
        return AuthResult.failure('Failed to fetch updated profile');
      }

      await _setAuthState(updatedUser);
      return AuthResult.success();
    } catch (e, stackTrace) {
      developer.log(
        'Profile update error',
        error: e,
        stackTrace: stackTrace,
        name: 'AuthService',
      );
      return AuthResult.failure('Failed to update profile');
    }
  }

  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (_currentUser == null) {
        return AuthResult.failure('Not authenticated');
      }

      if (newPassword.length < 8) {
        return AuthResult.failure('New password must be at least 8 characters');
      }

      final hashedCurrentPassword = _hashPassword(
        currentPassword,
        salt: _currentUser!.email,
      );
      final db = await _databaseService.database;

      // Verify current password
      final results = await db.query(
        'users',
        where: 'id = ? AND password = ?',
        whereArgs: [_currentUser!.id, hashedCurrentPassword],
        limit: 1,
      );

      if (results.isEmpty) {
        return AuthResult.failure('Current password is incorrect');
      }

      // Update password
      final hashedNewPassword = _hashPassword(
        newPassword,
        salt: _currentUser!.email,
      );
      final result = await db.update(
        'users',
        {
          'password': hashedNewPassword,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
      );

      if (result <= 0) {
        return AuthResult.failure('Failed to update password');
      }

      return AuthResult.success();
    } catch (e, stackTrace) {
      developer.log(
        'Password change error',
        error: e,
        stackTrace: stackTrace,
        name: 'AuthService',
      );
      return AuthResult.failure('Failed to change password');
    }
  }

  Future<AuthResult> deleteAccount() async {
    try {
      if (_currentUser == null) {
        return AuthResult.failure('Not authenticated');
      }

      // In a production app, you would:
      // 1. First soft-delete or mark for deletion
      // 2. Clean up related data
      // 3. Then hard delete after some period

      final db = await _databaseService.database;
      final result = await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
      );

      if (result <= 0) {
        return AuthResult.failure('Failed to delete account');
      }

      await logout();
      return AuthResult.success();
    } catch (e, stackTrace) {
      developer.log(
        'Account deletion error',
        error: e,
        stackTrace: stackTrace,
        name: 'AuthService',
      );
      return AuthResult.failure('Failed to delete account');
    }
  }

  Future<bool> isAdmin() async {
    try {
      if (_currentUser == null) return false;

      final db = await _databaseService.database;
      final results = await db.query(
        'users',
        columns: ['isAdmin'],
        where: 'id = ?',
        whereArgs: [_currentUser!.id],
        limit: 1,
      );

      return results.isNotEmpty && results.first['isAdmin'] == 1;
    } catch (e, stackTrace) {
      developer.log(
        'Admin check error',
        error: e,
        stackTrace: stackTrace,
        name: 'AuthService',
      );
      return false;
    }
  }
}

class AuthResult {
  final bool success;
  final String? errorMessage;

  AuthResult._({required this.success, this.errorMessage});

  factory AuthResult.success() => AuthResult._(success: true);
  factory AuthResult.failure(String message) => 
      AuthResult._(success: false, errorMessage: message);
}