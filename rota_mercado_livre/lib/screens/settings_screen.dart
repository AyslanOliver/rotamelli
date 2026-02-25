import 'package:flutter/material.dart';
import '../main.dart';
import '../utils/database_helper.dart';
import '../utils/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiController = TextEditingController();
  late DatabaseHelper _db;
  static const _defaultApi = 'https://rota-ml-cloudflare-api.ayslano37.workers.dev';
  bool _exporting = false;
  double _progress = 0.0;
  String _progressLabel = '';
  @override
  void initState() {
    super.initState();
    _db = DatabaseHelper();
    _load();
  }

  Future<void> _load() async {
    final api = await _db.getSetting('api_base_url');
    setState(() {
      _apiController.text = (api == null || api.isEmpty) ? _defaultApi : api;
    });
    if (api == null || api.isEmpty) {
      await _db.setSetting('api_base_url', _defaultApi);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seed = appThemeController.seed;
    final mode = appThemeController.mode;
    final colors = [
      const Color(0xFF1769AA),
      const Color(0xFF0D47A1),
      const Color(0xFF1E88E5),
      const Color(0xFF2E7D32),
      const Color(0xFF6A1B9A),
      const Color(0xFFB71C1C),
      const Color(0xFFEF6C00),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            SwitchListTile(
              title: const Text('Modo escuro'),
              value: mode == ThemeMode.dark,
              onChanged: (v) {
                appThemeController.setMode(v ? ThemeMode.dark : ThemeMode.light);
              },
            ),
            const SizedBox(height: 16),
            const Text('Cor primária'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: colors.map((c) {
                final selected = c.value == seed.value;
                return GestureDetector(
                  onTap: () => appThemeController.setSeed(c),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: selected ? const Icon(Icons.check, color: Colors.white) : null,
                  ),
                );
              }).toList(),
            ),
            Text('API Base URL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            TextField(
              controller: _apiController,
              decoration: const InputDecoration(
                labelText: 'Ex: https://seu-backend.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link_outlined),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _db.setSetting('api_base_url', _apiController.text.trim());
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conexão salva localmente')));
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final base = _apiController.text.trim().isNotEmpty ? _apiController.text.trim() : (await _db.getSetting('api_base_url') ?? '');
                      if (base.isEmpty) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe a API Base URL')));
                        return;
                      }
                      try {
                        final ok = await ApiService(base).ping();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'API acessível' : 'API indisponível')));
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao verificar: $e')));
                      }
                    },
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('Testar API (Cloudflare)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exporting
                        ? null
                        : () async {
                      final base = _apiController.text.trim().isNotEmpty ? _apiController.text.trim() : (await _db.getSetting('api_base_url') ?? '');
                      if (base.isEmpty) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe a API Base URL')));
                        return;
                      }
                      try {
                        setState(() {
                          _exporting = true;
                          _progress = 0.0;
                          _progressLabel = 'Iniciando';
                        });
                        final res = await _db.exportAllToCloudflare(
                          baseUrl: base,
                          onProgress: (p, label) {
                            if (!mounted) return;
                            setState(() {
                              _progress = p;
                              _progressLabel = label;
                            });
                          },
                        );
                        if (!mounted) return;
                        setState(() {
                          _exporting = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Importados: rotas ${res['imported']?['rotas'] ?? 0}, despesas ${res['imported']?['despesas'] ?? 0}')));
                      } catch (e) {
                        if (!mounted) return;
                        setState(() {
                          _exporting = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao importar para Cloudflare: $e')));
                      }
                    },
                    icon: const Icon(Icons.cloud_done_outlined),
                    label: const Text('Exportar dados locais para Cloudflare D1'),
                  ),
                ),
              ],
            ),
            if (_exporting) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: _progress == 0.0 ? null : _progress),
                  const SizedBox(height: 8),
                  Text(_progressLabel),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
