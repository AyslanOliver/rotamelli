import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../models/despesa.dart';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'add_rota_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import 'help_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _db = DatabaseHelper();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final list = await _db.getDespesasByMonth(now.year, now.month);
    final rotasCount = await _db.getCountByMonth(now.year, now.month);
    setState(() {
      _despesas = list;
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
      drawer: Drawer(
        width: MediaQuery.of(context).size.width < 600 ? MediaQuery.of(context).size.width * 0.72 : 320,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  children: [
                    const Icon(Icons.dashboard_outlined),
                    const SizedBox(width: 12),
                    Text('Menu', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text('Dashboard'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('Rotas'),
                trailing: rotasCountMes > 0 ? _Badge(count: rotasCountMes) : null,
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('Despesas'),
                selected: true,
                selectedTileColor: Theme.of(context).colorScheme.surfaceVariant,
                trailing: _Badge(count: _despesas.length),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Nova Rota'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddRotaScreen()));
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Relatórios'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Configurações'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Ajuda'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
                },
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
                        return ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text(d.descricao),
                          subtitle: Text('${d.categoria ?? 'Sem categoria'} • $ds'),
                          trailing: Text('R\$ ${d.valor.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
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
