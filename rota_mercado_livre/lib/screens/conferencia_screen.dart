import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../utils/romaneio_parser.dart';
import '../widgets/app_card.dart';
import '../widgets/sb_sidebar.dart';
import '../theme/sb2.dart';

class ConferenciaScreen extends StatefulWidget {
  const ConferenciaScreen({super.key});
  @override
  State<ConferenciaScreen> createState() => _ConferenciaScreenState();
}

class _ConferenciaScreenState extends State<ConferenciaScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _itens = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _db.getRomaneio();
    setState(() => _itens = items);
  }

  Future<void> _importarPorTexto() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Colar texto do PDF'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            maxLines: 16,
            decoration: const InputDecoration(hintText: 'Cole aqui o conteúdo copiado da tabela do PDF'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Importar')),
        ],
      ),
    );
    if (ok != true) return;
    final text = controller.text;
    final items = RomaneioParser.parseFromText(text);
    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível detectar itens.')));
      return;
    }
    await _db.clearRomaneio();
    await _db.insertRomaneioItemsBulk(items);
    await _load();
  }

  Future<void> _toggle(int id, bool value) async {
    await _db.marcarConferido(id, conferido: value);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _itens.where((e) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return (e['idPacote'] ?? '').toString().toLowerCase().contains(q) ||
          (e['cliente'] ?? '').toString().toLowerCase().contains(q) ||
          (e['endereco'] ?? '').toString().toLowerCase().contains(q) ||
          (e['bairro'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
    final pend = _itens.where((e) => e['status'] == 'pendente').length;
    final conf = _itens.where((e) => e['status'] == 'conferido').length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conferência de Rota'),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer()),
        ),
        actions: [
          IconButton(onPressed: _importarPorTexto, tooltip: 'Importar via texto', icon: const Icon(Icons.paste)),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const SbSidebar(active: 'conferencia'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              borderLeftColor: SB2.primary,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar por pacote, cliente, endereço...'),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Pendentes: $pend  •  Conferidos: $conf', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum item. Toque no ícone de “colar” para importar.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final e = filtrados[i];
                        final checked = e['status'] == 'conferido';
                        return AppCard(
                          borderLeftColor: checked ? SB2.success : SB2.warning,
                          child: Row(
                            children: [
                              Checkbox(value: checked, onChanged: (v) => _toggle(e['id'] as int, v ?? false)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${e['idPacote'] ?? ''} • ${e['cliente'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${e['endereco'] ?? ''}, ${e['numeroEndereco'] ?? ''}${(e['complemento'] ?? '').isNotEmpty ? ' - ${e['complemento']}' : ''}',
                                      style: TextStyle(color: Colors.grey.shade700),
                                    ),
                                    Text('${e['bairro'] ?? ''} • ${e['cidade'] ?? ''} • ${e['cep'] ?? ''}', style: TextStyle(color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importarPorTexto,
        icon: const Icon(Icons.paste),
        label: const Text('Importar texto do PDF'),
      ),
    );
  }
}
