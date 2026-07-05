import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "login_screen.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();
  String? _email;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final token = await _authStorage.readToken();
    if (token == null) {
      _goToLogin();
      return;
    }

    try {
      final me = await _apiService.getMe(token);
      setState(() => _email = me["email"] as String);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _handleLogout() async {
    await _authStorage.clearToken();
    _goToLogin();
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MyCalorie"),
        actions: [
          IconButton(onPressed: _handleLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Center(
        child: _errorMessage != null
            ? Text(_errorMessage!, style: const TextStyle(color: Colors.red))
            : _email == null
                ? const CircularProgressIndicator()
                : Text("Logged in as $_email"),
      ),
    );
  }
}
