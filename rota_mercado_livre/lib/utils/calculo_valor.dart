import 'package:intl/intl.dart';

class CalculoValor {
  static const double VALOR_PASSEIO = 330.00;
  static const double VALOR_UTILITARIO = 350.00;
  static const double ADICIONAL_DOMINGO = 40.00;
  static const double ADICIONAL_80_PACOTES = 40.00;
  static const int LIMITE_PACOTES = 80;

  /// Calcula o valor total da rota baseado no tipo de veículo e condições
  static double calcularValorTotal({
    required String tipoVeiculo,
    required DateTime dataRota,
    required int quantidadePacotes,
  }) {
    // Valor base conforme tipo de veículo
    double valorBase = tipoVeiculo == 'passeio' ? VALOR_PASSEIO : VALOR_UTILITARIO;

    double valorFinal = valorBase;

    // Adicional de domingo
    if (dataRota.weekday == 7) {
      // 7 = domingo
      valorFinal += ADICIONAL_DOMINGO;
    }

    // Adicional por 80 ou mais pacotes
    if (quantidadePacotes >= LIMITE_PACOTES) {
      valorFinal += ADICIONAL_80_PACOTES;
    }

    return valorFinal;
  }

  /// Formata um valor em moeda brasileira
  static String formatarMoeda(double valor) {
    final formatter = NumberFormat.simpleCurrency(locale: 'pt_BR');
    return formatter.format(valor);
  }

  /// Retorna o nome do dia da semana em português
  static String getNomeDia(DateTime data) {
    const diasSemana = [
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo'
    ];
    return diasSemana[data.weekday - 1];
  }

  /// Retorna informações sobre adicionais aplicáveis
  static String getInfoAdicionais(DateTime dataRota, int quantidadePacotes) {
    List<String> adicionais = [];

    if (dataRota.weekday == 7) {
      adicionais.add('Domingo (+R\$ 40,00)');
    }

    if (quantidadePacotes >= LIMITE_PACOTES) {
      adicionais.add('80+ pacotes (+R\$ 40,00)');
    }

    return adicionais.isEmpty ? 'Nenhum adicional' : adicionais.join(' | ');
  }
}
