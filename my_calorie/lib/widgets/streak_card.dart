import "package:flutter/material.dart";
import "../theme.dart";

class StreakCard extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final bool loggedToday;

  const StreakCard({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.loggedToday,
  });

  @override
  Widget build(BuildContext context) {
    final message = currentStreak == 0
        ? "Log a meal today to start your streak"
        : loggedToday
            ? "Nice — you're on a roll"
            : "Log today to keep your streak alive";

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: AppColors.accent, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$currentStreak day${currentStreak == 1 ? "" : "s"} streak",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            if (longestStreak > currentStreak)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("$longestStreak", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text("best", style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
