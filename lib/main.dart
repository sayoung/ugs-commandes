import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/cart_provider.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: const UgsApp(),
    ),
  );
}

class UgsApp extends StatelessWidget {
  const UgsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UGS Commandes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _hasSession = false;
  int? _clientId;
  String? _clientName;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final session = await AuthService.getSession();
    setState(() {
      _hasSession = session.isNotEmpty;
      _clientId = session['client_id'] != null ? int.tryParse(session['client_id']!) : null;
      _clientName = session['client_name'];
      _loading = false;
    });
  }

  void _onLogout() {
    setState(() {
      _hasSession = false;
      _clientId = null;
      _clientName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_hasSession && _clientId != null) {
      return HomeScreen(
        clientId: _clientId!,
        clientName: _clientName ?? '',
        onLogout: _onLogout,
      );
    }
    return LoginScreen(onLogin: _check);
  }
}
