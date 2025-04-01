// lib/widgets/event_calendar_view.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/screens/event_detail_screen.dart';
import 'package:turikumwe/services/database_service.dart';

class EventCalendarView extends StatefulWidget {
  final List<Event> events;
  final ValueChanged<DateTime>? onDaySelected;

  const EventCalendarView({
    Key? key,
    required this.events,
    this.onDaySelected,
  }) : super(key: key);

  @override
  State<EventCalendarView> createState() => _EventCalendarViewState();
}

class _EventCalendarViewState extends State<EventCalendarView> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late Map<DateTime, List<Event>> _eventsByDay;

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _eventsByDay = _groupEventsByDay(widget.events);
  }

  @override
  void didUpdateWidget(EventCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.events != oldWidget.events) {
      setState(() {
        _eventsByDay = _groupEventsByDay(widget.events);
      });
    }
  }

  Map<DateTime, List<Event>> _groupEventsByDay(List<Event> events) {
    final grouped = <DateTime, List<Event>>{};

    for (final event in events) {
      try {
        // Normalize the date (strip time) to ensure consistent comparison
        final date = DateTime(
          event.date.year,
          event.date.month,
          event.date.day,
        );

        // If this is the first event for this date, initialize the list
        if (grouped[date] == null) {
          grouped[date] = [];
        }

        // Add the event to its date
        grouped[date]!.add(event);

        // Debug output
        final formattedDate =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        debugPrint('Grouped event "${event.title}" to $formattedDate');
      } catch (e) {
        debugPrint('Error grouping event: $e');
      }
    }

    return grouped;
  }

  List<Event> _getEventsForDay(DateTime day) {
    // Normalize the date by removing time component
    final date = DateTime(day.year, day.month, day.day);

    // Check if we have events for this date in our map
    final events = _eventsByDay[date] ?? [];

    // If no events found in the map, search through all events manually as a fallback
    if (events.isEmpty) {
      final manuallyFound = widget.events.where((event) {
        final eventDate = DateTime(
          event.date.year,
          event.date.month,
          event.date.day,
        );
        return eventDate.year == date.year &&
            eventDate.month == date.month &&
            eventDate.day == date.day;
      }).toList();

      if (manuallyFound.isNotEmpty) {
        debugPrint(
            'Found ${manuallyFound.length} events for ${date.toIso8601String()} through manual search');
        return manuallyFound;
      }
    }

    debugPrint(
        'Found ${events.length} events for ${date.toIso8601String()} in the map');
    return events;
  }

  @override
  Widget build(BuildContext context) {
    // Print events for debugging
    debugPrint('EventCalendarView - Total events: ${widget.events.length}');

    // Map of dates to event counts for debugging
    final Map<String, int> eventCountsByDay = {};
    for (final event in widget.events) {
      final date = DateFormat('yyyy-MM-dd').format(DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      ));
      eventCountsByDay[date] = (eventCountsByDay[date] ?? 0) + 1;
    }

    // Print event counts by day for debugging
    eventCountsByDay.forEach((date, count) {
      debugPrint('Events on $date: $count');
    });

    // Rebuild the events map
    _eventsByDay = _groupEventsByDay(widget.events);

    return Column(
      children: [
        TableCalendar<Event>(
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 365 * 2)),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          eventLoader: _getEventsForDay,
          selectedDayPredicate: (day) {
            return isSameDay(_selectedDay, day);
          },
          onDaySelected: (selectedDay, focusedDay) {
            debugPrint(
                'Day selected: ${DateFormat('yyyy-MM-dd').format(selectedDay)}');
            final eventsCount = _getEventsForDay(selectedDay).length;
            debugPrint('Events for selected day: $eventsCount');

            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });

            if (widget.onDaySelected != null) {
              widget.onDaySelected!(selectedDay);
            }
          },
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() {
                _calendarFormat = format;
              });
            }
          },
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
          },
          calendarStyle: CalendarStyle(
            markerDecoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            // Additional style customizations
            weekendTextStyle: const TextStyle(color: Colors.red),
            outsideDaysVisible: false,
            markersMaxCount: 3,
          ),
          headerStyle: HeaderStyle(
            formatButtonTextStyle: const TextStyle(color: AppColors.primary),
            formatButtonDecoration: BoxDecoration(
              border: Border.all(color: AppColors.primary),
              borderRadius: BorderRadius.circular(16),
            ),
            titleCentered: true,
            titleTextStyle:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        _buildEventList(),
      ],
    );
  }

  Widget _buildEventList() {
    // Get events for the selected day
    final eventsForSelectedDay = _getEventsForDay(_selectedDay);
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    // Log for debugging
    debugPrint('Building event list for ${dateFormat.format(_selectedDay)}');
    debugPrint('Events found for this day: ${eventsForSelectedDay.length}');

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Events for ${dateFormat.format(_selectedDay)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Text(
                  '${eventsForSelectedDay.length} event${eventsForSelectedDay.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Event List
          Expanded(
            child: eventsForSelectedDay.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No events scheduled for this day',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: eventsForSelectedDay.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final event = eventsForSelectedDay[index];
                      return _buildEventTile(event);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(Event event) {
    final timeFormat = DateFormat('h:mm a');
    final isEventPast = event.date.isBefore(DateTime.now());

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor:
            isEventPast ? Colors.grey[300] : AppColors.primary.withOpacity(0.2),
        child: Icon(
          Icons.event,
          color: isEventPast ? Colors.grey : AppColors.primary,
        ),
      ),
      title: Text(
        event.title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isEventPast ? Colors.grey : Colors.black,
          decoration: isEventPast ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${timeFormat.format(event.date)} • ${event.location}',
            style: TextStyle(
              color: isEventPast ? Colors.grey : null,
            ),
          ),
          if (event.price != null && event.price! > 0)
            Text(
              '${event.price!.toStringAsFixed(0)} RWF',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.arrow_forward_ios, size: 16),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(event: event),
            ),
          );
        },
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(event: event),
          ),
        );
      },
    );
  }
}
