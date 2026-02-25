import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/home_screen.dart';
import '../screens/expenses_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/help_screen.dart';
import '../theme/sb2.dart';
import '../screens/conferencia_screen.dart';

class SbSidebar extends StatelessWidget {
  final String active;
  final int? rotasCount;
  final int? despesasCount;
  const SbSidebar({super.key, required this.active, this.rotasCount, this.despesasCount});
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Colors.white;
    final width = MediaQuery.of(context).size.width;
    final compact = width >= 600 && width < 900;
    return Drawer(
      width: MediaQuery.of(context).size.width < 600 ? MediaQuery.of(context).size.width * 0.72 : 320,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, const Color(0xFF224ABE)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.dashboard_outlined, color: Colors.white),
                    if (!compact) const SizedBox(width: 12),
                    if (!compact) Text('Rota Mercado Livre', style: TextStyle(fontWeight: FontWeight.bold, color: onPrimary)),
                  ],
                ),
              ),
              if (!compact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(
                    'INTERFACE',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: SB2.letterSpacing),
                  ),
                ),
              const SizedBox(height: 8),
              _NavItem(
                icon: Icons.dashboard,
                label: 'Dashboard',
                active: active == 'dashboard',
                compact: compact,
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
                },
              ),
              _NavItem(
                icon: Icons.list_alt,
                label: 'Rotas',
                active: active == 'rotas',
                count: rotasCount,
                badgeColor: SB2.info,
                compact: compact,
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                },
              ),
              _NavItem(
                icon: Icons.fact_check_outlined,
                label: 'Conferência',
                active: active == 'conferencia',
                compact: compact,
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ConferenciaScreen()));
                },
              ),
              _NavItem(
                icon: Icons.attach_money,
                label: 'Despesas',
                active: active == 'despesas',
                count: despesasCount,
                badgeColor: SB2.danger,
                compact: compact,
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen()));
                },
              ),
              const Divider(color: Colors.white24),
              if (!compact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Text(
                    'ADDONS',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: SB2.letterSpacing),
                  ),
                ),
              _NavItem(
                icon: Icons.bar_chart,
                label: 'Relatórios',
                active: active == 'relatorios',
                compact: compact,
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
                },
              ),
              _NavItem(
                icon: Icons.settings,
                label: 'Configurações',
                active: active == 'config',
                compact: compact,
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
              _NavItem(
                icon: Icons.help_outline,
                label: 'Ajuda',
                active: active == 'ajuda',
                compact: compact,
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int? count;
  final VoidCallback onTap;
  final bool compact;
  final Color? badgeColor;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap, this.count, this.compact = false, this.badgeColor});
  @override
  Widget build(BuildContext context) {
    final onPrimary = Colors.white;
    final row = Row(
      children: [
        Icon(icon, color: onPrimary),
        if (!compact) const SizedBox(width: 12),
        if (!compact) Expanded(child: Text(label, style: TextStyle(color: onPrimary))),
        if ((count ?? 0) > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: (badgeColor ?? Colors.white24), borderRadius: BorderRadius.circular(12)),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
      ],
    );
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
          border: active ? const Border(left: BorderSide(color: Colors.white, width: 3)) : null,
        ),
        child: compact ? Tooltip(message: label, child: Align(alignment: Alignment.centerLeft, child: row)) : row,
      ),
    );
  }
}
