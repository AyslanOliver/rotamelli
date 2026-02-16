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

  Future<double?> getAvulsoMes(int year, int month) async {
    final resp = await http.get(_url('/api/metrics/avulso-mes', {'year': '$year', 'month': '$month'}));
    if (resp.statusCode >= 400) return null;
    final data = jsonDecode(resp.body);
    final v = data['total'];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
