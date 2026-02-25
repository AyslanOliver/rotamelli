class RomaneioItem {
  final int? id;
  final String numero;
  final String idPacote;
  final String cliente;
  final String endereco;
  final String numeroEndereco;
  final String complemento;
  final String bairro;
  final String cidade;
  final String cep;
  final String tipoEndereco;
  final String assinatura;
  final String status; // pendente | conferido
  final String createdAt; // ISO date
  RomaneioItem({
    this.id,
    required this.numero,
    required this.idPacote,
    required this.cliente,
    required this.endereco,
    required this.numeroEndereco,
    required this.complemento,
    required this.bairro,
    required this.cidade,
    required this.cep,
    required this.tipoEndereco,
    required this.assinatura,
    this.status = 'pendente',
    required this.createdAt,
  });
  Map<String, dynamic> toMap() => {
        'id': id,
        'numero': numero,
        'idPacote': idPacote,
        'cliente': cliente,
        'endereco': endereco,
        'numeroEndereco': numeroEndereco,
        'complemento': complemento,
        'bairro': bairro,
        'cidade': cidade,
        'cep': cep,
        'tipoEndereco': tipoEndereco,
        'assinatura': assinatura,
        'status': status,
        'createdAt': createdAt,
      };
  factory RomaneioItem.fromMap(Map<String, dynamic> m) => RomaneioItem(
        id: m['id'] as int?,
        numero: m['numero']?.toString() ?? '',
        idPacote: m['idPacote']?.toString() ?? '',
        cliente: m['cliente']?.toString() ?? '',
        endereco: m['endereco']?.toString() ?? '',
        numeroEndereco: m['numeroEndereco']?.toString() ?? '',
        complemento: m['complemento']?.toString() ?? '',
        bairro: m['bairro']?.toString() ?? '',
        cidade: m['cidade']?.toString() ?? '',
        cep: m['cep']?.toString() ?? '',
        tipoEndereco: m['tipoEndereco']?.toString() ?? '',
        assinatura: m['assinatura']?.toString() ?? '',
        status: m['status']?.toString() ?? 'pendente',
        createdAt: m['createdAt']?.toString() ?? '',
      );
}
