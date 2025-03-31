// lib/widgets/event_card.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/screens/event_detail_screen.dart';
import 'package:turikumwe/services/service_locator.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final bool isHorizontal;
  final VoidCallback? onAttend;
  final bool showAttendButton;

  const EventCard({
    Key? key,
    required this.event,
    this.isHorizontal = false,
    this.onAttend,
    this.showAttendButton = true,
  }) : super(key: key);

  Future<void> _handleAttend(BuildContext context) async {
    // If a custom onAttend callback is provided, use it
    if (onAttend != null) {
      onAttend!();
      return;
    }

    // Access services through ServiceLocator
    final authService = ServiceLocator.auth;
    
    try {
      // Check if user is logged in
      if (authService.currentUser == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to attend events')),
          );
        }
        return;
      }

      // Navigate to event details
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(event: event),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  // Build the image section with proper error handling
  Widget _buildEventImage() {
    return SizedBox(
      height: isHorizontal ? 120 : 150,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: _buildImageContent(),
      ),
    );
  }

  Widget _buildImageContent() {
    if (event.image == null || event.image!.isEmpty) {
      return Container(
        color: AppColors.primary.withOpacity(0.1),
        child: const Center(
          child: Icon(
            Icons.event,
            color: AppColors.primary,
            size: 40,
          ),
        ),
      );
    }

    // Handle different image sources
    try {
      if (event.image!.startsWith('http')) {
        // Network image
        return Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'event-image-${event.id}',
              child: Image.network(
                event.image!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.primary.withOpacity(0.1),
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: AppColors.primary,
                        size: 40,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (isHorizontal)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
          ],
        );
      } else if (event.image!.startsWith('file://') || event.image!.startsWith('/')) {
        // Local file image
        final imagePath = event.image!.startsWith('file://') 
            ? event.image!.replaceFirst('file://', '') 
            : event.image!;
            
        return Hero(
          tag: 'event-image-${event.id}',
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppColors.primary.withOpacity(0.1),
                child: const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              );
            },
          ),
        );
      } else {
        // Asset image
        return Hero(
          tag: 'event-image-${event.id}',
          child: Image.asset(
            event.image!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppColors.primary.withOpacity(0.1),
                child: const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      // Fallback for any exceptions
      return Container(
        color: AppColors.primary.withOpacity(0.1),
        child: const Center(
          child: Icon(
            Icons.broken_image,
            color: AppColors.primary,
            size: 40,
          ),
        ),
      );
    }
  }

  // Check if event has a price
  bool get _isEventPaid => event.price != null && event.price! > 0;
  
  // Check if event is private
  bool get _isEventPrivate => event.isPrivate ?? false;
  
  // Format the price text
  String get _priceText {
    if (_isEventPaid) {
      return '${event.price!.toStringAsFixed(0)} RWF';
    } else {
      return 'Free';
    }
  }
  
  // Build category/private badge
  Widget _buildEventBadge() {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;
    
    if (_isEventPrivate) {
      badgeColor = Colors.amber;
      badgeText = 'Private';
      badgeIcon = Icons.lock;
    } else if (event.category != null && event.category!.isNotEmpty) {
      badgeColor = AppColors.primary;
      badgeText = event.category!;
      badgeIcon = _getCategoryIcon(event.category);
    } else {
      badgeColor = Colors.teal;
      badgeText = 'Event';
      badgeIcon = Icons.event;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            size: 12,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
  
  // Get icon for category
  IconData _getCategoryIcon(String? category) {
    if (category == null) return Icons.event;
    
    switch (category.toLowerCase()) {
      case 'community':
        return Icons.people;
      case 'education':
        return Icons.school;
      case 'health':
        return Icons.health_and_safety;
      case 'social':
        return Icons.celebration;
      case 'sports':
        return Icons.sports_soccer;
      case 'culture':
        return Icons.theater_comedy;
      case 'business':
        return Icons.business;
      case 'technology':
        return Icons.computer;
      default:
        return Icons.event;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return isHorizontal ? _buildHorizontalCard(context) : _buildVerticalCard(context);
  }

  Widget _buildVerticalCard(BuildContext context) {
    // Check if event is past
    final bool isPastEvent = event.date.isBefore(DateTime.now());
    
    return Card(
      clipBehavior: Clip.antiAlias, // Prevents content from overflowing
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _handleAttend(context),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ensures card only takes space it needs
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event image
            Stack(
              children: [
                _buildEventImage(),
                
                // Past event indicator
                if (isPastEvent)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.4),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Event Ended',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                // Event badge (category or private)
                Positioned(
                  top: 12,
                  left: 12,
                  child: _buildEventBadge(),
                ),
                
                // Price tag
                if (_isEventPaid)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.money, size: 12, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            _priceText,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          DateFormat('E, MMM d • h:mm a').format(event.date),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.district != null 
                              ? '${event.location}, ${event.district}'
                              : event.location,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  // Action row
                  if (showAttendButton) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Attendees count
                        if (event.attendeesIds != null && event.attendeesIds!.isNotEmpty) ...[
                          Text(
                            '${event.attendeesIds!.split(',').where((id) => id.trim().isNotEmpty).length} attending',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'Be the first to join!',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                        
                        // Attend button
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            visualDensity: VisualDensity.compact,
                            foregroundColor: isPastEvent ? Colors.grey : AppColors.primary,
                          ),
                          onPressed: isPastEvent ? null : () => _handleAttend(context),
                          child: Text(isPastEvent ? 'Event Ended' : 'Attend'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalCard(BuildContext context) {
    // Check if event is past
    final bool isPastEvent = event.date.isBefore(DateTime.now());
    
    return SizedBox(
      width: 280,
      child: Card(
        clipBehavior: Clip.antiAlias, // Prevents content from overflowing
        margin: const EdgeInsets.only(right: 16, bottom: 4),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => _handleAttend(context),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ensures card only takes space it needs
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event image with overlay
              Stack(
                children: [
                  _buildEventImage(),
                  
                  // Past event indicator
                  if (isPastEvent)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.4),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Event Ended',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                
                  // Event badge (category or private)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildEventBadge(),
                  ),
                  
                  // Price tag
                  if (_isEventPaid)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.money, size: 12, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              _priceText,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
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
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            DateFormat('E, MMM d • h:mm a').format(event.date),
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.district != null 
                                ? '${event.location}, ${event.district}'
                                : event.location,
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    // Action row
                    if (showAttendButton) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Attendees count
                          if (event.attendeesIds != null && event.attendeesIds!.isNotEmpty) ...[
                            Text(
                              '${event.attendeesIds!.split(',').where((id) => id.trim().isNotEmpty).length} attending',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ] else ...[
                            const Text(
                              'Be the first!',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                          
                          // Attend button
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: isPastEvent ? Colors.grey : AppColors.primary,
                            ),
                            onPressed: isPastEvent ? null : () => _handleAttend(context),
                            child: Text(
                              isPastEvent ? 'Ended' : 'Attend', 
                              style: const TextStyle(fontSize: 12)
                            ),
                          ),
                        ],
                      ),
                    ],
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