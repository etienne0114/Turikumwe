// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/screens/auth/login_screen.dart';
import 'package:turikumwe/screens/profile/edit_profile_screen.dart';
import 'package:turikumwe/screens/profile/change_password_screen.dart';
import 'package:turikumwe/services/auth_service.dart';
import 'package:turikumwe/services/theme_service.dart';
import 'package:turikumwe/services/notification_service.dart';
import 'package:turikumwe/services/localization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _language = 'English';
  String _appVersion = '1.0.0';
  bool _isLoading = false;
  
  final List<String> _languages = [
    'English',
    'Kinyarwanda',
    'French',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      // Fallback to default version
      setState(() {
        _appVersion = '1.0.0';
      });
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      
      // Load theme setting
      final themeService = Provider.of<ThemeService>(context, listen: false);
      final isDarkMode = themeService.isDarkMode;
      
      // Load language setting
      final localizationService = Provider.of<LocalizationService>(context, listen: false);
      final currentLanguage = localizationService.currentLanguage;
      
      // Load notification setting
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      final areNotificationsEnabled = notificationService.areNotificationsEnabled;
      
      setState(() {
        _notificationsEnabled = areNotificationsEnabled;
        _darkModeEnabled = isDarkMode;
        _language = currentLanguage;
        _isLoading = false;
      });
    } catch (e) {
      // If services are not available, fall back to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
        _language = prefs.getString('language') ?? 'English';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() {
      _darkModeEnabled = value;
    });
    
    try {
      // Update theme service
      final themeService = Provider.of<ThemeService>(context, listen: false);
      await themeService.setDarkMode(value);
    } catch (e) {
      // Fallback to SharedPreferences if service is not available
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode_enabled', value);
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    
    try {
      // Update notification service
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      await notificationService.setNotificationsEnabled(value);
      
      if (value) {
        // Request notification permissions if enabling
        await notificationService.requestPermissions();
      }
    } catch (e) {
      // Fallback to SharedPreferences if service is not available
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', value);
    }
  }

  Future<void> _changeLanguage(String language) async {
    if (language == _language) return;
    
    setState(() {
      _language = language;
    });
    
    try {
      // Update localization service
      final localizationService = Provider.of<LocalizationService>(context, listen: false);
      await localizationService.setLanguage(language);
      
      // Show language change confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Language changed to $language'),
          ),
        );
      }
    } catch (e) {
      // Fallback to SharedPreferences if service is not available
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', language);
    }
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfileScreen(),
      ),
    );
  }

  void _navigateToChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChangePasswordScreen(),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await Provider.of<AuthService>(context, listen: false).deleteAccount();
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
          ),
        );
        _logout();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete account. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _logout() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await Provider.of<AuthService>(context, listen: false).logout();
      
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch $url'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(
                title: 'General',
                children: [
                  _buildSwitchTile(
                    title: 'Dark Mode',
                    subtitle: 'Enable dark theme',
                    value: _darkModeEnabled,
                    onChanged: _toggleDarkMode,
                  ),
                  _buildLanguageDropdown(),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Notifications',
                children: [
                  _buildSwitchTile(
                    title: 'Enable Notifications',
                    subtitle: 'Receive updates about activity',
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'About',
                children: [
                  ListTile(
                    title: const Text('About Turikumwe'),
                    subtitle: const Text('Learn more about the app'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showAboutDialog();
                    },
                  ),
                  ListTile(
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showPolicyDialog('Privacy Policy');
                    },
                  ),
                  ListTile(
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showPolicyDialog('Terms of Service');
                    },
                  ),
                  ListTile(
                    title: const Text('Visit Website'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () {
                      _launchURL('https://turikumwe.rw');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Account',
                children: [
                  ListTile(
                    title: const Text('Edit Profile'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _navigateToEditProfile,
                  ),
                  ListTile(
                    title: const Text('Change Password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _navigateToChangePassword,
                  ),
                  ListTile(
                    title: const Text('Logout'),
                    trailing: const Icon(Icons.exit_to_app),
                    onTap: () => _showLogoutConfirmation(),
                  ),
                  ListTile(
                    title: const Text('Delete Account'),
                    textColor: Colors.red,
                    trailing: const Icon(Icons.delete_forever, color: Colors.red),
                    onTap: () {
                      _showDeleteAccountConfirmation();
                    },
                  ),
                ],
              ),
            ],
          ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About Turikumwe'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Turikumwe is a community app designed to unite Rwandans by connecting people across districts and backgrounds.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Version: $_appVersion',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('© 2025 Turikumwe. All rights reserved.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showPolicyDialog(String title) {
    final bool isPolicyPolicy = title == 'Privacy Policy';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isPolicyPolicy
                      ? 'This privacy policy outlines how we collect and use your data when you use the Turikumwe app.'
                      : 'These terms of service govern your use of the Turikumwe app and services.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'This is a placeholder for the complete policy content. In a real app, this would contain the full policy text.',
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Launch to full policy on website
                    Navigator.of(context).pop();
                    _launchURL(isPolicyPolicy
                        ? 'https://turikumwe.rw/privacy'
                        : 'https://turikumwe.rw/terms');
                  },
                  child: const Text('View Full Policy Online'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }

  Widget _buildLanguageDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Language',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Select your preferred language',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: _language,
            items: _languages.map((language) {
              return DropdownMenuItem(
                value: language,
                child: Text(language),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                _changeLanguage(newValue);
              }
            },
          ),
        ],
      ),
    );
  }
}