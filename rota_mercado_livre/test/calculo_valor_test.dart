import 'package:flutter_test/flutter_test.dart';
import 'package:rota_mercado_livre/utils/calculo_valor.dart';

void main() {
  group('CalculoValor.calcularValorTotal', () {
    test('valor base passeio sem adicionais', () {
      final date = DateTime(2026, 2, 7); // sábado
      final total = CalculoValor.calcularValorTotal(
        tipoVeiculo: 'passeio',
        dataRota: date,
        quantidadePacotes: 10,
      );
      expect(total, CalculoValor.valorPasseio);
    });

    test('valor base utilitario sem adicionais', () {
      final date = DateTime(2026, 2, 7); // sábado
      final total = CalculoValor.calcularValorTotal(
        tipoVeiculo: 'utilitario',
        dataRota: date,
        quantidadePacotes: 10,
      );
      expect(total, CalculoValor.valorUtilitario);
    });

    test('adicional domingo aplicado', () {
      final date = DateTime(2026, 2, 8); // domingo
      final total = CalculoValor.calcularValorTotal(
        tipoVeiculo: 'passeio',
        dataRota: date,
        quantidadePacotes: 10,
      );
      expect(
        total,
        CalculoValor.valorPasseio + CalculoValor.adicionalDomingo,
      );
    });

    test('adicional 80+ pacotes aplicado', () {
      final date = DateTime(2026, 2, 7); // sábado
      final total = CalculoValor.calcularValorTotal(
        tipoVeiculo: 'passeio',
        dataRota: date,
        quantidadePacotes: 80,
      );
      expect(
        total,
        CalculoValor.valorPasseio + CalculoValor.adicional80Pacotes,
      );
    });

    test('ambos adicionais (domingo e 80+ pacotes)', () {
      final date = DateTime(2026, 2, 8); // domingo
      final total = CalculoValor.calcularValorTotal(
        tipoVeiculo: 'utilitario',
        dataRota: date,
        quantidadePacotes: 85,
      );
      expect(
        total,
        CalculoValor.valorUtilitario +
            CalculoValor.adicionalDomingo +
            CalculoValor.adicional80Pacotes,
      );
    });

    test('pacotes a vulso soma 2 por unidade', () {
      final date = DateTime(2026, 2, 7); // sábado
      final total = CalculoValor.calcularValorTotal(
        tipoVeiculo: 'passeio',
        dataRota: date,
        quantidadePacotes: 10,
        pacotesVulso: 3,
      );
      expect(
        total,
        CalculoValor.valorPasseio,
      );
    });
  });
}
