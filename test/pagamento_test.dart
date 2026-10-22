import 'package:flutter_test/flutter_test.dart';
import 'package:ru_app/utils/pagamento.dart';

void main() {
  group('formatarDinheiro', () {
    test('formata com vírgula e milhar', () {
      expect(formatarDinheiro(0), 'R\$ 0,00');
      expect(formatarDinheiro(12.5), 'R\$ 12,50');
      expect(formatarDinheiro(1234.5), 'R\$ 1.234,50');
    });
  });

  group('erroValorRecarga', () {
    test('valida mínimo e máximo', () {
      expect(erroValorRecarga(null), isNotNull);
      expect(erroValorRecarga(4.99), isNotNull);
      expect(erroValorRecarga(500.01), isNotNull);
      expect(erroValorRecarga(5), isNull);
      expect(erroValorRecarga(500), isNull);
    });
  });

  group('cartão', () {
    test('detecta a bandeira', () {
      expect(detectarBandeira('4242 4242 4242 4242'), BandeiraCartao.visa);
      expect(detectarBandeira('5555555555554444'), BandeiraCartao.mastercard);
      expect(detectarBandeira('2223003122003222'), BandeiraCartao.mastercard);
      expect(detectarBandeira('378282246310005'), BandeiraCartao.amex);
      expect(detectarBandeira('6362970000457013'), BandeiraCartao.elo);
      expect(detectarBandeira('6062825624254001'), BandeiraCartao.hipercard);
      expect(detectarBandeira('9999'), BandeiraCartao.desconhecida);
    });

    test('formata o número', () {
      expect(formatarNumeroCartao('4242424242424242'), '4242 4242 4242 4242');
      expect(formatarNumeroCartao('42424'), '4242 4');
      expect(formatarNumeroCartao('378282246310005'), '3782 822463 10005');
    });

    test('Luhn', () {
      expect(luhnValido('4242 4242 4242 4242'), isTrue);
      expect(luhnValido('4000 0000 0000 0002'), isTrue);
      expect(luhnValido('4242 4242 4242 4243'), isFalse);
      expect(luhnValido('1234'), isFalse);
    });

    test('validade', () {
      final hoje = DateTime(2026, 10, 22);
      expect(validadeValida('10/26', hoje), isTrue); // vale até o fim do mês
      expect(validadeValida('09/26', hoje), isFalse);
      expect(validadeValida('12/30', hoje), isTrue);
      expect(validadeValida('13/30', hoje), isFalse);
      expect(validadeValida('1', hoje), isFalse);
      expect(formatarValidade('1228'), '12/28');
      expect(formatarValidade('12'), '12');
    });

    test('cartões de teste', () {
      expect(motivoRecusaSimulada('4242 4242 4242 4242'), isNull);
      expect(motivoRecusaSimulada('4000 0000 0000 0002'), isNotNull);
      expect(motivoRecusaSimulada('4000 0000 0000 9995'), isNotNull);
    });
  });

  group('Pix', () {
    test('CRC16/CCITT-FALSE bate com o valor de referência', () {
      expect(crc16Ccitt('123456789'), 0x29B1);
    });

    test('copia e cola tem estrutura e CRC corretos', () {
      final codigo = gerarPixCopiaECola(
        valor: 12.5,
        chave: chavePixRuSimulada,
        txid: 'ABC123',
      );
      expect(codigo.startsWith('000201'), isTrue);
      expect(codigo.contains('br.gov.bcb.pix'), isTrue);
      expect(codigo.contains('540512.50'), isTrue);
      final semCrc = codigo.substring(0, codigo.length - 4);
      final crc = codigo.substring(codigo.length - 4);
      expect(semCrc.endsWith('6304'), isTrue);
      expect(
        crc16Ccitt(semCrc).toRadixString(16).toUpperCase().padLeft(4, '0'),
        crc,
      );
    });

    test('ids gerados têm o tamanho esperado', () {
      expect(gerarTxid().length, 25);
      expect(gerarIdTransacaoPix(DateTime(2026, 10, 22, 17, 43)).length, 32);
      expect(gerarCodigoAutorizacao().length, 6);
    });
  });
}
