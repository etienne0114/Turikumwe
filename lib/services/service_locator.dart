// lib/services/service_locator.dart
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/database_service.dart';
import 'package:turikumwe/services/storage_service.dart';

class ServiceLocator {
  static final DatabaseService _databaseService = DatabaseService();
  static final StorageService _storageService = StorageService();
  static final AuthService _authService = AuthService();

  static DatabaseService get database => _databaseService;
  static StorageService get storage => _storageService;
  static AuthService get auth => _authService;

  static Future<void> init() async {
    // Initialize database first
    await _databaseService.initDatabase();
     await _authService.init();
    
    // Other initializations can be added here
    // await _authService.initialize();
    // await _storageService.initialize();
  }

  static void dispose() {
    _storageService.dispose();
    // Add other cleanup methods as needed
  }
}