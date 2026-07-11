import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "welcome_screen.dart";
import "profile_setup_screen.dart";
import "dashboard_screen.dart";

// Central place that decides where to send the user: Welcome (no/invalid token),
// ProfileSetup (logged in but hasn't entered TDEE inputs yet), or Dashboard.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();

  @override
  void initState() {
    super.initState();
    _decideStartScreen();
  }

  Future<void> _decideStartScreen() async {
    final token = await _authStorage.readToken();
    if (token == null) {
      _goTo(const WelcomeScreen());
      return;
    }

    try {
      final profile = await _apiService.getProfile(token);
      final profileComplete = profile["profileComplete"] as bool;
      _goTo(profileComplete ? const DashboardScreen() : const ProfileSetupScreen());
    } catch (_) {
      await _authStorage.clearToken();
      _goTo(const WelcomeScreen());
    }
  }

  void _goTo(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
