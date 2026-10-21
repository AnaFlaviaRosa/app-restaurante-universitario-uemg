import 'package:flutter_test/flutter_test.dart';
import 'package:ru_app/utils/formatadores.dart';
import 'package:ru_app/utils/validadores.dart';

// Testa as funções puras usadas na aba Perfil:
// iniciaisDoNome (círculo do avatar) e emailValido (editar e-mail).
void main() {
  group('iniciaisDoNome', () {
    test('usa a 1ª letra do primeiro nome e do último sobrenome', () {
      expect(iniciaisDoNome('Ana Flavia Alves Rosa'), 'AR');
    });

    test('nome com duas palavras', () {
      expect(iniciaisDoNome('Maria Silva'), 'MS');
    });

    test('nome com uma palavra só', () {
      expect(iniciaisDoNome('Maria'), 'M');
    });

    test('converte para maiúsculas', () {
      expect(iniciaisDoNome('joão da silva'), 'JS');
    });

    test('ignora espaços extras', () {
      expect(iniciaisDoNome('  Ana   Rosa  '), 'AR');
    });

    test('nome vazio devolve ?', () {
      expect(iniciaisDoNome(''), '?');
      expect(iniciaisDoNome('   '), '?');
    });
  });

  group('emailValido', () {
    test('aceita e-mails bem formados', () {
      expect(emailValido('ana@gmail.com'), isTrue);
      expect(emailValido('  ana.rosa@aluno.uemg.br '), isTrue);
    });

    test('rejeita e-mails mal formados', () {
      expect(emailValido(''), isFalse);
      expect(emailValido('ana'), isFalse);
      expect(emailValido('ana@'), isFalse);
      expect(emailValido('ana@gmail'), isFalse);
      expect(emailValido('ana @gmail.com'), isFalse);
      expect(emailValido('@gmail.com'), isFalse);
    });
  });
}