import 'package:flutter_test/flutter_test.dart';
import 'package:ru_app/utils/validadores.dart';

// Testa lib/utils/validadores.dart. São testes "unitários" (não
// testam telas/widgets) de propósito: as telas do app criam
// conexão com o Firebase assim que são construídas, o que exigiria
// simular o Firebase inteiro no ambiente de teste (pacotes como
// firebase_auth_mocks + fake_cloud_firestore) — um esforço de
// configuração maior do que cabe neste MVP. Fica registrado aqui
// como sugestão de trabalho futuro.
void main() {
  group('validarCpf', () {
    test('aceita CPF válido (dígitos verificadores corretos)', () {
      // 111.444.777-35 é um CPF de teste amplamente usado em sistemas
      // (os dígitos verificadores batem matematicamente, mesmo não
      // pertencendo a ninguém de verdade).
      expect(validarCpf('11144477735'), isTrue);
    });

    test('aceita CPF válido formatado com pontos e traço', () {
      expect(validarCpf('111.444.777-35'), isTrue);
    });

    test('rejeita CPF com dígito verificador errado', () {
      expect(validarCpf('11144477736'), isFalse);
    });

    test('rejeita sequências repetidas (não são CPFs reais)', () {
      expect(validarCpf('11111111111'), isFalse);
      expect(validarCpf('00000000000'), isFalse);
    });

    test('rejeita string com tamanho errado', () {
      expect(validarCpf('123'), isFalse);
      expect(validarCpf(''), isFalse);
      expect(validarCpf('123456789012'), isFalse);
    });
  });

  group('limparCpf', () {
    test('remove pontuação, mantendo só os números', () {
      expect(limparCpf('111.444.777-35'), '11144477735');
    });

    test('não altera uma string que já só tem números', () {
      expect(limparCpf('11144477735'), '11144477735');
    });
  });

  group('formatarCpf', () {
    test('formata um CPF de 11 dígitos', () {
      expect(formatarCpf('11144477735'), '111.444.777-35');
    });

    test('devolve sem alteração se não tiver 11 dígitos', () {
      expect(formatarCpf('123'), '123');
    });
  });
}