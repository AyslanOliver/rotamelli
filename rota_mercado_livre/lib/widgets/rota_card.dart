import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/rota.dart';
import '../utils/calculo_valor.dart';

class RotaCard extends StatelessWidget {
  final Rota rota;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const RotaCard({
    Key? key,
    required this.rota,
    required this.onDelete,
    required this.onEdit,
  }) : super(key: key);

  String _getTipoVeiculoNome(String tipo) {
    return tipo == 'passeio' ? 'Carro de Passeio' : 'Utilitário';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
    final nomeDia = CalculoValor.getNomeDia(rota.dataRota);
    final moedaFormatada = CalculoValor.formatarMoeda(rota.valorCalculado);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 2,
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rota.nomeRota,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dateFormat.format(rota.dataRota)} - $nomeDia',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              moedaFormatada,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Placa do Carro:', rota.placaCarro),
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Tipo de Veículo:',
                  _getTipoVeiculoNome(rota.tipoVeiculo),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Quantidade de Pacotes:',
                  rota.quantidadePacotes.toString(),
                ),
                const SizedBox(height: 12),
                if (rota.pacotesVulso > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        'Pacotes a Vulso:',
                        rota.pacotesVulso.toString(),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detalhes do Valor:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Valor Base:',
                        rota.tipoVeiculo == 'passeio'
                            ? CalculoValor.formatarMoeda(
                                CalculoValor.VALOR_PASSEIO)
                            : CalculoValor.formatarMoeda(
                                CalculoValor.VALOR_UTILITARIO),
                        fontSize: 11,
                      ),
                      if (rota.dataRota.weekday == 7)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            _buildDetailRow(
                              'Adicional Domingo:',
                              '+' +
                                  CalculoValor.formatarMoeda(
                                      CalculoValor.ADICIONAL_DOMINGO),
                              fontSize: 11,
                              textColor: Colors.green,
                            ),
                          ],
                        ),
                      if (rota.quantidadePacotes >=
                          CalculoValor.LIMITE_PACOTES)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            _buildDetailRow(
                              'Adicional 80+ Pacotes:',
                              '+' +
                                  CalculoValor.formatarMoeda(
                                      CalculoValor.ADICIONAL_80_PACOTES),
                              fontSize: 11,
                              textColor: Colors.green,
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
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Deletar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
