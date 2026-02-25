import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../models/despesa.dart';
import '../models/rota.dart';
import '../widgets/app_card.dart';

enum QuinzenaFilter { full, first, second }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = DatabaseHelper();
  QuinzenaFilter _filter = QuinzenaFilter.full;
  int mesAtual = DateTime.now().month;
  int anoAtual = DateTime.now().year;
  double _totalRotas = 0.0;
  double _totalDespesas = 0.0;
  int _countRotas = 0;
  int _countDespesas = 0;
  int _sumPacotes = 0;
  int _sumVulso = 0;
  List<Despesa> _despesas = [];
  List<Rota> _rotas = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    DateTime start, end;
    final firstStart = DateTime(anoAtual, mesAtual, 1);
    final firstEnd = DateTime(anoAtual, mesAtual, 15);
    final secondStart = DateTime(anoAtual, mesAtual, 16);
    final secondEnd = DateTime(anoAtual, mesAtual + 1, 0);
    if (_filter == QuinzenaFilter.full) {
      start = firstStart;
      end = secondEnd;
    } else if (_filter == QuinzenaFilter.first) {
      start = firstStart;
      end = firstEnd;
    } else {
      start = secondStart;
      end = secondEnd;
    }
    final rotas = await _db.getRotasByDateRange(start, end);
    final despesas = await _db.getDespesasByDateRange(start, end);
    final totalRotas = await _db.getSumRotasByDateRange(start, end);
    final totalDespesas = await _db.getSumDespesasByDateRange(start, end);
    final sumPacotes = await _db.getSumQuantidadePacotesByDateRange(start, end);
    final sumVulso = await _db.getSumPacotesVulsoByDateRange(start, end);
    setState(() {
      _rotas = rotas;
      _despesas = despesas;
      _totalRotas = totalRotas;
      _totalDespesas = totalDespesas;
      _countRotas = rotas.length;
      _countDespesas = despesas.length;
      _sumPacotes = sumPacotes;
      _sumVulso = sumVulso;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Mês inteiro'),
                  selected: _filter == QuinzenaFilter.full,
                  onSelected: (s) {
                    if (!s) return;
                    setState(() => _filter = QuinzenaFilter.full);
                    _load();
                  },
                ),
                ChoiceChip(
                  label: const Text('1ª quinzena'),
                  selected: _filter == QuinzenaFilter.first,
                  onSelected: (s) {
                    if (!s) return;
                    setState(() => _filter = QuinzenaFilter.first);
                    _load();
                  },
                ),
                ChoiceChip(
                  label: const Text('2ª quinzena'),
                  selected: _filter == QuinzenaFilter.second,
                  onSelected: (s) {
                    if (!s) return;
                    setState(() => _filter = QuinzenaFilter.second);
                    _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(8),
                    child: AppCard(
                      borderLeftColor: Theme.of(context).colorScheme.primary,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TOTAL ROTAS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                                const SizedBox(height: 6),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  child: Text('R\$ ${_totalRotas.toStringAsFixed(2)}', key: ValueKey(_totalRotas.toStringAsFixed(2)), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 6),
                                Text('Qtd. rotas: $_countRotas', style: TextStyle(color: Colors.grey.shade700)),
                              ],
                            ),
                          ),
                          const Icon(Icons.attach_money, color: Colors.black38, size: 28),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(8),
                    child: AppCard(
                      borderLeftColor: Theme.of(context).colorScheme.error,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TOTAL DESPESAS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                                const SizedBox(height: 6),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  child: Text('R\$ ${_totalDespesas.toStringAsFixed(2)}', key: ValueKey(_totalDespesas.toStringAsFixed(2)), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 6),
                                Text('Qtd. despesas: $_countDespesas', style: TextStyle(color: Colors.grey.shade700)),
                              ],
                            ),
                          ),
                          const Icon(Icons.receipt_long, color: Colors.black38, size: 28),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    borderLeftColor: Theme.of(context).colorScheme.secondary,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PACOTES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                              const SizedBox(height: 6),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 350),
                                child: Text('Totais: $_sumPacotes', key: ValueKey(_sumPacotes), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 4),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 350),
                                child: Text('Vulso: $_sumVulso', key: ValueKey(_sumVulso)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.local_shipping_outlined, color: Colors.black38, size: 28),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCard(
                    child: Row(
                      children: const [
                        Icon(Icons.calendar_today),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Período', style: TextStyle(fontSize: 14)),
                              SizedBox(height: 8),
                              Text('Relatório por quinzena', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _despesas.isEmpty
                  ? const Center(child: Text('Sem despesas no período'))
                  : ListView.separated(
                      itemCount: _despesas.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final d = _despesas[index];
                        final ds = '${d.dataDespesa.day.toString().padLeft(2, '0')}/${d.dataDespesa.month.toString().padLeft(2, '0')}/${d.dataDespesa.year}';
                        return ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text(d.descricao),
                          subtitle: Text('${d.categoria ?? 'Sem categoria'} • $ds'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('R\$ ${d.valor.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await _editDespesa(d);
                                  } else if (value == 'delete') {
                                    await _deleteDespesa(d);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                                  PopupMenuItem(value: 'delete', child: Text('Excluir')),
                                ],
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
    );
  }

  Future<void> _editDespesa(Despesa d) async {
    final descricaoController = TextEditingController(text: d.descricao);
    final valorController = TextEditingController(text: d.valor.toStringAsFixed(2));
    DateTime data = d.dataDespesa;
    String? categoria = d.categoria;
    final localFormKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Editar despesa'),
              content: SingleChildScrollView(
                child: Form(
                  key: localFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: descricaoController,
                        decoration: const InputDecoration(labelText: 'Descrição'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Informe a descrição' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: valorController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Valor'),
                        validator: (v) => (double.tryParse((v ?? '').replaceAll(',', '.')) ?? 0) > 0 ? null : 'Informe um valor válido',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Data'),
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: data,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                    locale: const Locale('pt', 'BR'),
                                  );
                                  if (picked != null) {
                                    setStateDialog(() {
                                      data = picked;
                                    });
                                  }
                                },
                                child: Text('${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: categoria,
                        items: const [
                          DropdownMenuItem(value: 'Combustível', child: Text('Combustível')),
                          DropdownMenuItem(value: 'Alimentação', child: Text('Alimentação')),
                          DropdownMenuItem(value: 'Manutenção', child: Text('Manutenção')),
                          DropdownMenuItem(value: 'Outros', child: Text('Outros')),
                        ],
                        onChanged: (v) => setStateDialog(() {
                          categoria = v;
                        }),
                        decoration: const InputDecoration(labelText: 'Categoria'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () async {
                    if (!localFormKey.currentState!.validate()) return;
                    final valor = double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0.0;
                    final updated = Despesa(
                      id: d.id,
                      descricao: descricaoController.text.trim(),
                      valor: valor,
                      dataDespesa: data,
                      categoria: categoria,
                    );
                    await _db.updateDespesa(updated);
                    await _load();
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Despesa atualizada')));
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteDespesa(Despesa d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir despesa'),
        content: Text('Deseja excluir "${d.descricao}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirm == true) {
      if (d.id != null) {
        await _db.deleteDespesa(d.id!);
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Despesa excluída')));
      }
    }
  }
}
