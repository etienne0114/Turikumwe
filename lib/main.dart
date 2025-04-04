import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_theme.dart';
import 'package:turikumwe/screens/splash_screen.dart';
import 'package:turikumwe/services/service_locator.dart';
import 'package:turikumwe/services/database_service.dart'; // Import DatabaseService
import 'package:turikumwe/services/storage_service.dart'; // Import StorageService

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize all services
  await ServiceLocator.init();
  
  // Update the events table schema if needed
  final databaseService = DatabaseService();
  await databaseService.updateEventTableIfNeeded();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ServiceLocator.auth),
        Provider<DatabaseService>(create: (_) => databaseService), // Use the same instance
        Provider<StorageService>(create: (_) => StorageService()), // Create new instance
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turikumwe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}