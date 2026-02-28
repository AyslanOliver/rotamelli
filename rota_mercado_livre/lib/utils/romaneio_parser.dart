import 'package:syncfusion_flutter_pdf/pdf.dart';

class RomaneioParser {
  static List<Map<String, dynamic>> parseFromText(String text) {
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];
    final headerIndex = lines.indexWhere((l) {
      final n = _norm(l);
      return n.contains('id do pacote') && n.contains('cliente');
    });
    if (headerIndex < 0 || headerIndex + 1 >= lines.length) {
      final looseStrict = _parseLooseLines(lines);
      final looseFlex = _parseLooseFlexible(lines);
      final looseBlocks = _parseLooseBlocks(lines);
      final merged = [...looseStrict, ...looseFlex, ...looseBlocks];
      return merged.where((r) {
        final num = (r['numero'] ?? '').toString().trim();
        final id = (r['idPacote'] ?? '').toString().trim();
        final isIdNumeric = RegExp(r'^\d{6,}$').hasMatch(id);
        final numOk = RegExp(r'^\d+[A-Za-z]*$').hasMatch(num);
        return isIdNumeric && numOk;
      }).toList();
    }
    final header = lines[headerIndex];
    final headerNorm = _norm(header);
    final idPacotePos = _posAny(headerNorm, ['id do pacote', 'id pacote', 'id']);
    final clientePos = _posAny(headerNorm, ['cliente']);
    final enderecoPos = _posAny(headerNorm, ['endereco']);
    final cols = <_Col>[
      _Col('numero', _posAny(headerNorm, ['n.', 'nº', 'n°', 'numero'])),
      _Col('idPacote', idPacotePos),
      _Col('cliente', clientePos),
      _Col('endereco', enderecoPos),
      _Col('numeroEndereco', enderecoPos >= 0 ? _posAnyAfter(headerNorm, ['n.º', 'nº', 'n°', 'numero', 'n.'], enderecoPos + 1) : _posAny(headerNorm, ['n.º', 'nº', 'n°', 'numero', 'n.'])),
      _Col('complemento', _posAny(headerNorm, ['complemento'])),
      _Col('bairro', _posAny(headerNorm, ['bairro'])),
      _Col('cidade', _posAny(headerNorm, ['cidade'])),
      _Col('cep', _posAny(headerNorm, ['cep'])),
      _Col('tipoEndereco', _posAny(headerNorm, ['tipo de endereco', 'tipo de endereço'])),
      _Col('assinatura', _posAny(headerNorm, ['assinatura'])),
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
      var m = <String, String>{};
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
      if ((m['idPacote'] ?? '').isEmpty && (m['cliente'] ?? '').isEmpty) {
        final parts = line.split(RegExp(r'\s{2,}')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (parts.length >= ordered.length) {
          final mm = <String, String>{};
          for (var j = 0; j < ordered.length; j++) {
            final key = ordered[j].key;
            mm[key] = parts[j];
          }
          m = mm;
        }
      }
      final id = (m['idPacote'] ?? '').toString().trim();
      final isIdNumeric = RegExp(r'^\d{6,}$').hasMatch(id);
      final numeroText = (m['numero'] ?? '').toString().toLowerCase().trim();
      final numOk = RegExp(r'^\d+[a-z]*$').hasMatch(numeroText);
      if (!isIdNumeric) continue;
      if (!numOk) continue;
      if (numeroText.contains('n.º') || numeroText.contains('nº') || numeroText.contains('n°')) continue;
      if (_norm(id) == 'id do pacote') continue;
      out.add({
        'numero': m['numero'] ?? '',
        'idPacote': m['idPacote'] ?? '',
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

  static List<Map<String, dynamic>> _parseLooseLines(List<String> lines) {
    final out = <Map<String, dynamic>>[];
    final re = RegExp(r'^(\d+[A-Za-z]*)\s+(\d{8,})\s+(.*?)\s+(SN|S\/N|\d+)\s+(.*?)\s+([A-Za-zÀ-ÿ]+)\s+([A-Za-zÀ-ÿ]+)\s+(\d{8})\s+([A-Z])$');
    for (final line in lines) {
      final l = line.trim();
      final m = re.firstMatch(l);
      if (m == null) continue;
      final numeroRaw = m.group(1)!;
      out.add({
        'numero': numeroRaw,
        'idPacote': m.group(2) ?? '',
        'endereco': m.group(3) ?? '',
        'numeroEndereco': m.group(4) ?? '',
        'complemento': m.group(5) ?? '',
        'bairro': m.group(6) ?? '',
        'cidade': m.group(7) ?? '',
        'cep': m.group(8) ?? '',
        'tipoEndereco': '',
        'assinatura': '',
        'status': 'pendente',
        'createdAt': DateTime.now().toIso8601String().split('T').first,
      });
    }
    return out;
  }

  static List<Map<String, dynamic>> _parseLooseFlexible(List<String> lines) {
    final out = <Map<String, dynamic>>[];
    var seq = 0;
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final toks = line.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      if (toks.length < 3) continue;
      // unir número dividido "8 AB"
      var numeroTok = toks.first;
      if (RegExp(r'^\d+$').hasMatch(numeroTok)) {
        int k = 1;
        final buf = StringBuffer()..write(numeroTok);
        while (k < toks.length && RegExp(r'^[A-Za-z]+$').hasMatch(toks[k])) {
          buf.write(toks[k]);
          k++;
        }
        numeroTok = buf.toString();
      }
      var validNum = RegExp(r'^\d+[A-Za-z]*$').hasMatch(numeroTok);
      int idIdx = toks.indexWhere((t) => _isIdToken(t));
      if (idIdx < 0) continue;
      int cepIdx = toks.lastIndexWhere((t) => _isCepToken(t));
      final tipoIdx = cepIdx + 1 < toks.length && RegExp(r'^[A-Za-z]$').hasMatch(toks[cepIdx + 1]) ? cepIdx + 1 : -1;
      int cidadeIdx = cepIdx - 1;
      if (cepIdx < 0) {
        for (int i = toks.length - 1; i >= 0; i--) {
          if (_isCityToken(toks[i])) {
            cidadeIdx = i;
            break;
          }
        }
      }
      final cidadeTok = cidadeIdx >= 0 ? toks[cidadeIdx] : '';
      final cidade = cidadeTok;
      final idPacote = toks[idIdx];
      seq += 1;
      final numero = validNum ? numeroTok : '${seq}A';
      String endereco = '';
      String numeroEndereco = '';
      String complemento = '';
      String bairro = cidadeIdx - 1 >= 0 ? toks[cidadeIdx - 1] : '';
      final endSpanIdx = cidadeIdx >= 0 ? cidadeIdx : toks.length;
      if (idIdx + 1 < endSpanIdx) {
        final span = toks.sublist(idIdx + 1, endSpanIdx);
        int numEndIdx = span.lastIndexWhere((t) => RegExp(r'^(SN|S/N|\d+)$').hasMatch(t));
        if (numEndIdx >= 0) {
          endereco = span.sublist(0, numEndIdx).join(' ').trim();
          numeroEndereco = span[numEndIdx];
          if (numEndIdx + 1 < span.length) {
            complemento = span.sublist(numEndIdx + 1).join(' ').trim();
          }
        } else {
          endereco = span.join(' ').trim();
        }
      }
      out.add({
        'numero': numero,
        'idPacote': idPacote,
        'endereco': _abbr(endereco),
        'numeroEndereco': numeroEndereco,
        'complemento': _abbr(complemento),
        'bairro': bairro,
        'cidade': cidade,
        'cep': cepIdx >= 0 ? toks[cepIdx].replaceAll('-', '') : '',
        'tipoEndereco': '',
        'assinatura': '',
        'status': 'pendente',
        'createdAt': DateTime.now().toIso8601String().split('T').first,
      });
    }
    return out;
  }

  static List<Map<String, dynamic>> _parseLooseBlocks(List<String> lines) {
    final out = <Map<String, dynamic>>[];
    int i = 0;
    while (i < lines.length) {
      final start = lines[i].trim();
      final m = RegExp(r'^(\d+)\s*([A-Za-z]*)\s+(\d{8,})$').firstMatch(start);
      if (m == null) {
        i++;
        continue;
      }
      final numero = '${m.group(1)!}${m.group(2)!}';
      final idPacote = m.group(3)!;
      final buf = <String>[];
      int j = i + 1;
      while (j < lines.length && RegExp(r'^\d+[A-Za-z]*\s+\d{8,}$').firstMatch(lines[j].trim()) == null) {
        buf.add(lines[j].trim());
        j++;
      }
      final block = buf.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      final toks = block.split(' ');
      int cepIdx = -1;
      for (int k = toks.length - 1; k >= 0; k--) {
        if (_isCepToken(toks[k])) {
          cepIdx = k;
          break;
        }
      }
      int tipoIdx = (cepIdx >= 0 && cepIdx + 1 < toks.length && RegExp(r'^[A-Za-z]$').hasMatch(toks[cepIdx + 1])) ? (cepIdx + 1) : -1;
      int cidadeIdx = cepIdx >= 0 ? cepIdx - 1 : -1;
      if (cidadeIdx < 0) {
        for (int k = toks.length - 1; k >= 0; k--) {
          if (_isCityToken(toks[k])) {
            cidadeIdx = k;
            break;
          }
        }
      }
      final bairroIdx = cidadeIdx - 1;
      final cidade = cidadeIdx >= 0 ? toks[cidadeIdx] : '';
      final bairro = bairroIdx >= 0 ? toks[bairroIdx] : '';
      final endSpanEnd = bairroIdx >= 0 ? bairroIdx : (cidadeIdx >= 0 ? cidadeIdx : toks.length);
      String endereco = '';
      String numeroEndereco = '';
      String complemento = '';
      if (endSpanEnd > 0) {
        final span = toks.sublist(0, endSpanEnd);
        int numIdx = span.lastIndexWhere((t) => RegExp(r'^(SN|S/N|\d+)$').hasMatch(t));
        if (numIdx >= 0) {
          endereco = span.sublist(0, numIdx).join(' ').trim();
          numeroEndereco = span[numIdx];
          if (numIdx + 1 < span.length) {
            complemento = span.sublist(numIdx + 1).join(' ').trim();
          }
        } else {
          endereco = span.join(' ').trim();
        }
      }
      out.add({
        'numero': numero,
        'idPacote': idPacote,
        'endereco': _abbr(endereco),
        'numeroEndereco': numeroEndereco,
        'complemento': _abbr(complemento),
        'bairro': bairro,
        'cidade': cidade,
        'cep': cepIdx >= 0 ? toks[cepIdx].replaceAll('-', '') : '',
        'tipoEndereco': '',
        'assinatura': '',
        'status': 'pendente',
        'createdAt': DateTime.now().toIso8601String().split('T').first,
      });
      i = j;
    }
    return out;
  }

  static List<Map<String, dynamic>> parseFromPdf(PdfDocument doc) {
    final extractor = PdfTextExtractor(doc);
    final parsedByLines = _parseDataLines(extractor.extractTextLines(startPageIndex: 0, endPageIndex: doc.pages.count - 1));
    final out = <Map<String, dynamic>>[];
    var seq = 0;
    for (var p = 0; p < doc.pages.count; p++) {
      final resNumero = extractor.findText(['N.º', 'Nº', 'N°'], startPageIndex: p, endPageIndex: p);
      final resId = extractor.findText(['ID do pacote', 'ID DO PACOTE', 'ID pacote', 'ID'], startPageIndex: p, endPageIndex: p);
      final resCliente = extractor.findText(['Cliente', 'CLIENTE'], startPageIndex: p, endPageIndex: p);
      final resEndereco = extractor.findText(['Endereço', 'Endereco'], startPageIndex: p, endPageIndex: p);
      final resComplemento = extractor.findText(['Complemento'], startPageIndex: p, endPageIndex: p);
      final resBairro = extractor.findText(['Bairro'], startPageIndex: p, endPageIndex: p);
      final resCidade = extractor.findText(['Cidade', 'CIDADE'], startPageIndex: p, endPageIndex: p);
      final resCep = extractor.findText(['CEP'], startPageIndex: p, endPageIndex: p);
      final resTipo = extractor.findText(['Tipo de endereço', 'Tipo de endereco'], startPageIndex: p, endPageIndex: p);
      final resAss = extractor.findText(['Assinatura'], startPageIndex: p, endPageIndex: p);
      double? numeroLeft = _minLeft(resNumero);
      final idPacoteLeft = _minLeft(resId);
      final clienteLeft = _minLeft(resCliente);
      final enderecoLeft = _minLeft(resEndereco);
      double? numeroEndLeft;
      if (enderecoLeft != null && resNumero.isNotEmpty) {
        final rights = resNumero.map((m) => m.bounds.left).toList()..sort();
        numeroEndLeft = rights.firstWhere((l) => l > enderecoLeft!, orElse: () => -1);
        if (numeroEndLeft <= 0 && rights.length > 1) {
          numeroEndLeft = rights[1];
        }
        // numero de linha (primeira coluna) é o menor left
        numeroLeft = rights.isNotEmpty ? rights.first : numeroLeft;
      }
      final complementoLeft = _minLeft(resComplemento);
      final bairroLeft = _minLeft(resBairro);
      final cidadeLeft = _minLeft(resCidade);
      final cepLeft = _minLeft(resCep);
      final tipoLeft = _minLeft(resTipo);
      final assLeft = _minLeft(resAss);
      final lines = extractor.extractTextLines(startPageIndex: p, endPageIndex: p);
      if (lines.isEmpty) continue;
      final allHeaderTops = <double>[];
      for (final m in [
        ...resNumero,
        ...resId,
        ...resCliente,
        ...resEndereco,
        ...resComplemento,
        ...resBairro,
        ...resCidade,
        ...resCep,
        ...resTipo,
        ...resAss
      ]) {
        allHeaderTops.add(m.bounds.top);
      }
      if (allHeaderTops.isEmpty) continue;
      double headerTop = allHeaderTops.reduce((a, b) => a < b ? a : b);
      final headerBottoms = <double>[];
      for (final m in [
        ...resNumero,
        ...resId,
        ...resCliente,
        ...resEndereco,
        ...resComplemento,
        ...resBairro,
        ...resCidade,
        ...resCep,
        ...resTipo,
        ...resAss
      ]) {
        headerBottoms.add(m.bounds.top + m.bounds.height);
      }
      double headerBottom = headerBottoms.isNotEmpty ? headerBottoms.reduce((a, b) => a > b ? a : b) : headerTop;
      final thresholdTop = headerBottom + 6;
      // Capturar endereço no cabeçalho (entre headerTop e thresholdTop) na coluna Endereço
      String headerAddress = '';
      if (enderecoLeft != null) {
        for (final ln in lines) {
          if (ln.bounds.top <= headerTop || ln.bounds.top > thresholdTop) continue;
          for (final w in ln.wordCollection) {
            final cx = w.bounds.left + w.bounds.width / 2;
            final rightBound = (numeroEndLeft ?? (complementoLeft ?? (bairroLeft ?? (cidadeLeft ?? (cepLeft ?? (tipoLeft ?? (assLeft ?? (enderecoLeft + 200))))))));
            if (cx >= enderecoLeft && cx < rightBound) {
              headerAddress = (headerAddress.isEmpty ? w.text : '$headerAddress ${w.text}').trim();
            }
          }
        }
      }
      // Se não houver coluna Endereço encontrada, tentar pegar a linha mais longa na faixa do cabeçalho
      if (headerAddress.isEmpty) {
        String best = '';
        for (final ln in lines) {
          if (ln.bounds.top <= headerTop || ln.bounds.top > thresholdTop) continue;
          final text = ln.text?.trim() ?? ln.wordCollection.map((w) => w.text).join(' ').trim();
          final norm = _norm(text);
          if (norm.isEmpty) continue;
          // Ignorar rótulos comuns do cabeçalho
          if (norm.contains('id do pacote') || norm.contains('cliente') || norm.contains('cidade') || norm.contains('bairro') || norm.contains('cep')) {
            continue;
          }
          if (text.length > best.length) best = text;
        }
        headerAddress = best;
      }
      final rows = <double, Map<String, String>>{};
      for (final ln in lines) {
        if (ln.bounds.top <= thresholdTop) continue;
        final y = ln.bounds.top;
        final keyY = rows.keys.firstWhere((k) => (k - y).abs() < 2, orElse: () => double.nan);
        final targetY = keyY.isNaN ? y : keyY;
        rows[targetY] ??= {
          'numero': '',
          'idPacote': '',
          'endereco': '',
          'numeroEndereco': '',
          'complemento': '',
          'bairro': '',
          'cidade': '',
          'cep': '',
          'tipoEndereco': '',
          'assinatura': '',
        };
        for (final w in ln.wordCollection) {
          final cx = w.bounds.left + w.bounds.width / 2;
          String col;
          if (numeroLeft != null && cx < (idPacoteLeft ?? cx + 1)) {
            col = 'numero';
          } else if (idPacoteLeft != null && cx < (clienteLeft ?? cx + 1)) {
            col = 'idPacote';
          } else if (enderecoLeft != null && cx < (numeroEndLeft ?? cx + 1)) {
            col = 'endereco';
          } else if (numeroEndLeft != null && cx < (complementoLeft ?? cx + 1)) {
            col = 'numeroEndereco';
          } else if (complementoLeft != null && cx < (bairroLeft ?? cx + 1)) {
            col = 'complemento';
          } else if (bairroLeft != null && cx < (cidadeLeft ?? cx + 1)) {
            col = 'bairro';
          } else if (cidadeLeft != null && cx < (cepLeft ?? cx + 1)) {
            col = 'cidade';
          } else if (cepLeft != null && cx < (tipoLeft ?? cx + 1)) {
            col = 'cep';
          } else if (tipoLeft != null && cx < (assLeft ?? cx + 1)) {
            col = 'tipoEndereco';
          } else {
            col = 'assinatura';
          }
          final prev = rows[targetY]![col]!;
          rows[targetY]![col] = (prev.isEmpty ? w.text : '$prev ${w.text}').trim();
        }
      }
      final sortedKeys = rows.keys.toList()..sort();
      final mergedRows = <Map<String, String>>[];
      for (int i = 0; i < sortedKeys.length; i++) {
        final curr = rows[sortedKeys[i]]!;
        if (i + 1 < sortedKeys.length) {
          final next = rows[sortedKeys[i + 1]]!;
          final currHasId = (curr['idPacote'] ?? '').trim().isNotEmpty;
          final nextHasId = (next['idPacote'] ?? '').trim().isNotEmpty;
          final nextHasText = ((next['endereco'] ?? '').trim().isNotEmpty) ||
              ((next['complemento'] ?? '').trim().isNotEmpty) ||
              ((next['bairro'] ?? '').trim().isNotEmpty) ||
              ((next['cidade'] ?? '').trim().isNotEmpty) ||
              ((next['cep'] ?? '').trim().isNotEmpty);
          if (currHasId && !nextHasId && nextHasText) {
            if ((curr['endereco'] ?? '').trim().isEmpty) {
              curr['endereco'] = next['endereco'] ?? '';
            } else if ((next['endereco'] ?? '').trim().isNotEmpty) {
              curr['endereco'] = '${curr['endereco']} ${next['endereco']}'.trim();
            }
            if ((curr['numeroEndereco'] ?? '').trim().isEmpty && (next['numeroEndereco'] ?? '').trim().isNotEmpty) {
              curr['numeroEndereco'] = next['numeroEndereco']!;
            }
            if ((curr['complemento'] ?? '').trim().isEmpty) {
              curr['complemento'] = next['complemento'] ?? '';
            } else if ((next['complemento'] ?? '').trim().isNotEmpty) {
              curr['complemento'] = '${curr['complemento']} ${next['complemento']}'.trim();
            }
            if ((curr['bairro'] ?? '').trim().isEmpty && (next['bairro'] ?? '').trim().isNotEmpty) {
              curr['bairro'] = next['bairro']!;
            }
            if ((curr['cidade'] ?? '').trim().isEmpty && (next['cidade'] ?? '').trim().isNotEmpty) {
              curr['cidade'] = next['cidade']!;
            }
            if ((curr['cep'] ?? '').trim().isEmpty && (next['cep'] ?? '').trim().isNotEmpty) {
              curr['cep'] = next['cep']!;
            }
            i++; // skip next because merged
          }
        }
        mergedRows.add(curr);
      }
      for (final r in mergedRows) {
        if ((r['endereco'] ?? '').toString().trim().isEmpty && headerAddress.isNotEmpty) {
          r['endereco'] = headerAddress;
        }
        final id = r['idPacote'] ?? '';
        final isIdNumeric = RegExp(r'^\d{6,}$').hasMatch(id);
        if (!isIdNumeric) continue;
        var numeroText = (r['numero'] ?? '').toString().toLowerCase().trim();
        final numOk = RegExp(r'^\d+[a-z]?$').hasMatch(numeroText);
        seq += 1;
        if (!numOk) {
          numeroText = '${seq}a';
        }
        final enderecoText = (r['endereco'] ?? '').toLowerCase();
        if (numeroText.contains('n.º') || numeroText.contains('nº') || numeroText.contains('n°')) continue;
        if (!RegExp(r'\d').hasMatch(numeroText)) continue;
        if (id.toLowerCase() == 'id do pacote') continue;
        if (enderecoText == 'endereço' || enderecoText == 'endereco') continue;
        out.add({
          'numero': numeroText.toUpperCase(),
          'idPacote': r['idPacote'] ?? '',
          'endereco': _abbr(r['endereco'] ?? ''),
          'numeroEndereco': r['numeroEndereco'] ?? '',
          'complemento': _abbr(r['complemento'] ?? ''),
          'bairro': r['bairro'] ?? '',
          'cidade': r['cidade'] ?? '',
          'cep': r['cep'] ?? '',
          'tipoEndereco': '',
          'assinatura': r['assinatura'] ?? '',
          'status': 'pendente',
          'createdAt': DateTime.now().toIso8601String().split('T').first,
        });
      }
    }
    // merge results from both strategies, preferring entries with more filled fields
    final byId = <String, Map<String, dynamic>>{};
    void upsert(Map<String, dynamic> it) {
      final id = (it['idPacote'] ?? '').toString();
      if (id.isEmpty) return;
      if (!byId.containsKey(id)) {
        byId[id] = it;
        return;
      }
      final cur = byId[id]!;
      int filled(Map<String, dynamic> m) {
        int c = 0;
        for (final k in ['numero','idPacote','endereco','numeroEndereco','complemento','bairro','cidade','cep']) {
          final v = (m[k] ?? '').toString().trim();
          if (v.isNotEmpty) c++;
        }
        return c;
      }
      if (filled(it) > filled(cur)) {
        byId[id] = it;
      }
    }
    for (final it in parsedByLines) upsert(it);
    for (final it in out) upsert(it);
    return byId.values.toList();
  }
  static List<Map<String, dynamic>> _parseDataLines(List<dynamic> lines) {
    final out = <Map<String, dynamic>>[];
    var seq = 0;
    for (final ln in lines) {
      final List<TextWord> words = List<TextWord>.from(ln.wordCollection);
      words.sort((TextWord a, TextWord b) => a.bounds.left.compareTo(b.bounds.left));
      if (words.isEmpty) continue;
      final texts = words.map((w) => w.text.trim()).toList();
      int idxId = texts.indexWhere((t) => _isIdToken(t));
      if (idxId < 0) continue;
      int idxCep = -1;
      for (int i = texts.length - 1; i >= 0; i--) {
        if (RegExp(r'^\d{8}$').hasMatch(texts[i]) || RegExp(r'^\d{5}-\d{3}$').hasMatch(texts[i])) {
          idxCep = i;
          break;
        }
      }
      // detectar número possivelmente dividido: "8 AB"
      var numero = '';
      int idxNum = -1;
      for (int i = 0; i < idxId; i++) {
        final t = texts[i];
        if (RegExp(r'^\d+$').hasMatch(t)) {
          final buf = StringBuffer()..write(t);
          int k = i + 1;
          while (k < idxId && RegExp(r'^[A-Za-z]+$').hasMatch(texts[k])) {
            buf.write(texts[k]);
            k++;
          }
          numero = buf.toString();
          idxNum = i;
          break;
        } else if (RegExp(r'^\d+[A-Za-z]*$').hasMatch(t)) {
          numero = t;
          idxNum = i;
          break;
        }
      }
      if (numero.isEmpty) continue;
      final idPacote = texts[idxId];
      final tipoIdx = idxCep >= 0 && (idxCep + 1 < texts.length) && RegExp(r'^[A-Za-z]$').hasMatch(texts[idxCep + 1]) ? idxCep + 1 : -1;
      // se CEP ausente, usar último token alfabético como cidade
      int cidadeIdx = idxCep >= 0 ? idxCep - 1 : -1;
      if (cidadeIdx < 0) {
        for (int i = texts.length - 1; i >= 0; i--) {
          if (_isCityToken(texts[i])) {
            cidadeIdx = i;
            break;
          }
        }
      }
      final bairroIdx = cidadeIdx - 1;
      final cidade = cidadeIdx >= 0 ? texts[cidadeIdx] : '';
      final bairro = bairroIdx >= 0 ? texts[bairroIdx] : '';
      String endereco = '';
      String numeroEndereco = '';
      String complemento = '';
      final endSpanIdx = bairroIdx >= 0 ? bairroIdx : (cidadeIdx >= 0 ? cidadeIdx : texts.length);
      if (idxId + 1 < endSpanIdx) {
        final span = texts.sublist(idxId + 1, endSpanIdx);
        int numEndLocal = span.indexWhere((t) => RegExp(r'^(SN|S/N|\d+)$').hasMatch(t));
        if (numEndLocal >= 0) {
          endereco = span.sublist(0, numEndLocal).join(' ').trim();
          numeroEndereco = span[numEndLocal];
          if (numEndLocal + 1 < span.length) {
            complemento = span.sublist(numEndLocal + 1).join(' ').trim();
          }
        } else {
          endereco = span.join(' ').trim();
        }
      }
      final validId = _isIdToken(idPacote);
      var validNum = RegExp(r'^\d+[A-Za-z]*$').hasMatch(numero);
      if (!validId) continue;
      seq += 1;
      if (!validNum) {
        numero = '${seq}A';
        validNum = true;
      }
      out.add({
        'numero': numero,
        'idPacote': idPacote,
        'endereco': _abbr(endereco),
        'numeroEndereco': numeroEndereco,
        'complemento': _abbr(complemento),
        'bairro': bairro,
        'cidade': cidade,
        'cep': idxCep >= 0 ? texts[idxCep].replaceAll('-', '') : '',
        'tipoEndereco': '',
        'assinatura': '',
        'status': 'pendente',
        'createdAt': DateTime.now().toIso8601String().split('T').first,
      });
    }
    return out;
  }
  static double? _minLeft(List<dynamic> results) {
    if (results.isEmpty) return null;
    double? min;
    for (final r in results) {
      final l = r.bounds.left;
      if (min == null || l < min) min = l;
    }
    return min;
  }

  static bool _isCepToken(String t) {
    final s = t.trim();
    return RegExp(r'^\d{8}$').hasMatch(s) || RegExp(r'^\d{5}-\d{3}$').hasMatch(s);
  }
  static bool _isIdToken(String t) {
    final s = t.trim();
    return RegExp(r'^\d{10,}$').hasMatch(s) && !_isCepToken(s);
  }
  static bool _isCityToken(String t) {
    final s = t.trim().toLowerCase();
    if (!RegExp(r'^[a-zà-ÿ]+$').hasMatch(s)) return false;
    const stop = {'o','a','de','da','do','vista','referencia','casa'};
    return !stop.contains(s);
  }
  static String _abbr(String s) {
    var t = s;
    List<MapEntry<RegExp, String>> rules = [
      MapEntry(RegExp(r'\bAvenida\b', caseSensitive: false), 'Av.'),
      MapEntry(RegExp(r'\bPraça\b', caseSensitive: false), 'Pç.'),
      MapEntry(RegExp(r'\bTravessa\b', caseSensitive: false), 'Tv.'),
      MapEntry(RegExp(r'\bRua\b', caseSensitive: false), 'R.'),
      MapEntry(RegExp(r'\bRodovia\b', caseSensitive: false), 'Rod.'),
      MapEntry(RegExp(r'\bEstrada\b', caseSensitive: false), 'Est.'),
      MapEntry(RegExp(r'\bAlameda\b', caseSensitive: false), 'Al.'),
      MapEntry(RegExp(r'\bConjunto\b', caseSensitive: false), 'Conj.'),
      MapEntry(RegExp(r'\bCondom[ií]nio\b', caseSensitive: false), 'Cond.'),
      MapEntry(RegExp(r'\bResidencial\b', caseSensitive: false), 'Res.'),
      MapEntry(RegExp(r'\bApartamento\b', caseSensitive: false), 'Apto'),
      MapEntry(RegExp(r'\bBloco\b', caseSensitive: false), 'Bl.'),
      MapEntry(RegExp(r'\bQuadra\b', caseSensitive: false), 'Qd.'),
      MapEntry(RegExp(r'\bLote\b', caseSensitive: false), 'Lt.'),
      MapEntry(RegExp(r'\bSetor\b', caseSensitive: false), 'St.'),
      MapEntry(RegExp(r'\bFundos\b', caseSensitive: false), 'Fund.'),
      MapEntry(RegExp(r'\bEsquina\b', caseSensitive: false), 'Esq.'),
      MapEntry(RegExp(r'\bRefer[eê]ncia\b', caseSensitive: false), 'Ref.:'),
      MapEntry(RegExp(r'\bN[úu]mero\b', caseSensitive: false), 'Nº'),
      MapEntry(RegExp(r'\bS/?N\b', caseSensitive: false), 's/n'),
    ];
    for (final r in rules) {
      t = t.replaceAll(r.key, r.value);
    }
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  static String _norm(String s) {
    final lower = s.toLowerCase();
    final buf = StringBuffer();
    for (final ch in lower.runes) {
      final c = String.fromCharCode(ch);
      switch (c) {
        case 'á':
        case 'à':
        case 'ã':
        case 'â':
        case 'ä':
          buf.write('a');
          break;
        case 'é':
        case 'è':
        case 'ê':
        case 'ë':
          buf.write('e');
          break;
        case 'í':
        case 'ì':
        case 'î':
        case 'ï':
          buf.write('i');
          break;
        case 'ó':
        case 'ò':
        case 'õ':
        case 'ô':
        case 'ö':
          buf.write('o');
          break;
        case 'ú':
        case 'ù':
        case 'û':
        case 'ü':
          buf.write('u');
          break;
        case 'ç':
          buf.write('c');
          break;
        case 'º':
        case '°':
          buf.write('º');
          break;
        default:
          buf.write(c);
      }
    }
    return buf.toString();
  }

  static int _posAny(String headerNorm, List<String> patterns) {
    var best = -1;
    for (final p in patterns) {
      final idx = headerNorm.indexOf(_norm(p));
      if (idx >= 0 && (best < 0 || idx < best)) {
        best = idx;
      }
    }
    return best;
  }
  static int _posAnyAfter(String headerNorm, List<String> patterns, int after) {
    var best = -1;
    for (final p in patterns) {
      final needle = _norm(p);
      final idx = headerNorm.indexOf(needle, after);
      if (idx >= 0 && (best < 0 || idx < best)) {
        best = idx;
      }
    }
    return best;
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

class _HeaderItem {
  final double left;
  final double top;
  final double width;
  final double height;
  _HeaderItem(this.left, this.top, this.width, this.height);
}
