import "package:calendar_view/calendar_view.dart";
import "package:flutter/material.dart";
import "../theme.dart";

/// Current-week calendar of workout sessions, themed to the app's dark/lime
/// look. Each session shows as an hour-long block at the time it was logged.
class WorkoutWeekCalendar extends StatefulWidget {
  final List<Map<String, dynamic>> logs;

  const WorkoutWeekCalendar({super.key, required this.logs});

  @override
  State<WorkoutWeekCalendar> createState() => _WorkoutWeekCalendarState();
}

class _WorkoutWeekCalendarState extends State<WorkoutWeekCalendar> {
  final _controller = EventController();

  @override
  void initState() {
    super.initState();
    _syncEvents();
  }

  @override
  void didUpdateWidget(WorkoutWeekCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.logs, widget.logs)) _syncEvents();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncEvents() {
    _controller.removeWhere((_) => true);
    _controller.addAll(widget.logs.map(_eventFromLog).toList());
  }

  CalendarEventData _eventFromLog(Map<String, dynamic> log) {
    final loggedAt = DateTime.parse(log["loggedAt"] as String).toLocal();
    final sets =
        (log["sets"] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final exerciseNames = sets
        .map((s) => (s["exercise"] as Map<String, dynamic>)["name"] as String)
        .toSet();
    // Clamp near-midnight sessions so the one-hour block stays inside the day.
    final start = loggedAt.hour >= 23
        ? DateTime(loggedAt.year, loggedAt.month, loggedAt.day, 22, 45)
        : loggedAt;

    return CalendarEventData(
      title: log["venue"] as String,
      description: exerciseNames.isEmpty
          ? "No sets logged"
          : exerciseNames.join(", "),
      date: DateTime(loggedAt.year, loggedAt.month, loggedAt.day),
      startTime: start,
      endTime: start.add(const Duration(hours: 1)),
      color: AppColors.accent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 300,
        child: WeekView(
          controller: _controller,
          initialDay: DateTime.now(),
          showLiveTimeLineInAllDays: true,
          startDay: WeekDays.monday,
          startHour: 5,
          endHour: 24,
          heightPerMinute: 0.5,
          backgroundColor: Colors.transparent,
          weekTitleBackgroundColor: Colors.transparent,
          headerStyle: const HeaderStyle(
            decoration: BoxDecoration(color: Colors.transparent),
            headerTextStyle: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            leftIconConfig: IconDataConfig(color: AppColors.accent, size: 20),
            rightIconConfig: IconDataConfig(color: AppColors.accent, size: 20),
          ),
          weekNumberBuilder: (_) => const SizedBox.shrink(),
          weekDayBuilder: (date) {
            final isToday = DateUtils.isSameDay(date, DateTime.now());
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  const ["M", "T", "W", "T", "F", "S", "S"][date.weekday - 1],
                  style: TextStyle(
                    fontSize: 11,
                    color: isToday ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
                Text(
                  "${date.day}",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday ? AppColors.accent : AppColors.textPrimary,
                  ),
                ),
              ],
            );
          },
          timeLineBuilder: (date) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              "${date.hour.toString().padLeft(2, '0')}:00",
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
              ),
            ),
          ),
          hourIndicatorSettings: const HourIndicatorSettings(
            color: AppColors.border,
            height: 0.5,
          ),
          liveTimeIndicatorSettings: const LiveTimeIndicatorSettings(
            color: AppColors.accent,
          ),
          eventTileBuilder: (date, events, boundary, start, end) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              events.isNotEmpty ? events.first.title : "",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
