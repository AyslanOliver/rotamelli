import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import '../models/rota.dart';
import '../utils/database_helper.dart';
import '../utils/calculo_valor.dart';
import 'add_rota_screen.dart';
import '../widgets/rota_card.dart';

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

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper();
    _loadRotas();
  }

  void _loadRotas() async {
    final mesRotas = await _dbHelper.getRotasByMonth(anoAtual, mesAtual);
    final total = await _dbHelper.getSumValorByMonth(anoAtual, mesAtual);

    setState(() {
      rotas = mesRotas;
      totalMes = total;
    });
  }

  void _deleteRota(int id) async {
    await _dbHelper.deleteRota(id);
    _loadRotas();
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
      ),
      body: Column(
        children: [
          // Header com mês/ano e navegação
          Container(
            color: Colors.blue.shade50,
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
                        foregroundColor: Colors.blue.shade700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => _changeMes(1),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Total do mês
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total do Mês:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        CalculoValor.formatarMoeda(totalMes),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
            child: rotas.isEmpty
                ? Center(
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
                      ],
                    ),
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
