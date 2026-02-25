import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../models/rota.dart';
import '../utils/calculo_valor.dart';
import '../utils/api_service.dart';
import 'home_screen.dart';
import 'add_rota_screen.dart';
import 'expenses_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import 'help_screen.dart';
import '../widgets/app_card.dart';
import '../widgets/sb_sidebar.dart';
 
enum QuinzenaFilter { full, first, second }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DatabaseHelper _dbHelper;
  int mesAtual = DateTime.now().month;
  int anoAtual = DateTime.now().year;
  double totalMes = 0.0;
  int quantidadeMes = 0;
  double despesasMes = 0.0;
  double netMes = 0.0;
  double primeiraQuinzenaRotas = 0.0;
  double primeiraQuinzenaDespesas = 0.0;
  double primeiraQuinzenaNet = 0.0;
  double segundaQuinzenaRotas = 0.0;
  double segundaQuinzenaDespesas = 0.0;
  double segundaQuinzenaNet = 0.0;
  int primeiraQuinzenaPacotesTotais = 0;
  int primeiraQuinzenaPacotesVulso = 0;
  int segundaQuinzenaPacotesTotais = 0;
  int segundaQuinzenaPacotesVulso = 0;
  int despesasCountMes = 0;
  double avulsoValorMes = 0.0;
  List<Rota> recentes = [];
  QuinzenaFilter _filter = QuinzenaFilter.full;
  double _periodRotas = 0.0;
  double _periodDespesas = 0.0;
  int _periodRotasCount = 0;

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper();
    _loadData();
  }

  Future<void> _loadData() async {
    final firstStart = DateTime(anoAtual, mesAtual, 1);
    final firstEnd = DateTime(anoAtual, mesAtual, 15);
    final secondStart = DateTime(anoAtual, mesAtual, 16);
    final secondEnd = DateTime(anoAtual, mesAtual + 1, 0);
    final results = await Future.wait([
      _dbHelper.getSumValorByMonth(anoAtual, mesAtual), // 0
      _dbHelper.getCountByMonth(anoAtual, mesAtual), // 1
      _dbHelper.getSumDespesasByMonth(anoAtual, mesAtual), // 2
      _dbHelper.getCountDespesasByMonth(anoAtual, mesAtual), // 3
      _dbHelper.getSumPacotesVulsoByMonth(anoAtual, mesAtual), // 4
      _dbHelper.getSumRotasByDateRange(firstStart, firstEnd), // 5
      _dbHelper.getSumRotasByDateRange(secondStart, secondEnd), // 6
      _dbHelper.getSumDespesasByDateRange(firstStart, firstEnd), // 7
      _dbHelper.getSumDespesasByDateRange(secondStart, secondEnd), // 8
      _dbHelper.getSumQuantidadePacotesByDateRange(firstStart, firstEnd), // 9
      _dbHelper.getSumQuantidadePacotesByDateRange(secondStart, secondEnd), // 10
      _dbHelper.getSumPacotesVulsoByDateRange(firstStart, firstEnd), // 11
      _dbHelper.getSumPacotesVulsoByDateRange(secondStart, secondEnd), // 12
    ]);
    final total = results[0] as double;
    final count = results[1] as int;
    final despesasTotal = results[2] as double;
    final despesasCount = results[3] as int;
    final vulsoMes = results[4] as int;
    final rotasFirst = results[5] as double;
    final rotasSecond = results[6] as double;
    final despesasFirst = results[7] as double;
    final despesasSecond = results[8] as double;
    final pacotesFirst = results[9] as int;
    final pacotesSecond = results[10] as int;
    final vulsoFirst = results[11] as int;
    final vulsoSecond = results[12] as int;
    double avulsoRemoto = avulsoValorMes;
    try {
      final apiBase = await _dbHelper.getSetting('api_base_url');
      if (apiBase != null && apiBase.isNotEmpty) {
        final api = ApiService(apiBase);
        final remote = await api.getAvulsoMes(anoAtual, mesAtual);
        if (remote != null) avulsoRemoto = remote;
      }
    } catch (_) {}
    DateTime pStart, pEnd;
    if (_filter == QuinzenaFilter.full) {
      pStart = firstStart;
      pEnd = secondEnd;
    } else if (_filter == QuinzenaFilter.first) {
      pStart = firstStart;
      pEnd = firstEnd;
    } else {
      pStart = secondStart;
      pEnd = secondEnd;
    }
    final pResults = await Future.wait([
      _dbHelper.getSumRotasByDateRange(pStart, pEnd),
      _dbHelper.getSumDespesasByDateRange(pStart, pEnd),
      _dbHelper.getRotasByDateRange(pStart, pEnd),
    ]);
    final periodRotas = pResults[0] as double;
    final periodDespesas = pResults[1] as double;
    final periodList = pResults[2] as List<Rota>;
    periodList.sort((a, b) => b.dataRota.compareTo(a.dataRota));
    final recents = periodList.take(5).toList();
    setState(() {
      totalMes = total;
      quantidadeMes = count;
      despesasMes = despesasTotal;
      netMes = totalMes - despesasMes;
      avulsoValorMes = avulsoRemoto > 0 ? avulsoRemoto : vulsoMes * CalculoValor.valorPacoteVulso;
      despesasCountMes = despesasCount;
      primeiraQuinzenaRotas = rotasFirst;
      primeiraQuinzenaDespesas = despesasFirst;
      primeiraQuinzenaNet = rotasFirst - despesasFirst;
      segundaQuinzenaNet = rotasSecond - despesasSecond;
      primeiraQuinzenaPacotesTotais = pacotesFirst;
      segundaQuinzenaPacotesTotais = pacotesSecond;
      primeiraQuinzenaPacotesVulso = vulsoFirst;
      segundaQuinzenaPacotesVulso = vulsoSecond;
      recentes = recents;
      _periodRotas = periodRotas;
      _periodDespesas = periodDespesas;
      _periodRotasCount = periodList.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        actions: [
          const Icon(Icons.notifications_none),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: SbSidebar(active: 'dashboard', rotasCount: quantidadeMes, despesasCount: despesasCountMes),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: RefreshIndicator(
          onRefresh: _loadData,
          displacement: 80,
          edgeOffset: 8,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      _loadData();
                    },
                  ),
                  ChoiceChip(
                    label: const Text('1ª quinzena'),
                    selected: _filter == QuinzenaFilter.first,
                    onSelected: (s) {
                      if (!s) return;
                      setState(() => _filter = QuinzenaFilter.first);
                      _loadData();
                    },
                  ),
                  ChoiceChip(
                    label: const Text('2ª quinzena'),
                    selected: _filter == QuinzenaFilter.second,
                    onSelected: (s) {
                      if (!s) return;
                      setState(() => _filter = QuinzenaFilter.second);
                      _loadData();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Resumo do período', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      'Rotas: ${CalculoValor.formatarMoeda(_periodRotas)} • Despesas: ${CalculoValor.formatarMoeda(_periodDespesas)} • Qtd: $_periodRotasCount',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  // Paleta SB Admin 2
                  // primary #4E73DF, secondary #858796, danger #E74A3B,
                  // success #1CC88A, info #36B9CC, warning #F6C23E
                  _MetricCard(
                    title: _filter == QuinzenaFilter.full ? 'Total do mês' : 'Total do período',
                    value: _filter == QuinzenaFilter.full ? totalMes : _periodRotas,
                    color: const Color(0xFF4E73DF),
                    icon: Icons.attach_money,
                  ),
                  _CountCard(
                    title: _filter == QuinzenaFilter.full ? 'Rotas no mês' : 'Rotas no período',
                    count: _filter == QuinzenaFilter.full ? quantidadeMes : _periodRotasCount,
                    color: const Color(0xFF858796),
                    icon: Icons.route,
                  ),
                  _MetricCard(
                    title: _filter == QuinzenaFilter.full ? 'Despesas do mês' : 'Despesas do período',
                    value: _filter == QuinzenaFilter.full ? despesasMes : _periodDespesas,
                    color: const Color(0xFFE74A3B),
                    icon: Icons.receipt_long,
                  ),
                  _MetricCard(
                    title: _filter == QuinzenaFilter.full ? 'Resultado do mês' : 'Resultado do período',
                    value: (_filter == QuinzenaFilter.full ? netMes : (_periodRotas - _periodDespesas)),
                    color: (_filter == QuinzenaFilter.full ? netMes : (_periodRotas - _periodDespesas)) >= 0
                        ? const Color(0xFF1CC88A)
                        : const Color(0xFFE74A3B),
                    icon: Icons.assessment,
                  ),
                  _MetricCard(title: r'Avulso (R$)', value: avulsoValorMes, color: const Color(0xFF36B9CC), icon: Icons.local_shipping),
                  _MetricCard(title: '1ª quinzena', value: primeiraQuinzenaNet, color: const Color(0xFFF6C23E), icon: Icons.timeline),
                  _MetricCard(title: '2ª quinzena', value: segundaQuinzenaNet, color: const Color(0xFF4E73DF), icon: Icons.timeline),
                  _PacotesCard(title: 'Pacotes 1ª quinzena', total: primeiraQuinzenaPacotesTotais, vulso: primeiraQuinzenaPacotesVulso, color: const Color(0xFFF6C23E)),
                  _PacotesCard(title: 'Pacotes 2ª quinzena', total: segundaQuinzenaPacotesTotais, vulso: segundaQuinzenaPacotesVulso, color: const Color(0xFF4E73DF)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddRotaScreen()));
                        _loadData();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Nova Rota'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                        _loadData();
                      },
                      icon: const Icon(Icons.list),
                      label: const Text('Ver Rotas'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen()));
                        _loadData();
                      },
                      icon: const Icon(Icons.money_off),
                      label: const Text('Despesas'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('RECENTES',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Color(0xFF4E73DF),
                  )),
              const SizedBox(height: 8),
              AppCard(
                child: recentes.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('Sem rotas recentes', style: TextStyle(color: Colors.grey.shade600))),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recentes.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final r = recentes[index];
                          return ListTile(
                            leading: const Icon(Icons.route),
                            title: Text(r.nomeRota),
                            subtitle: Text('${r.dataRota.toLocal()} • ${r.tipoVeiculo}'),
                            trailing: Text(CalculoValor.formatarMoeda(r.valorCalculado), style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final double value;
  final Color color;
  final IconData icon;
  const _MetricCard({required this.title, required this.value, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
      borderRadius: BorderRadius.circular(8),
      child: AppCard(
        borderLeftColor: color,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700, letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      CalculoValor.formatarMoeda(value),
                      key: ValueKey(value.toStringAsFixed(2)),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(message: title, child: Icon(icon, color: Colors.black.withValues(alpha: 0.25), size: 28)),
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  const _CountCard({required this.title, required this.count, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
      borderRadius: BorderRadius.circular(8),
      child: AppCard(
        borderLeftColor: color,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700, letterSpacing: 0.6)),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text('$count', key: ValueKey(count), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Tooltip(message: title, child: Icon(icon, color: Colors.black.withValues(alpha: 0.25), size: 28)),
          ],
        ),
      ),
    );
  }
}

class _PacotesCard extends StatelessWidget {
  final String title;
  final int total;
  final int vulso;
  final Color color;
  const _PacotesCard({required this.title, required this.total, required this.vulso, required this.color});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
      borderRadius: BorderRadius.circular(8),
      child: AppCard(
        borderLeftColor: color,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700, letterSpacing: 0.6)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Text(
                            'Totais: $total',
                            key: ValueKey('tot_$total'),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: Container(
                          key: ValueKey('v_$vulso'),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('Vulso: $vulso'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.local_shipping_outlined, color: Colors.black38, size: 28),
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
