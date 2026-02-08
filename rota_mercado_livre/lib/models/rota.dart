class Rota {
  int? id;
  String nomeRota;
  DateTime dataRota;
  String placaCarro;
  int quantidadePacotes;
  int pacotesVulso;
  String tipoVeiculo; // 'passeio' ou 'utilitario'
  double valorCalculado;

  Rota({
    this.id,
    required this.nomeRota,
    required this.dataRota,
    required this.placaCarro,
    required this.quantidadePacotes,
    int? pacotesVulso,
    required this.tipoVeiculo,
    required this.valorCalculado,
  }) : pacotesVulso = pacotesVulso ?? 0;

  // Converter para Map para armazenar no banco de dados
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nomeRota': nomeRota,
      'dataRota': dataRota.toIso8601String(),
      'placaCarro': placaCarro,
      'quantidadePacotes': quantidadePacotes,
      'pacotesVulso': pacotesVulso,
      'tipoVeiculo': tipoVeiculo,
      'valorCalculado': valorCalculado,
    };
  }

  // Criar a partir do Map do banco de dados
  factory Rota.fromMap(Map<String, dynamic> map) {
    return Rota(
      id: map['id'],
      nomeRota: map['nomeRota'],
      dataRota: DateTime.parse(map['dataRota']),
      placaCarro: map['placaCarro'],
      quantidadePacotes: map['quantidadePacotes'],
      pacotesVulso: map['pacotesVulso'],
      tipoVeiculo: map['tipoVeiculo'],
      valorCalculado: map['valorCalculado'],
    );
  }

  @override
  String toString() {
    return 'Rota(id: $id, nomeRota: $nomeRota, dataRota: $dataRota, placaCarro: $placaCarro, quantidadePacotes: $quantidadePacotes, tipoVeiculo: $tipoVeiculo, valorCalculado: $valorCalculado)';
  }
}
