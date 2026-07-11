import "package:flutter/material.dart";
import "../theme.dart";
import "../widgets/primary_button.dart";

class PasswordResetSentScreen extends StatelessWidget {
  final String email;

  const PasswordResetSentScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.mark_email_read_outlined, color: Colors.black, size: 44),
              ),
              const SizedBox(height: 32),
              const Text(
                "Password Reset Sent!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "We've sent a password reset link to $email containing further instructions.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const Spacer(),
              PrimaryButton(
                label: "Back to Sign In",
                onPressed: () {
                  // Dismiss this screen and the Forgot Password screen beneath it,
                  // landing back on the Sign In screen that started this flow.
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
