// lib/widgets/event_card.dart
import 'dart:io'; // Add this import for File class

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/screens/event_detail_screen.dart';
import 'package:turikumwe/services/service_locator.dart';
import 'package:turikumwe/services/auth_service.dart'; // Add this import for AuthService

class EventCard extends StatelessWidget {
  final Event event;
  final bool isHorizontal;

  const EventCard({
    Key? key,
    required this.event,
    this.isHorizontal = false,
  }) : super(key: key);

  Future<void> _handleAttend(BuildContext context) async {
    // Access services through ServiceLocator
    final storageService = ServiceLocator.storage;
    final authService = ServiceLocator.auth; // Changed from context.read<AuthService>()
    
    try {
      // Example: Upload image if needed (though in this case we're just navigating)
      if (event.image != null && event.image!.startsWith('file://')) {
        final imageFile = File(event.image!.replaceFirst('file://', ''));
        final imageUrl = await storageService.uploadImage(imageFile);
        if (imageUrl != null) {
          // Update event with new URL if needed
        }
      }

      // Example: Check if user is logged in
      if (authService.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to attend events')),
        );
        return;
      }

      // Navigate to event details
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventDetailScreen(event: event),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('E, MMM d • h:mm a');
    
    return isHorizontal ? _buildHorizontalCard(context) : _buildVerticalCard(context);
  }

  Widget _buildVerticalCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _handleAttend(context),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event image - updated to use NetworkImage if URL exists
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                image: event.image != null
                    ? DecorationImage(
                        image: event.image!.startsWith('http')
                            ? NetworkImage(event.image!)
                            : AssetImage(event.image!) as ImageProvider,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: event.image == null
                  ? const Center(
                      child: Icon(
                        Icons.event,
                        color: AppColors.primary,
                        size: 40,
                      ),
                    )
                  : null,
            ),
            
            // Event info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('E, MMM d • h:mm a').format(event.date),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: const TextStyle(color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        label: const Text(
                          'RSVP Required',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _handleAttend(context),
                        child: const Text('Attend'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalCard(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => _handleAttend(context),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event image - updated to use NetworkImage if URL exists
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  image: event.image != null
                      ? DecorationImage(
                          image: event.image!.startsWith('http')
                              ? NetworkImage(event.image!)
                              : AssetImage(event.image!) as ImageProvider,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: event.image == null
                    ? const Center(
                        child: Icon(
                          Icons.event,
                          color: AppColors.primary,
                          size: 40,
                        ),
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            DateFormat('E, MMM d').format(event.date),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
              ),
              
              // Event info
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.grey),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            event.location,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                          label: const Text(
                            'RSVP',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _handleAttend(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Attend'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}