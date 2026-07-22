import "package:calendar_view/calendar_view.dart";
import "package:flutter/material.dart";
import "../theme.dart";

/// Current-week calendar of workout sessions, themed to the app's dark/lime
/// look. Each session shows as an hour-long block at the time it was logged.
///
/// The day columns are made wider than the screen and the grid scrolls
/// horizontally. WeekView's own swipe-paging is disabled (it would fight the
/// horizontal pan, being the same axis); week navigation runs off the custom
/// chevron header instead, via the WeekView state key.
class WorkoutWeekCalendar extends StatefulWidget {
  final List<Map<String, dynamic>> logs;

  const WorkoutWeekCalendar({super.key, required this.logs});

  @override
  State<WorkoutWeekCalendar> createState() => _WorkoutWeekCalendarState();
}

// Kept in sync between the WeekView config and the initial-scroll math.
// Waking/training hours only — trims the dead pre-dawn and post-midnight
// rows. The end stays at 23 so late-evening sessions (the event mapping caps
// them at 22:45) remain visible.
const _calStartHour = 6;
const _calEndHour = 23;
const _calCardHeight = 200.0;
// Custom chevron header (above the grid) and the weekday-titles row (inside
// the grid), each roughly this tall — used to size the scrollable window.
const _calHeaderHeight = 44.0;
const _calWeekTitleHeight = 50.0;
// Height of the scrollable time grid, and how many hours should fill it. The
// per-minute height is derived so exactly that many hours show, so a shorter
// window makes each hour row taller rather than cramming more in.
const _calGridWindow = _calCardHeight - _calHeaderHeight - _calWeekTitleHeight;
const _calVisibleHours = 3;
const _calHeightPerMinute = _calGridWindow / (_calVisibleHours * 60);
// Each day column, and the left time-axis column. Total grid width overflows
// the card, so the grid scrolls horizontally.
const _calDayWidth = 72.0;
const _calTimeLineWidth = 44.0;
const _calContentWidth = _calTimeLineWidth + 7 * _calDayWidth;

class _WorkoutWeekCalendarState extends State<WorkoutWeekCalendar> {
  final _controller = EventController();
  final _weekViewKey = GlobalKey<WeekViewState>();

  // Computed once so rebuilds (e.g. when logs reload) don't snap the view
  // back and fight the user's own scrolling.
  late final double _initialScrollOffset = _computeInitialScrollOffset();

  // Start of the week currently shown; updated on every page change so the
  // custom header's date range stays in sync.
  late DateTime _weekStart = _mondayOf(DateTime.now());

  static DateTime _mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  @override
  void initState() {
    super.initState();
    _syncEvents();
  }

  /// Vertical offset that centres "now" in the visible time grid. The axis
  /// maps minutes-since-startHour to pixels via heightPerMinute; we back off
  /// half the scrollable viewport so the live-time line sits in the middle.
  double _computeInitialScrollOffset() {
    final now = DateTime.now();
    final minutesSinceStart = (now.hour - _calStartHour) * 60 + now.minute;
    final nowPixel = minutesSinceStart * _calHeightPerMinute;
    final offset = nowPixel - _calGridWindow / 2;
    return offset < 0 ? 0 : offset;
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

  String _fmt(DateTime d) => "${d.day} / ${d.month} / ${d.year}";

  Widget _buildHeader() {
    final end = _weekStart.add(const Duration(days: 6));
    return SizedBox(
      height: _calHeaderHeight,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.accent),
            onPressed: () => _weekViewKey.currentState?.previousPage(),
          ),
          Expanded(
            child: Text(
              "${_fmt(_weekStart)} to ${_fmt(end)}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.accent),
            onPressed: () => _weekViewKey.currentState?.nextPage(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: _calCardHeight,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _calContentWidth,
                  child: _buildWeekView(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekView() {
    return WeekView(
      key: _weekViewKey,
      controller: _controller,
      width: _calContentWidth,
      timeLineWidth: _calTimeLineWidth,
      // Own header is hidden; the custom chevron header above drives paging.
      weekPageHeaderBuilder: (_, _) => const SizedBox.shrink(),
      // Same-axis as the horizontal pan — disable swipe so they don't fight;
      // chevrons still page via the state key (programmatic, physics-agnostic).
      pageViewPhysics: const NeverScrollableScrollPhysics(),
      onPageChange: (date, _) => setState(() => _weekStart = date),
      // Without this the calendar applies the app-bar inset published by
      // extendBodyBehindAppBar as blank space above its own header.
      safeAreaOption: const SafeAreaOption(
        top: false,
        bottom: false,
        left: false,
        right: false,
      ),
      initialDay: DateTime.now(),
      scrollOffset: _initialScrollOffset,
      weekTitleHeight: _calWeekTitleHeight,
      showLiveTimeLineInAllDays: true,
      startDay: WeekDays.monday,
      startHour: _calStartHour,
      endHour: _calEndHour,
      heightPerMinute: _calHeightPerMinute,
      backgroundColor: Colors.transparent,
      weekTitleBackgroundColor: Colors.transparent,
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
    );
  }
}
