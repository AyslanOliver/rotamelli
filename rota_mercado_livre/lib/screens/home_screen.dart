import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../models/rota.dart';
import '../utils/database_helper.dart';
import '../utils/calculo_valor.dart';
import 'add_rota_screen.dart';
import '../widgets/rota_card.dart';
import 'settings_screen.dart';
import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'reports_screen.dart';
import 'help_screen.dart';
import '../widgets/app_card.dart';

enum QuinzenaFilter { full, first, second }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DatabaseHelper _dbHelper;
  List<Rota> rotas = [];
  double totalMes = 0.0;
  int mesAtual = DateTime.now().month;
  int anoAtual = DateTime.now().year;
  int despesasCountMes = 0;
  QuinzenaFilter _filter = QuinzenaFilter.full;

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper();
    _loadRotas();
  }

  void _loadRotas() async {
    List<Rota> mesRotas;
    double total;
    if (_filter == QuinzenaFilter.full) {
      mesRotas = await _dbHelper.getRotasByMonth(anoAtual, mesAtual);
      total = await _dbHelper.getSumValorByMonth(anoAtual, mesAtual);
    } else {
      final firstStart = DateTime(anoAtual, mesAtual, 1);
      final firstEnd = DateTime(anoAtual, mesAtual, 15);
      final secondStart = DateTime(anoAtual, mesAtual, 16);
      final secondEnd = DateTime(anoAtual, mesAtual + 1, 0);
      final start = _filter == QuinzenaFilter.first ? firstStart : secondStart;
      final end = _filter == QuinzenaFilter.first ? firstEnd : secondEnd;
      mesRotas = await _dbHelper.getRotasByDateRange(start, end);
      total = await _dbHelper.getSumRotasByDateRange(start, end);
    }
    final despesasCount = await _dbHelper.getCountDespesasByMonth(anoAtual, mesAtual);

    setState(() {
      rotas = mesRotas;
      totalMes = total;
      despesasCountMes = despesasCount;
    });
  }

  void _deleteRota(int id) async {
    await _dbHelper.deleteRota(id);
    _loadRotas();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rota deletada com sucesso!')),
    );
  }

  void _showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Tem certeza que deseja deletar esta rota?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              _deleteRota(id);
              Navigator.pop(context);
            },
            child: const Text('Deletar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _changeMes(int direction) {
    setState(() {
      mesAtual += direction;
      if (mesAtual > 12) {
        mesAtual = 1;
        anoAtual++;
      } else if (mesAtual < 1) {
        mesAtual = 12;
        anoAtual--;
      }
    });
    _loadRotas();
  }

  Future<void> _pickMesAno() async {
    final picked = await showMonthPicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDate: DateTime(anoAtual, mesAtual),
    );
    if (picked != null) {
      setState(() {
        anoAtual = picked.year;
        mesAtual = picked.month;
      });
      _loadRotas();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM yyyy', 'pt_BR');
    final currentDate = DateTime(anoAtual, mesAtual);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciador de Rotas'),
        centerTitle: true,
        elevation: 2,
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
                selected: true,
                selectedTileColor: Theme.of(context).colorScheme.surfaceVariant,
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('Despesas'),
                trailing: despesasCountMes > 0 ? _Badge(count: despesasCountMes) : null,
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Nova Rota'),
                trailing: _Badge(count: rotas.length),
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
      body: Column(
        children: [
          // Header com mês/ano e navegação
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Navegação de mês
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => _changeMes(-1),
                    ),
                    TextButton.icon(
                      onPressed: _pickMesAno,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        dateFormat.format(currentDate),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => _changeMes(1),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Mês inteiro'),
                      selected: _filter == QuinzenaFilter.full,
                      onSelected: (s) {
                        if (!s) return;
                        setState(() => _filter = QuinzenaFilter.full);
                        _loadRotas();
                      },
                    ),
                    ChoiceChip(
                      label: const Text('1ª quinzena'),
                      selected: _filter == QuinzenaFilter.first,
                      onSelected: (s) {
                        if (!s) return;
                        setState(() => _filter = QuinzenaFilter.first);
                        _loadRotas();
                      },
                    ),
                    ChoiceChip(
                      label: const Text('2ª quinzena'),
                      selected: _filter == QuinzenaFilter.second,
                      onSelected: (s) {
                        if (!s) return;
                        setState(() => _filter = QuinzenaFilter.second);
                        _loadRotas();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Total do mês
                AppCard(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Color.alphaBlend(Colors.black.withValues(alpha: 0.05), Theme.of(context).colorScheme.primaryContainer),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total do Mês:',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: Text(
                          CalculoValor.formatarMoeda(totalMes),
                          key: ValueKey<double>(totalMes),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Lista de rotas
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadRotas(),
              child: rotas.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.35,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Nenhuma rota cadastrada',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: 180,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AddRotaScreen(),
                                      ),
                                    );
                                    _loadRotas();
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Cadastrar rota'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: rotas.length,
                      itemBuilder: (context, index) {
                        return RotaCard(
                          rota: rotas[index],
                          onDelete: () => _showDeleteDialog(rotas[index].id!),
                          onEdit: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AddRotaScreen(rota: rotas[index]),
                              ),
                            );
                            _loadRotas();
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddRotaScreen()),
          );
          _loadRotas();
        },
        child: const Icon(Icons.add),
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
