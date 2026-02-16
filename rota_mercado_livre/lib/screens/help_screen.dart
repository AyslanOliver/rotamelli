import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajuda')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Ajuda e suporte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• Para gerar APK, use o comando "flutter build apk --release".'),
            Text('• Navegue pelo menu lateral para acessar as funções.'),
            Text('• Em Configurações, altere tema e cor primária do app.'),
          ],
        ),
      ),
    );
  }
}
