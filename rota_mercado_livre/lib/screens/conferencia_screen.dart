import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../utils/romaneio_parser.dart';
import '../widgets/app_card.dart';
import '../widgets/sb_sidebar.dart';
import '../theme/sb2.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'barcode_scan_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ConferenciaScreen extends StatefulWidget {
  const ConferenciaScreen({super.key});
  @override
  State<ConferenciaScreen> createState() => _ConferenciaScreenState();
}

class _ConferenciaScreenState extends State<ConferenciaScreen> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _itens = [];
  String _search = '';
  bool _onlyPendentes = false;
    bool _onlyFaltantes = false;
    bool _onlyConferidos = false;

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

  Future<void> _importarPorPdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    try {
      Uint8List? bytes = res.files.single.bytes;
      final path = res.files.single.path;
      if (bytes == null) {
        final stream = res.files.single.readStream;
        if (stream != null) {
          final b = BytesBuilder();
          await for (final chunk in stream) {
            b.add(chunk);
          }
          bytes = b.takeBytes();
        } else if (path != null) {
          bytes = await File(path).readAsBytes();
        }
      }
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível obter bytes do PDF.')));
        return;
      }
      final doc = PdfDocument(inputBytes: bytes);
      var items = RomaneioParser.parseFromPdf(doc);
      if (items.isEmpty) {
        final text = PdfTextExtractor(doc).extractText();
        final parsed = RomaneioParser.parseFromText(text);
        if (parsed.isNotEmpty) {
          items = parsed;
        }
      }
      doc.dispose();
      if (items.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível detectar itens no PDF.')));
        return;
      }
      await _db.clearRomaneio();
      await _db.insertRomaneioItemsBulk(items);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Importados ${items.length} itens do PDF.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha ao ler PDF: $e')));
    }
  }

  Future<void> _toggle(int id, bool value) async {
    await _db.marcarConferido(id, conferido: value);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _itens.where((e) {
      final statusOk = (!_onlyPendentes || (e['status'] == 'pendente')) &&
          (!_onlyFaltantes || (e['status'] == 'faltante')) &&
          (!_onlyConferidos || (e['status'] == 'conferido'));
      if (_search.isEmpty) return statusOk;
      final q = _search.toLowerCase();
      final matches = (e['numero'] ?? '').toString().toLowerCase().contains(q) ||
          (e['idPacote'] ?? '').toString().toLowerCase().contains(q) ||
          (e['cidade'] ?? '').toString().toLowerCase().contains(q);
      return statusOk && matches;
    }).toList();
    filtrados.sort((a, b) {
      final na = (a['numero'] ?? '').toString();
      final nb = (b['numero'] ?? '').toString();
      int numA = int.tryParse(RegExp(r'^\d+').stringMatch(na) ?? '') ?? 0;
      int numB = int.tryParse(RegExp(r'^\d+').stringMatch(nb) ?? '') ?? 0;
      if (numA != numB) return numA.compareTo(numB);
      final sufA = RegExp(r'^\d+([A-Za-z]*)').firstMatch(na)?.group(1) ?? '';
      final sufB = RegExp(r'^\d+([A-Za-z]*)').firstMatch(nb)?.group(1) ?? '';
      if (sufA != sufB) {
        if (sufA.length != sufB.length) return sufA.length.compareTo(sufB.length);
        final cmp = sufA.compareTo(sufB);
        if (cmp != 0) return cmp;
      }
      return ((a['idPacote'] ?? '') as String).compareTo((b['idPacote'] ?? '') as String);
    });
    final pend = _itens.where((e) => e['status'] == 'pendente').length;
    final conf = _itens.where((e) => e['status'] == 'conferido').length;
    final falt = _itens.where((e) => e['status'] == 'faltante').length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conferência de Rota'),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer()),
        ),
        actions: [
          IconButton(onPressed: _importarPorPdf, tooltip: 'Importar PDF', icon: const Icon(Icons.picture_as_pdf)),
          IconButton(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const BarcodeScanScreen()));
              await _load();
            },
            tooltip: 'Ler código de barras',
            icon: const Icon(Icons.qr_code_scanner),
          ),
          IconButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Limpar tudo'),
                  content: const Text('Apagar todos os itens do romaneio?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar')),
                  ],
                ),
              );
              if (ok == true) {
                await _db.clearRomaneio();
                await _load();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Romaneio limpo.')));
              }
            },
            tooltip: 'Limpar tudo',
            icon: const Icon(Icons.delete_forever),
          ),
          IconButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Limpar conferidos'),
                  content: const Text('Remover todos os itens já conferidos?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Limpar')),
                  ],
                ),
              );
              if (ok == true) {
                await _db.deleteConferidos();
                await _load();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Itens conferidos removidos.')));
              }
            },
            tooltip: 'Limpar conferidos',
            icon: const Icon(Icons.delete_sweep),
          ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChipTheme(
                    data: ChipTheme.of(context).copyWith(
                      labelStyle: const TextStyle(fontSize: 12, color: SB2.text),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      backgroundColor: Colors.white,
                      selectedColor: SB2.divider,
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        FilterChip(
                          selected: _onlyPendentes,
                          label: const Text('Apenas pendentes'),
                          onSelected: (v) => setState(() {
                            _onlyPendentes = v;
                            if (v) {
                              _onlyFaltantes = false;
                              _onlyConferidos = false;
                            }
                          }),
                        ),
                        FilterChip(
                          selected: _onlyFaltantes,
                          label: const Text('Apenas faltantes'),
                          onSelected: (v) => setState(() {
                            _onlyFaltantes = v;
                            if (v) {
                              _onlyPendentes = false;
                              _onlyConferidos = false;
                            }
                          }),
                        ),
                        FilterChip(
                          selected: _onlyConferidos,
                          label: const Text('Apenas conferidos'),
                          onSelected: (v) => setState(() {
                            _onlyConferidos = v;
                            if (v) {
                              _onlyPendentes = false;
                              _onlyFaltantes = false;
                            }
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pendentes: $pend  •  Faltantes: $falt  •  Conferidos: $conf',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SB2.text),
                  ),
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
                        final missing = e['status'] == 'faltante';
                        return AppCard(
                          borderLeftColor: missing ? SB2.danger : (checked ? SB2.success : SB2.warning),
                          child: Row(
                            children: [
                              Checkbox(value: checked, onChanged: (v) => _toggle(e['id'] as int, v ?? false)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Builder(builder: (_) {
                                      final numero = (e['numero'] ?? '').toString().trim();
                                      final id = (e['idPacote'] ?? '').toString().trim();
                                      final cidade = ((e['cidade'] ?? (e['cliente'] ?? ''))).toString().trim();
                                      final cep = (e['cep'] ?? '').toString().trim();
                                      final parts = <String>[];
                                      if (numero.isNotEmpty && id.isNotEmpty) {
                                        parts.add('$numero • $id');
                                      } else {
                                        if (numero.isNotEmpty) parts.add(numero);
                                        if (id.isNotEmpty) parts.add(id);
                                      }
                                      if (cidade.isNotEmpty) parts.add(cidade);
                                      if (cep.isNotEmpty) parts.add(cep);
                                      final title = parts.isEmpty ? id : parts.join(' ');
                                      return Text(
                                        title,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: true,
                                      );
                                    }),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(e['cidade'] ?? '').toString()}',
                                      style: TextStyle(color: Colors.grey.shade700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: true,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Ver detalhes',
                                icon: const Icon(Icons.info_outline),
                                onPressed: () {
                                  showDialog<void>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Detalhes do pacote'),
                                      content: SingleChildScrollView(
                                        child: Builder(builder: (_) {
                                          String fmt(String? s) => (s ?? '').toString().trim().isEmpty ? '—' : (s ?? '').toString().trim();
                                          String compEnd() {
                                            final end = fmt(e['endereco'] as String?);
                                            if (end != '—') return end;
                                            final parts = <String>[];
                                            final bairro = fmt(e['bairro'] as String?);
                                            final cidade = fmt(e['cidade'] as String?);
                                            final cep = fmt(e['cep'] as String?);
                                            if (bairro != '—') parts.add(bairro);
                                            if (cidade != '—') parts.add(cidade);
                                            if (cep != '—') parts.add(cep);
                                            return parts.isEmpty ? '—' : parts.join(' • ');
                                          }
                                          return Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              SelectableText('Endereço: ${compEnd()}'),
                                              SelectableText('Número: ${fmt(e['numeroEndereco'] as String?)}'),
                                              SelectableText('Complemento: ${fmt(e['complemento'] as String?)}'),
                                              SelectableText('Bairro: ${fmt(e['bairro'] as String?)}'),
                                              const SizedBox(height: 8),
                                              SelectableText('Cidade: ${fmt(e['cidade'] as String?)}'),
                                              SelectableText('CEP: ${fmt(e['cep'] as String?)}'),
                                              SelectableText('ID do pacote: ${fmt(e['idPacote'] as String?)}'),
                                            ],
                                          );
                                        }),
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
                                        OutlinedButton(
                                          onPressed: () async {
                                            String fmt(String? s) => (s ?? '').toString().trim();
                                            final end = fmt(e['endereco'] as String?);
                                            final nume = fmt(e['numeroEndereco'] as String?);
                                            final comp = fmt(e['complemento'] as String?);
                                            final bairro = fmt(e['bairro'] as String?);
                                            final cidade = fmt(e['cidade'] as String?);
                                            final cep = fmt(e['cep'] as String?);
                                            final parts = [end, nume, comp, bairro, cidade, cep].where((p) => p.isNotEmpty).toList();
                                            if (parts.isEmpty) {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sem dados suficientes para abrir no Maps.')));
                                              return;
                                            }
                                            final query = parts.join(', ');
                                            final geo = Uri.parse('geo:0,0?q=${Uri.encodeComponent(query)}');
                                            final web = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
                                            try {
                                              if (await canLaunchUrl(geo)) {
                                                await launchUrl(geo, mode: LaunchMode.externalApplication);
                                              } else if (await canLaunchUrl(web)) {
                                                await launchUrl(web, mode: LaunchMode.externalApplication);
                                              } else {
                                                await launchUrl(web, mode: LaunchMode.platformDefault);
                                              }
                                            } catch (_) {
                                              await launchUrl(web, mode: LaunchMode.platformDefault);
                                            }
                                          },
                                          child: const Text('Abrir no Maps'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            final endCtrl = TextEditingController(text: (e['endereco'] ?? '').toString());
                                            final numCtrl = TextEditingController(text: (e['numeroEndereco'] ?? '').toString());
                                            final compCtrl = TextEditingController(text: (e['complemento'] ?? '').toString());
                                            final bairroCtrl = TextEditingController(text: (e['bairro'] ?? '').toString());
                                            final cidadeCtrl = TextEditingController(text: (e['cidade'] ?? '').toString());
                                            final cepCtrl = TextEditingController(text: (e['cep'] ?? '').toString());
                                            final ok = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Editar detalhes'),
                                                content: SingleChildScrollView(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'Endereço')),
                                                      TextField(controller: numCtrl, decoration: const InputDecoration(labelText: 'Número')),
                                                      TextField(controller: compCtrl, decoration: const InputDecoration(labelText: 'Complemento')),
                                                      TextField(controller: bairroCtrl, decoration: const InputDecoration(labelText: 'Bairro')),
                                                      TextField(controller: cidadeCtrl, decoration: const InputDecoration(labelText: 'Cidade')),
                                                      TextField(controller: cepCtrl, decoration: const InputDecoration(labelText: 'CEP')),
                                                    ],
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
                                                ],
                                              ),
                                            );
                                            if (ok == true) {
                                              await _db.atualizarRomaneio(e['id'] as int, {
                                                'endereco': endCtrl.text.trim(),
                                                'numeroEndereco': numCtrl.text.trim(),
                                                'complemento': compCtrl.text.trim(),
                                                'bairro': bairroCtrl.text.trim(),
                                                'cidade': cidadeCtrl.text.trim(),
                                                'cep': cepCtrl.text.trim(),
                                              });
                                              await _load();
                                            }
                                          },
                                          child: const Text('Editar'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: missing ? 'Desmarcar faltante' : 'Marcar faltante',
                                icon: Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: missing ? SB2.danger : Colors.transparent,
                                    border: Border.all(color: missing ? SB2.danger : SB2.secondary),
                                  ),
                                  child: Text(
                                    'F',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: missing ? Colors.white : SB2.text,
                                    ),
                                  ),
                                ),
                                onPressed: () async {
                                  await _db.marcarFaltante(e['id'] as int, faltante: !missing);
                                  await _load();
                                },
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
      floatingActionButton: null,
    );
  }
}
