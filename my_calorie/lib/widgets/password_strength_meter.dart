import "package:flutter/material.dart";
import "../theme.dart";

enum _Strength { empty, weak, medium, strong }

class PasswordStrengthMeter extends StatelessWidget {
  final String password;

  const PasswordStrengthMeter({super.key, required this.password});

  _Strength get _strength {
    if (password.isEmpty) return _Strength.empty;

    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r"[A-Z]").hasMatch(password)) score++;
    if (RegExp(r"[0-9]").hasMatch(password)) score++;
    if (RegExp(r"[^A-Za-z0-9]").hasMatch(password)) score++;

    if (score <= 1) return _Strength.weak;
    if (score <= 2) return _Strength.medium;
    return _Strength.strong;
  }

  @override
  Widget build(BuildContext context) {
    final strength = _strength;
    if (strength == _Strength.empty) return const SizedBox.shrink();

    final (color, label, fraction) = switch (strength) {
      _Strength.weak => (AppColors.error, "Weak. Add more characters", 1 / 3),
      _Strength.medium => (Colors.orange, "Getting there", 2 / 3),
      _Strength.strong => (AppColors.accent, "Strong", 1.0),
      _Strength.empty => (AppColors.border, "", 0.0),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: AppColors.border,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
