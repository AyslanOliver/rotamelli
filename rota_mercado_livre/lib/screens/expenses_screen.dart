import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../models/despesa.dart';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'add_rota_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import 'help_screen.dart';
import '../widgets/app_card.dart';
import '../widgets/sb_sidebar.dart';

enum QuinzenaFilter { full, first, second }

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  DateTime? _data;
  String? _categoria;
  late DatabaseHelper _db;
  List<Despesa> _despesas = [];
  int rotasCountMes = 0;
  int mesAtual = DateTime.now().month;
  int anoAtual = DateTime.now().year;
  QuinzenaFilter _filter = QuinzenaFilter.full;
  double _totalPeriodo = 0.0;

  @override
  void initState() {
    super.initState();
    _db = DatabaseHelper();
    _load();
  }

  Future<void> _load() async {
    List<Despesa> list;
    double total;
    if (_filter == QuinzenaFilter.full) {
      list = await _db.getDespesasByMonth(anoAtual, mesAtual);
      total = await _db.getSumDespesasByMonth(anoAtual, mesAtual);
    } else {
      final firstStart = DateTime(anoAtual, mesAtual, 1);
      final firstEnd = DateTime(anoAtual, mesAtual, 15);
      final secondStart = DateTime(anoAtual, mesAtual, 16);
      final secondEnd = DateTime(anoAtual, mesAtual + 1, 0);
      final start = _filter == QuinzenaFilter.first ? firstStart : secondStart;
      final end = _filter == QuinzenaFilter.first ? firstEnd : secondEnd;
      list = await _db.getDespesasByDateRange(start, end);
      total = await _db.getSumDespesasByDateRange(start, end);
    }
    final rotasCount = await _db.getCountByMonth(anoAtual, mesAtual);
    setState(() {
      _despesas = list;
      _totalPeriodo = total;
      rotasCountMes = rotasCount;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        _data = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_data == null) return;
    final valor = double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0.0;
    final d = Despesa(
      descricao: _descricaoController.text.trim(),
      valor: valor,
      dataDespesa: _data!,
      categoria: _categoria,
    );
    await _db.insertDespesa(d);
    _descricaoController.clear();
    _valorController.clear();
    setState(() {
      _data = null;
      _categoria = null;
    });
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Despesa salva')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Despesas'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      drawer: SbSidebar(active: 'despesas', rotasCount: rotasCountMes, despesasCount: _despesas.length),
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
            const SizedBox(height: 8),
            AppCard(
              borderLeftColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL DO PERÍODO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                        const SizedBox(height: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Text(
                            'R\$ ${_totalPeriodo.toStringAsFixed(2)}',
                            key: ValueKey(_totalPeriodo.toStringAsFixed(2)),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.receipt_long, color: Colors.black38, size: 28),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _descricaoController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Informe a descrição' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _valorController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (double.tryParse((v ?? '').replaceAll(',', '.')) ?? 0) > 0 ? null : 'Informe um valor válido',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: InputDecoration(
                      labelText: 'Data',
                      border: const OutlineInputBorder(),
                      suffixText: _data != null ? '${_data!.day.toString().padLeft(2, '0')}/${_data!.month.toString().padLeft(2, '0')}/${_data!.year}' : null,
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    validator: (_) => _data == null ? 'Selecione a data' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _categoria,
                    items: const [
                      DropdownMenuItem(value: 'Combustível', child: Text('Combustível')),
                      DropdownMenuItem(value: 'Alimentação', child: Text('Alimentação')),
                      DropdownMenuItem(value: 'Manutenção', child: Text('Manutenção')),
                      DropdownMenuItem(value: 'Outros', child: Text('Outros')),
                    ],
                    onChanged: (v) => setState(() => _categoria = v),
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _despesas.isEmpty
                  ? const Center(child: Text('Sem despesas no mês'))
                  : ListView.separated(
                      itemCount: _despesas.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final d = _despesas[index];
                        final ds = '${d.dataDespesa.day.toString().padLeft(2, '0')}/${d.dataDespesa.month.toString().padLeft(2, '0')}/${d.dataDespesa.year}';
                        return AppCard(
                          child: ListTile(
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

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
