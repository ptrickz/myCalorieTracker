import "package:flutter/material.dart";
import "../theme.dart";
import "../widgets/app_logo.dart";
import "../widgets/app_toast.dart";
import "login_screen.dart";
import "signup_screen.dart";

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _showComingSoon(BuildContext context, String provider) {
    AppToast.show(context, "$provider sign-in is coming soon — use email for now.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const AppLogo(radius: 36),
              const SizedBox(height: 24),
              const Text(
                "Welcome to MyCalorie",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Select how you'd like to proceed",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const Spacer(),
              _SocialButton(
                label: "Sign In With Google",
                icon: Icons.g_mobiledata,
                background: Colors.white,
                foreground: Colors.black,
                onPressed: () => _showComingSoon(context, "Google"),
              ),
              const SizedBox(height: 12),
              _SocialButton(
                label: "Sign In With Facebook",
                icon: Icons.facebook,
                background: const Color(0xFF1877F2),
                foreground: Colors.white,
                onPressed: () => _showComingSoon(context, "Facebook"),
              ),
              const SizedBox(height: 12),
              _SocialButton(
                label: "Sign In With Email",
                icon: Icons.email_outlined,
                background: AppColors.accent,
                foreground: Colors.black,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ", style: TextStyle(color: AppColors.textSecondary)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    ),
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: foreground),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }
}
