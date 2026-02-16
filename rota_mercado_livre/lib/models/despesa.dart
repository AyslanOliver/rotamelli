class Despesa {
  final int? id;
  final String descricao;
  final double valor;
  final DateTime dataDespesa;
  final String? categoria;

  Despesa({
    this.id,
    required this.descricao,
    required this.valor,
    required this.dataDespesa,
    this.categoria,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descricao': descricao,
      'valor': valor,
      'dataDespesa': _formatDate(dataDespesa),
      'categoria': categoria,
    };
  }

  static String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  factory Despesa.fromMap(Map<String, dynamic> map) {
    final dataStr = map['dataDespesa'] as String;
    final parts = dataStr.split('-');
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    return Despesa(
      id: map['id'] as int?,
      descricao: map['descricao'] as String,
      valor: (map['valor'] as num).toDouble(),
      dataDespesa: date,
      categoria: map['categoria'] as String?,
    );
  }
}
