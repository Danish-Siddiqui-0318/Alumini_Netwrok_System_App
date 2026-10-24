import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Adjust this path to wherever auth_palette.dart lives in your project.
import '../theme/auth_palette.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Optional badge counts keyed by tab index, e.g. {3: 2} puts a "2" on
  /// Applications. Missing or zero entries show no badge.
  final Map<int, int> badges;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.badges = const {},
  });

  static const List<IconData> _icons = [
    Icons.home_outlined,
    Icons.people_outline_rounded,
    Icons.work_outline_rounded,
    Icons.assignment_outlined,
    Icons.person_outline_rounded,
  ];

  static const List<IconData> _selectedIcons = [
    Icons.home_rounded,
    Icons.people_rounded,
    Icons.work_rounded,
    Icons.assignment_rounded,
    Icons.person_rounded,
  ];

  static const List<String> _labels = [
    'Home',
    'Alumni',
    'Jobs',
    'Applications',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AuthPalette.ink.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Row(
            children: List.generate(_labels.length, (index) {
              return Expanded(
                child: _NavItem(
                  icon: _icons[index],
                  selectedIcon: _selectedIcons[index],
                  label: _labels[index],
                  selected: currentIndex == index,
                  badgeCount: badges[index] ?? 0,
                  onTap: () {
                    if (index != currentIndex) HapticFeedback.selectionClick();
                    onTap(index);
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(
      selected ? selectedIcon : icon,
      size: 24,
      color: selected ? AuthPalette.brass : AuthPalette.textMuted,
    );

    if (badgeCount > 0) {
      iconWidget = Badge(
        label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
        backgroundColor: selected ? AuthPalette.brass : AuthPalette.error,
        textColor: selected ? AuthPalette.ink : Colors.white,
        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        child: iconWidget,
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The ink "pill" slides in behind the active icon.
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: selected ? 56 : 40,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AuthPalette.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: iconWidget,
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.1,
                color: selected ? AuthPalette.ink : AuthPalette.textMuted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}