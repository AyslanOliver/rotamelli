class RomaneioParser {
  static List<Map<String, dynamic>> parseFromText(String text) {
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];
    final headerIndex = lines.indexWhere((l) => l.contains('ID do pacote') && l.contains('Cliente'));
    if (headerIndex < 0 || headerIndex + 1 >= lines.length) return [];
    final header = lines[headerIndex];
    final cols = <_Col>[
      _Col('numero', header.indexOf('N.')),
      _Col('idPacote', header.indexOf('ID do pacote')),
      _Col('cliente', header.indexOf('Cliente')),
      _Col('endereco', header.indexOf('Endereço')),
      _Col('numeroEndereco', header.indexOf('N.º')),
      _Col('complemento', header.indexOf('Complemento')),
      _Col('bairro', header.indexOf('Bairro')),
      _Col('cidade', header.indexOf('Cidade')),
      _Col('cep', header.indexOf('CEP')),
      _Col('tipoEndereco', header.indexOf('Tipo de endereço')),
      _Col('assinatura', header.indexOf('Assinatura')),
    ];
    final ordered = cols.where((c) => c.pos >= 0).toList()..sort((a, b) => a.pos.compareTo(b.pos));
    final bounds = <_Slice>[];
    for (var i = 0; i < ordered.length; i++) {
      final start = ordered[i].pos;
      final end = i + 1 < ordered.length ? ordered[i + 1].pos : null;
      bounds.add(_Slice(ordered[i].key, start, end));
    }
    final out = <Map<String, dynamic>>[];
    for (var i = headerIndex + 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) continue;
      final m = <String, String>{};
      for (final sl in bounds) {
        final start = sl.start;
        final end = sl.end ?? line.length;
        if (start >= line.length) {
          m[sl.key] = '';
        } else {
          final part = line.substring(start, end.clamp(0, line.length)).trim();
          m[sl.key] = part;
        }
      }
      if ((m['idPacote'] ?? '').isEmpty && (m['cliente'] ?? '').isEmpty) continue;
      out.add({
        'numero': m['numero'] ?? '',
        'idPacote': m['idPacote'] ?? '',
        'cliente': m['cliente'] ?? '',
        'endereco': m['endereco'] ?? '',
        'numeroEndereco': m['numeroEndereco'] ?? '',
        'complemento': m['complemento'] ?? '',
        'bairro': m['bairro'] ?? '',
        'cidade': m['cidade'] ?? '',
        'cep': m['cep'] ?? '',
        'tipoEndereco': m['tipoEndereco'] ?? '',
        'assinatura': m['assinatura'] ?? '',
        'status': 'pendente',
        'createdAt': DateTime.now().toIso8601String().split('T').first,
      });
    }
    return out;
  }
}

class _Col {
  final String key;
  final int pos;
  _Col(this.key, this.pos);
}

class _Slice {
  final String key;
  final int start;
  final int? end;
  _Slice(this.key, this.start, this.end);
}
