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
      final date = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );
      
      if (grouped[date] == null) {
        grouped[date] = [];
      }
      
      grouped[date]!.add(event);
    }
    
    return grouped;
  }

  List<Event> _getEventsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _eventsByDay[date] ?? [];
  }

  @override
  Widget build(BuildContext context) {
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
            if (!isSameDay(_selectedDay, selectedDay)) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              
              if (widget.onDaySelected != null) {
                widget.onDaySelected!(selectedDay);
              }
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
            _focusedDay = focusedDay;
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
          ),
          headerStyle: HeaderStyle(
            formatButtonTextStyle: const TextStyle(color: AppColors.primary),
            formatButtonDecoration: BoxDecoration(
              border: Border.all(color: AppColors.primary),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildEventList(),
      ],
    );
  }

  Widget _buildEventList() {
    final eventsForSelectedDay = _getEventsForDay(_selectedDay);
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Events for ${dateFormat.format(_selectedDay)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        
        if (eventsForSelectedDay.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
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
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: eventsForSelectedDay.length,
            itemBuilder: (context, index) {
              final event = eventsForSelectedDay[index];
              return _buildEventTile(event);
            },
          ),
      ],
    );
  }

  Widget _buildEventTile(Event event) {
    final timeFormat = DateFormat('h:mm a');
    final isEventPast = event.date.isBefore(DateTime.now());
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: isEventPast 
            ? Colors.grey[300] 
            : AppColors.primary.withOpacity(0.2),
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