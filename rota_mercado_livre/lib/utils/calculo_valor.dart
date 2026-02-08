import 'package:intl/intl.dart';

class CalculoValor {
  static const double valorPasseio = 330.00;
  static const double valorUtilitario = 350.00;
  static const double adicionalDomingo = 40.00;
  static const double adicional80Pacotes = 40.00;
  static const int limitePacotes = 80;

  /// Calcula o valor total da rota baseado no tipo de veículo e condições
  static double calcularValorTotal({
    required String tipoVeiculo,
    required DateTime dataRota,
    required int quantidadePacotes,
  }) {
    // Valor base conforme tipo de veículo
    double valorBase = tipoVeiculo == 'passeio' ? valorPasseio : valorUtilitario;

    double valorFinal = valorBase;

    // Adicional de domingo
    if (dataRota.weekday == 7) {
      valorFinal += adicionalDomingo;
    }

    // Adicional por 80 ou mais pacotes
    if (quantidadePacotes >= limitePacotes) {
      valorFinal += adicional80Pacotes;
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

    if (quantidadePacotes >= limitePacotes) {
      adicionais.add('80+ pacotes (+R\$ 40,00)');
    }

    return adicionais.isEmpty ? 'Nenhum adicional' : adicionais.join(' | ');
  }
}
