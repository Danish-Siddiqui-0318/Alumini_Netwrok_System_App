import 'package:flutter/material.dart';

import '../theme/auth_palette.dart';

/// Turns the raw `createdAt` string from the API into friendly text.
class PostTime {
  PostTime._();

  /// Set to false if the API sends local server time (no "Z" or offset) and
  /// posts show the wrong hours.
  static const bool serverSendsUtc = true;

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _monthsFull = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Parses the API string into the user's local time, or null if invalid.
  static DateTime? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;

    // Strings with "Z" or an offset (+05:00) are already parsed as UTC.
    if (parsed.isUtc) return parsed.toLocal();

    // No timezone in the string.
    if (serverSendsUtc) {
      return DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
      ).toLocal();
    }
    return parsed;
  }

  static String _time(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// "Just now", "5 min ago", "3h ago", "Yesterday at 3:42 PM",
  /// "Mon at 3:42 PM", "24 Oct at 3:42 PM", "24 Oct 2025".
  static String relative(String? raw, {DateTime? now}) {
    final date = parse(raw);
    if (date == null) return raw ?? '';

    final current = now ?? DateTime.now();
    final diff = current.difference(date);

    // Also covers small clock differences where the post looks "in the future".
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';

    final today = DateTime(current.year, current.month, current.day);
    final postDay = DateTime(date.year, date.month, date.day);
    final dayDiff = today.difference(postDay).inDays;

    if (dayDiff == 1) return 'Yesterday at ${_time(date)}';
    if (dayDiff < 7) {
      final name = _weekdays[date.weekday - 1].substring(0, 3);
      return '$name at ${_time(date)}';
    }
    if (date.year == current.year) {
      return '${date.day} ${_months[date.month - 1]} at ${_time(date)}';
    }
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  /// "Saturday, 24 October 2026 · 3:42 PM"
  static String full(String? raw) {
    final date = parse(raw);
    if (date == null) return raw ?? '';

    return '${_weekdays[date.weekday - 1]}, ${date.day} '
        '${_monthsFull[date.month - 1]} ${date.year} · ${_time(date)}';
  }
}

/// Small clock icon + friendly time. Tap it to see the full date.
class PostTimeLabel extends StatelessWidget {
  const PostTimeLabel({super.key, required this.createdAt});

  final String? createdAt;

  @override
  Widget build(BuildContext context) {
    if (createdAt == null || createdAt!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.schedule_rounded,
          size: 13,
          color: AuthPalette.textMuted,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            PostTime.relative(createdAt),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AuthPalette.textMuted,
            ),
          ),
        ),
      ],
    );

    // If the string could not be parsed there is no full date to show.
    if (PostTime.parse(createdAt) == null) return label;

    return Tooltip(
      message: PostTime.full(createdAt),
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 3),
      decoration: BoxDecoration(
        color: AuthPalette.ink,
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      child: label,
    );
  }
}