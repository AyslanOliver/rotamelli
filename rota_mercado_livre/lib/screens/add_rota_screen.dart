import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rota.dart';
import '../utils/database_helper.dart';
import '../utils/calculo_valor.dart';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'expenses_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import 'help_screen.dart';
import '../widgets/sb_sidebar.dart';

class AddRotaScreen extends StatefulWidget {
  final Rota? rota;

  const AddRotaScreen({super.key, this.rota});

  @override
  State<AddRotaScreen> createState() => _AddRotaScreenState();
}

class _AddRotaScreenState extends State<AddRotaScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeRotaController;
  late TextEditingController _placaCarroController;
  late TextEditingController _quantidadePacotesController;
  late TextEditingController _pacotesVulsoController;

  DateTime? _selectedDate;
  String _selectedTipoVeiculo = 'passeio';
  double _valorCalculado = 330.00;
  late DatabaseHelper _dbHelper;
  int rotasCountMes = 0;
  int despesasCountMes = 0;

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper();

    if (widget.rota != null) {
      _nomeRotaController =
          TextEditingController(text: widget.rota!.nomeRota);
      _placaCarroController =
          TextEditingController(text: widget.rota!.placaCarro);
      _quantidadePacotesController =
          TextEditingController(text: widget.rota!.quantidadePacotes.toString());
      _pacotesVulsoController =
          TextEditingController(text: widget.rota!.pacotesVulso.toString());
      _selectedDate = widget.rota!.dataRota;
      _selectedTipoVeiculo = widget.rota!.tipoVeiculo;
      _valorCalculado = widget.rota!.valorCalculado;
    } else {
      _nomeRotaController = TextEditingController();
      _placaCarroController = TextEditingController();
      _quantidadePacotesController = TextEditingController();
      _pacotesVulsoController = TextEditingController();
      _selectedDate = DateTime.now();
    }
    _loadCounts();
  }

  @override
  void dispose() {
    _nomeRotaController.dispose();
    _placaCarroController.dispose();
    _quantidadePacotesController.dispose();
    _pacotesVulsoController.dispose();
    super.dispose();
  }

  void _calculateValor() {
    if (_selectedDate != null &&
        _quantidadePacotesController.text.isNotEmpty) {
      int pacotes = int.tryParse(_quantidadePacotesController.text) ?? 0;
      int vulso = int.tryParse(_pacotesVulsoController.text) ?? 0;
      setState(() {
        _valorCalculado = CalculoValor.calcularValorTotal(
          tipoVeiculo: _selectedTipoVeiculo,
          dataRota: _selectedDate!,
          quantidadePacotes: pacotes,
          pacotesVulso: vulso,
        );
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _calculateValor();
    }
  }

  void _saveRota() async {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      final rota = Rota(
        id: widget.rota?.id,
        nomeRota: _nomeRotaController.text,
        dataRota: _selectedDate!,
        placaCarro: _placaCarroController.text,
        quantidadePacotes:
            int.parse(_quantidadePacotesController.text),
        pacotesVulso: int.tryParse(_pacotesVulsoController.text) ?? 0,
        tipoVeiculo: _selectedTipoVeiculo,
        valorCalculado: _valorCalculado,
      );

      if (widget.rota != null) {
        await _dbHelper.updateRota(rota);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rota atualizada com sucesso!')),
        );
      } else {
        await _dbHelper.insertRota(rota);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rota cadastrada com sucesso!')),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _loadCounts() async {
    final now = DateTime.now();
    final rc = await _dbHelper.getCountByMonth(now.year, now.month);
    final dc = await _dbHelper.getCountDespesasByMonth(now.year, now.month);
    setState(() {
      rotasCountMes = rc;
      despesasCountMes = dc;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
    final nomeDia = _selectedDate != null
        ? CalculoValor.getNomeDia(_selectedDate!)
        : 'Dia não selecionado';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rota != null ? 'Editar Rota' : 'Nova Rota'),
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
      drawer: SbSidebar(active: 'rotas', rotasCount: rotasCountMes, despesasCount: despesasCountMes),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nome da Rota
              TextFormField(
                controller: _nomeRotaController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Rota',
                  hintText: 'Ex: Rota Centro',
                  prefixIcon: Icon(Icons.route),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, digite o nome da rota';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                readOnly: true,
                onTap: () => _selectDate(context),
                decoration: InputDecoration(
                  labelText: 'Data da Rota',
                  hintText: 'Selecione a data',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: const OutlineInputBorder(),
                  suffixText: _selectedDate != null
                      ? '${dateFormat.format(_selectedDate!)} ($nomeDia)'
                      : null,
                ),
                validator: (_) {
                  if (_selectedDate == null) {
                    return 'Por favor, selecione uma data';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Placa do Carro
              TextFormField(
                controller: _placaCarroController,
                decoration: const InputDecoration(
                  labelText: 'Placa do Carro',
                  hintText: 'Ex: ABC-1234',
                  prefixIcon: Icon(Icons.directions_car),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, digite a placa do carro';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Tipo de Veículo
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<String>(
                  value: _selectedTipoVeiculo,
                  isExpanded: true,
                  underline: const SizedBox(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedTipoVeiculo = newValue;
                      });
                      _calculateValor();
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'passeio',
                      child: Text('Carro de Passeio (R\$ 330,00)'),
                    ),
                    DropdownMenuItem(
                      value: 'utilitario',
                      child: Text('Utilitário (R\$ 350,00)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quantidade de Pacotes
              TextFormField(
                controller: _quantidadePacotesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade de Pacotes',
                  hintText: 'Ex: 45',
                  prefixIcon: Icon(Icons.inventory_2),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _calculateValor(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, digite a quantidade de pacotes';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Por favor, digite um número válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Pacotes a Vulso
              TextFormField(
                controller: _pacotesVulsoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Pacotes a Vulso (opcional)',
                  hintText: 'Ex: 5',
                  prefixIcon: Icon(Icons.local_shipping),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _calculateValor(),
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      int.tryParse(value) == null) {
                    return 'Por favor, digite um número válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Resumo de Adicionais
              if (_selectedDate != null &&
                  _quantidadePacotesController.text.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.tertiary),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informações da Rota:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dia: $nomeDia',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onTertiaryContainer),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Adicionais: ${CalculoValor.getInfoAdicionais(_selectedDate!, int.tryParse(_quantidadePacotesController.text) ?? 0)}',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onTertiaryContainer),
                      ),
                      const SizedBox(height: 4),
                      if (_pacotesVulsoController.text.isNotEmpty)
                        Text(
                          'Pacotes a Vulso: R\$ ${(CalculoValor.valorPacoteVulso * (int.tryParse(_pacotesVulsoController.text) ?? 0)).toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onTertiaryContainer),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Valor Calculado
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valor da Rota:',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CalculoValor.formatarMoeda(_valorCalculado),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botões de Ação
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveRota,
                      icon: const Icon(Icons.check),
                      label: const Text('Salvar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
