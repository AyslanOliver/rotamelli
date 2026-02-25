import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/rota.dart';
import '../models/despesa.dart';

class ApiService {
  final String baseUrl;
  ApiService(this.baseUrl);

  Uri _url(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Future<bool> ping() async {
    try {
      final resp = await http.get(_url('/health')).timeout(const Duration(seconds: 6));
      return resp.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  Future<void> postRota(Rota r) async {
    final resp = await http.post(
      _url('/api/rotas'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(r.toMap()),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Falha ao enviar rota: ${resp.statusCode}');
    }
  }

  Future<void> postDespesa(Despesa d) async {
    final body = d.toMap();
    final resp = await http.post(
      _url('/api/despesas'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Falha ao enviar despesa: ${resp.statusCode}');
    }
  }

  Future<void> putRota(Rota r) async {
    final resp = await http.put(
      _url('/api/rotas/${r.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(r.toMap()),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Falha ao atualizar rota: ${resp.statusCode}');
    }
  }

  Future<void> deleteRota(int id) async {
    final resp = await http.delete(_url('/api/rotas/$id'));
    if (resp.statusCode >= 400) {
      throw Exception('Falha ao excluir rota: ${resp.statusCode}');
    }
  }

  Future<void> putDespesa(Despesa d) async {
    final resp = await http.put(
      _url('/api/despesas/${d.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(d.toMap()),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Falha ao atualizar despesa: ${resp.statusCode}');
    }
  }

  Future<void> deleteDespesa(int id) async {
    final resp = await http.delete(_url('/api/despesas/$id'));
    if (resp.statusCode >= 400) {
      throw Exception('Falha ao excluir despesa: ${resp.statusCode}');
    }
  }

  Future<double?> getAvulsoMes(int year, int month) async {
    final resp = await http.get(_url('/api/metrics/avulso-mes', {'year': '$year', 'month': '$month'}));
    if (resp.statusCode >= 400) return null;
    final data = jsonDecode(resp.body);
    final v = data['total'];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Future<Map<String, dynamic>> importAll({required List<Rota> rotas, required List<Despesa> despesas}) async {
    final body = {
      'rotas': rotas.map((r) => r.toMap()).toList(),
      'despesas': despesas.map((d) => d.toMap()).toList(),
    };
    final resp = await http.post(
      _url('/api/import'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Falha ao importar: ${resp.statusCode} ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
