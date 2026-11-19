import 'package:flutter_test/flutter_test.dart';
import 'package:ru_app/models/lotacao.dart';
import 'package:ru_app/utils/lotacao_calculo.dart';

void main() {
  group('estimarPresentes', () {
    test('usa as entradas da permanência média', () {
      expect(
          estimarPresentes(entradasNaPermanencia: 80, capacidadeMaxima: 200),
          80);
    });

    test('não passa da capacidade', () {
      expect(
          estimarPresentes(entradasNaPermanencia: 250, capacidadeMaxima: 200),
          200);
    });

    test('nunca é negativo', () {
      expect(estimarPresentes(entradasNaPermanencia: -3), 0);
    });
  });

  test('rotuloJanela', () {
    expect(rotuloJanela(5), '5 min');
    expect(rotuloJanela(60), '1 h');
  });

  test('statusPara', () {
    expect(Lotacao.statusPara(50, 200), 'Baixo movimento');
    expect(Lotacao.statusPara(120, 200), 'Médio movimento');
    expect(Lotacao.statusPara(190, 200), 'Alta ocupação');
    expect(Lotacao.statusPara(10, 0), 'Sem informação');
  });
}
