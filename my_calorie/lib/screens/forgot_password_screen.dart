import "package:flutter/material.dart";
import "../theme.dart";
import "../widgets/app_text_field.dart";
import "../widgets/primary_button.dart";
import "password_reset_sent_screen.dart";

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleSend() async {
    setState(() => _isLoading = true);
    // No password-reset endpoint exists on the backend yet, so this just
    // shows the confirmation screen without actually sending anything.
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PasswordResetSentScreen(email: _emailController.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.lock_outline, color: Colors.black, size: 32),
            ),
            const SizedBox(height: 24),
            const Text("Forgot Password", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              "Please enter your email address to reset your password.",
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            AppTextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              placeholder: "Enter your email address...",
              prefix: const Icon(Icons.mail_outline, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: "Send Reset Link", isLoading: _isLoading, onPressed: _handleSend),
          ],
        ),
      ),
    );
  }
}
