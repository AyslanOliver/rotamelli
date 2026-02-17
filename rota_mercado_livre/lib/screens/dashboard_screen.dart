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
    final total = await _dbHelper.getSumValorByMonth(anoAtual, mesAtual);
    final count = await _dbHelper.getCountByMonth(anoAtual, mesAtual);
    final recents = await _dbHelper.getRecentRotasByMonth(anoAtual, mesAtual, limit: 5);
    final despesasTotal = await _dbHelper.getSumDespesasByMonth(anoAtual, mesAtual);
    final despesasCount = await _dbHelper.getCountDespesasByMonth(anoAtual, mesAtual);
    final vulsoMes = await _dbHelper.getSumPacotesVulsoByMonth(anoAtual, mesAtual);
    final firstStart = DateTime(anoAtual, mesAtual, 1);
    final firstEnd = DateTime(anoAtual, mesAtual, 15);
    final secondStart = DateTime(anoAtual, mesAtual, 16);
    final secondEnd = DateTime(anoAtual, mesAtual + 1, 0);
    final rotasFirst = await _dbHelper.getSumRotasByDateRange(firstStart, firstEnd);
    final rotasSecond = await _dbHelper.getSumRotasByDateRange(secondStart, secondEnd);
    final despesasFirst = await _dbHelper.getSumDespesasByDateRange(firstStart, firstEnd);
    final despesasSecond = await _dbHelper.getSumDespesasByDateRange(secondStart, secondEnd);
    final pacotesFirst = await _dbHelper.getSumQuantidadePacotesByDateRange(firstStart, firstEnd);
    final pacotesSecond = await _dbHelper.getSumQuantidadePacotesByDateRange(secondStart, secondEnd);
    final vulsoFirst = await _dbHelper.getSumPacotesVulsoByDateRange(firstStart, firstEnd);
    final vulsoMesLocal = await _dbHelper.getSumPacotesVulsoByMonth(anoAtual, mesAtual);
    double avulsoRemoto = avulsoValorMes;
    try {
      final apiBase = await _dbHelper.getSetting('api_base_url');
      if (apiBase != null && apiBase.isNotEmpty) {
        final api = ApiService(apiBase);
        final remote = await api.getAvulsoMes(anoAtual, mesAtual);
        if (remote != null) avulsoRemoto = remote;
      }
    } catch (_) {}
    final vulsoSecond = await _dbHelper.getSumPacotesVulsoByDateRange(secondStart, secondEnd);
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
    final periodRotas = await _dbHelper.getSumRotasByDateRange(pStart, pEnd);
    final periodDespesas = await _dbHelper.getSumDespesasByDateRange(pStart, pEnd);
    final periodRotasCount = (await _dbHelper.getRotasByDateRange(pStart, pEnd)).length;
    setState(() {
      totalMes = total;
      quantidadeMes = count;
      despesasMes = despesasTotal;
      netMes = totalMes - despesasMes;
      avulsoValorMes = avulsoRemoto > 0 ? avulsoRemoto : vulsoMesLocal * CalculoValor.valorPacoteVulso;
      despesasCountMes = despesasCount;
      avulsoValorMes = vulsoMes * CalculoValor.valorPacoteVulso;
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
      _periodRotasCount = periodRotasCount;
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
                    Text('Rota Mercado Livre', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text('Dashboard'),
                selected: true,
                selectedTileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('Rotas'),
                trailing: quantidadeMes > 0 ? _Badge(count: quantidadeMes) : null,
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                  _loadData();
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('Despesas'),
                trailing: despesasCountMes > 0 ? _Badge(count: despesasCountMes) : null,
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen()));
                  _loadData();
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Nova Rota'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddRotaScreen()));
                  _loadData();
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
        child: SingleChildScrollView(
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
                  _MetricCard(title: 'Total do mês', value: totalMes, color: Theme.of(context).colorScheme.primaryContainer),
                  _CountCard(title: 'Rotas no mês', count: quantidadeMes, color: Theme.of(context).colorScheme.secondaryContainer),
                  _MetricCard(title: 'Despesas do mês', value: despesasMes, color: Theme.of(context).colorScheme.errorContainer),
                  _MetricCard(title: 'Resultado do mês', value: netMes, color: Theme.of(context).colorScheme.tertiaryContainer),
                  _MetricCard(title: r'Avulso (R$)', value: avulsoValorMes, color: Theme.of(context).colorScheme.secondaryContainer),
                  _MetricCard(title: '1ª quinzena', value: primeiraQuinzenaNet, color: Theme.of(context).colorScheme.primaryContainer),
                  _MetricCard(title: '2ª quinzena', value: segundaQuinzenaNet, color: Theme.of(context).colorScheme.secondaryContainer),
                  _PacotesCard(title: 'Pacotes 1ª quinzena', total: primeiraQuinzenaPacotesTotais, vulso: primeiraQuinzenaPacotesVulso, color: Theme.of(context).colorScheme.surfaceContainerHighest),
                  _PacotesCard(title: 'Pacotes 2ª quinzena', total: segundaQuinzenaPacotesTotais, vulso: segundaQuinzenaPacotesVulso, color: Theme.of(context).colorScheme.tertiaryContainer),
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
              Text(
                'Recentes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
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
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final double value;
  final Color color;
  const _MetricCard({required this.title, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final textColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
    final g = LinearGradient(
      colors: [
        color,
        Color.alphaBlend(Colors.black.withValues(alpha: 0.05), color),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
      borderRadius: BorderRadius.circular(8),
      child: AppCard(
        gradient: g,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color.alphaBlend(Colors.white.withValues(alpha: 0.2), color),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.attach_money, color: textColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textColor, fontSize: 14)),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                    child: Text(
                      CalculoValor.formatarMoeda(value),
                      key: ValueKey(value.toStringAsFixed(2)),
                      style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 600),
                        builder: (context, t, _) {
                          return Container(
                            width: constraints.maxWidth * t,
                            height: 4,
                            decoration: BoxDecoration(
                              color: textColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
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
  const _CountCard({required this.title, required this.count, required this.color});
  @override
  Widget build(BuildContext context) {
    final textColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
    final g = LinearGradient(
      colors: [
        color,
        Color.alphaBlend(Colors.black.withValues(alpha: 0.05), color),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
      borderRadius: BorderRadius.circular(8),
      child: AppCard(
        gradient: g,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color.alphaBlend(Colors.white.withValues(alpha: 0.2), color),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.route, color: textColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textColor, fontSize: 14)),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Text(
                      '$count',
                      key: ValueKey(count),
                      style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
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
    final textColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
    final g = LinearGradient(
      colors: [
        color,
        Color.alphaBlend(Colors.black.withValues(alpha: 0.05), color),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
      borderRadius: BorderRadius.circular(8),
      child: AppCard(
        gradient: g,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color.alphaBlend(Colors.white.withValues(alpha: 0.2), color),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.local_shipping_outlined, color: textColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textColor, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                          child: Text(
                            'Totais: $total',
                            key: ValueKey('tot_$total'),
                            style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
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
                            color: textColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('Vulso: $vulso', style: TextStyle(color: textColor)),
                        ),
                      ),
                    ],
                  ),
                ],
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
