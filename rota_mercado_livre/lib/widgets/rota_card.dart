import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rota.dart';
import '../utils/calculo_valor.dart';
import 'app_card.dart';

class RotaCard extends StatelessWidget {
  final Rota rota;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const RotaCard({
    super.key,
    required this.rota,
    required this.onDelete,
    required this.onEdit,
  });

  String _getTipoVeiculoNome(String tipo) {
    return tipo == 'passeio' ? 'Carro de Passeio' : 'Utilitário';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
    final nomeDia = CalculoValor.getNomeDia(rota.dataRota);
    final moedaFormatada = CalculoValor.formatarMoeda(rota.valorCalculado);

    final primary = Theme.of(context).colorScheme.primary;

    final tile = ExpansionTile(
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rota.nomeRota,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dateFormat.format(rota.dataRota)} - $nomeDia',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            moedaFormatada,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Ações',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Editar'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Deletar'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: AppCard(
            borderLeftColor: primary,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Placa do Carro:', rota.placaCarro),
                const SizedBox(height: 12),
                _buildDetailRow('Tipo de Veículo:', _getTipoVeiculoNome(rota.tipoVeiculo)),
                const SizedBox(height: 12),
                _buildDetailRow('Quantidade de Pacotes:', rota.quantidadePacotes.toString()),
                const SizedBox(height: 12),
                if (rota.pacotesVulso > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Pacotes a Vulso:', rota.pacotesVulso.toString()),
                      const SizedBox(height: 12),
                    ],
                  ),
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Detalhes do Valor:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Valor Base:',
                        rota.tipoVeiculo == 'passeio'
                            ? CalculoValor.formatarMoeda(CalculoValor.valorPasseio)
                            : CalculoValor.formatarMoeda(CalculoValor.valorUtilitario),
                        fontSize: 11,
                      ),
                      if (rota.dataRota.weekday == 7)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            _buildDetailRow(
                              'Adicional Domingo:',
                              '+${CalculoValor.formatarMoeda(CalculoValor.adicionalDomingo)}',
                              fontSize: 11,
                              textColor: Colors.green,
                            ),
                          ],
                        ),
                      if (rota.quantidadePacotes >= CalculoValor.limitePacotes)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            _buildDetailRow(
                              'Adicional 80+ Pacotes:',
                              '+${CalculoValor.formatarMoeda(CalculoValor.adicional80Pacotes)}',
                              fontSize: 11,
                              textColor: Colors.green,
                            ),
                          ],
                        ),
                      if (rota.pacotesVulso > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            _buildDetailRow(
                              'Pacotes a Vulso (motoristas):',
                              '+${CalculoValor.formatarMoeda(CalculoValor.valorPacoteVulso * rota.pacotesVulso)}',
                              fontSize: 11,
                              textColor: Colors.blueGrey,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Deletar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return tile;
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    double fontSize = 13,
    Color textColor = Colors.black,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
