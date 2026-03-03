import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../utils/api_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pin = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  final _db = DatabaseHelper();
  String _msg = '';

  Future<void> _doLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _msg = ''; });
    try {
      final base = await _db.getSetting('api_base_url') ?? 'https://rota-ml-cloudflare-api.ayslano37.workers.dev';
      final api = ApiService(base);
      final res = await api.login(_email.text.trim(), _pin.text.trim());
      if ((res['ok'] ?? false) != true || (res['token'] ?? '').toString().isEmpty) {
        setState(() { _msg = (res['error'] ?? 'Falha no login').toString(); });
      } else {
        await _db.setSetting('auth_token', res['token']);
        await _db.setSetting('user_email', (res['user']?['email'] ?? '').toString());
        await _db.setSetting('user_name', (res['user']?['name'] ?? '').toString());
        await _db.setSetting('user_role', (res['user']?['role'] ?? '').toString());
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      }
    } catch (e) {
      setState(() { _msg = 'Erro: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o e-mail' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pin,
                decoration: const InputDecoration(labelText: 'PIN', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
                obscureText: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o PIN' : null,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _doLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('Entrar'),
                ),
              ),
              if (_msg.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_msg, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
