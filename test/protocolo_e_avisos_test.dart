import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ru_app/models/aviso.dart';
import 'package:ru_app/models/reserva.dart';
import 'package:ru_app/services/config_service.dart';
import 'package:ru_app/utils/codigo_reserva.dart';
import 'package:ru_app/utils/datas.dart';
import 'package:ru_app/utils/lista_do_dia.dart';
import 'package:ru_app/utils/protocolo.dart';

// Testes das regras novas (protocolo de retirada, lista do dia, avisos,
// RU fechado). São testes de funções puras: não abrem o Firebase.

Reserva _reserva({
  StatusReserva status = StatusReserva.confirmada,
  TipoRefeicao tipo = TipoRefeicao.almoco,
  DateTime? data,
  String nome = 'Maria',
  String codigo = 'ABC234',
  bool vegetariana = false,
  DateTime? protocoloAbertoEm,
  String id = 'r1',
}) {
  return Reserva(
    id: id,
    usuarioId: 'u1',
    data: data ?? DateTime(2026, 11, 19),
    tipoRefeicao: tipo,
    valor: 4,
    status: status,
    criadaEm: DateTime(2026, 11, 18, 20),
    vegetariana: vegetariana,
    nome: nome,
    codigo: codigo,
    protocoloAbertoEm: protocoloAbertoEm,
  );
}

void main() {
  group('código do protocolo', () {
    test('tem 6 caracteres do alfabeto sem confusão (0/O, 1/I/L)', () {
      final aleatorio = Random(42);
      for (var i = 0; i < 200; i++) {
        final c = gerarCodigoReserva(aleatorio);
        expect(c.length, tamanhoCodigoReserva);
        for (final ch in c.split('')) {
          expect(alfabetoCodigoReserva.contains(ch), isTrue);
        }
      }
      expect(alfabetoCodigoReserva.contains('0'), isFalse);
      expect(alfabetoCodigoReserva.contains('O'), isFalse);
      expect(alfabetoCodigoReserva.contains('1'), isFalse);
      expect(alfabetoCodigoReserva.contains('I'), isFalse);
      expect(alfabetoCodigoReserva.contains('L'), isFalse);
    });

    test('com a mesma semente gera o mesmo código', () {
      expect(gerarCodigoReserva(Random(7)), gerarCodigoReserva(Random(7)));
    });

    test('codigoComEspaco separa em 3 + 3', () {
      expect(codigoComEspaco('ABC234'), 'ABC 234');
      expect(codigoComEspaco('AB'), 'AB');
    });
  });

  group('status da reserva', () {
    test('liberada vai e volta como texto', () {
      expect(statusReservaFromString('liberada'), StatusReserva.liberada);
      expect(statusReservaToString(StatusReserva.liberada), 'liberada');
    });

    test('todos os status fazem ida e volta', () {
      for (final s in StatusReserva.values) {
        expect(statusReservaFromString(statusReservaToString(s)), s);
      }
    });
  });

  group('validade do protocolo', () {
    final aberto = DateTime(2026, 11, 19, 12, 0, 0);

    test('sem abertura: sem contagem', () {
      final r = _reserva();
      expect(r.protocoloSegundosRestantes(aberto), isNull);
      expect(r.protocoloValido(aberto), isFalse);
    });

    test('conta regressiva a partir da duração', () {
      final r = _reserva(
          status: StatusReserva.utilizada, protocoloAbertoEm: aberto);
      expect(r.protocoloSegundosRestantes(aberto), duracaoProtocoloSegundos);
      expect(r.protocoloSegundosRestantes(aberto.add(const Duration(seconds: 60))),
          duracaoProtocoloSegundos - 60);
      expect(r.protocoloValido(aberto.add(const Duration(seconds: 1))), isTrue);
    });

    test('expira e nunca fica negativo', () {
      final r = _reserva(
          status: StatusReserva.utilizada, protocoloAbertoEm: aberto);
      final depois =
      aberto.add(const Duration(seconds: duracaoProtocoloSegundos));
      expect(r.protocoloSegundosRestantes(depois), 0);
      expect(r.protocoloValido(depois), isFalse);
      expect(r.protocoloSegundosRestantes(depois.add(const Duration(hours: 1))), 0);
    });
  });

  group('podeAbrirProtocolo', () {
    final horario = HorarioRefeicao(inicioHora: 11, fimHora: 14);
    final meioDia = DateTime(2026, 11, 19, 12, 0);
    final cedo = DateTime(2026, 11, 19, 8, 0);
    final tarde = DateTime(2026, 11, 19, 15, 0);

    bool pode(Reserva r, {required bool integracao, required DateTime agora}) =>
        podeAbrirProtocolo(
          reserva: r,
          integracaoCatracaAtiva: integracao,
          horario: horario,
          agora: agora,
        );

    test('liberada na catraca: pode abrir', () {
      final r = _reserva(status: StatusReserva.liberada);
      expect(pode(r, integracao: true, agora: meioDia), isTrue);
    });

    test('confirmada com integração ligada: não pode (precisa da catraca)', () {
      final r = _reserva();
      expect(pode(r, integracao: true, agora: meioDia), isFalse);
    });

    test('confirmada com integração desligada: só dentro do horário', () {
      final r = _reserva();
      expect(pode(r, integracao: false, agora: meioDia), isTrue);
      expect(pode(r, integracao: false, agora: cedo), isFalse);
      expect(pode(r, integracao: false, agora: tarde), isFalse);
    });

    test('já utilizada, não retirada ou cancelada: não pode', () {
      for (final s in [
        StatusReserva.utilizada,
        StatusReserva.naoRetirada,
        StatusReserva.cancelada,
      ]) {
        expect(pode(_reserva(status: s), integracao: false, agora: meioDia),
            isFalse);
      }
    });

    test('reserva de outro dia: não pode', () {
      final ontem = _reserva(
          status: StatusReserva.liberada, data: DateTime(2026, 11, 18));
      expect(pode(ontem, integracao: true, agora: meioDia), isFalse);
    });
  });

  group('horários e RU fechado', () {
    test('estaAbertoEm / encerradoEm', () {
      final h = HorarioRefeicao(inicioHora: 11, fimHora: 14);
      expect(h.estaAbertoEm(DateTime(2026, 11, 19, 10, 59)), isFalse);
      expect(h.estaAbertoEm(DateTime(2026, 11, 19, 11, 0)), isTrue);
      expect(h.estaAbertoEm(DateTime(2026, 11, 19, 13, 59)), isTrue);
      expect(h.estaAbertoEm(DateTime(2026, 11, 19, 14, 0)), isFalse);
      expect(h.encerradoEm(DateTime(2026, 11, 19, 13, 59)), isFalse);
      expect(h.encerradoEm(DateTime(2026, 11, 19, 14, 0)), isTrue);
    });

    test('validarHorarios aceita o padrão e recusa incoerências', () {
      String? v(int ai, int af, int ji, int jf) =>
          ConfigService.validarHorarios(
              almocoInicio: ai, almocoFim: af, jantaInicio: ji, jantaFim: jf);
      expect(v(11, 14, 17, 20), isNull);
      expect(v(14, 11, 17, 20), isNotNull); // almoço termina antes de começar
      expect(v(11, 14, 20, 17), isNotNull); // janta termina antes de começar
      expect(v(11, 18, 17, 20), isNotNull); // janta começa antes do fim do almoço
      expect(v(-1, 14, 17, 20), isNotNull);
      expect(v(11, 14, 17, 24), isNotNull);
    });

    test('StatusRu: fechado só no dia gravado', () {
      final status = StatusRu(fechadoEm: '2026-11-19', motivo: 'Feriado');
      expect(status.fechadoEmDia(DateTime(2026, 11, 19, 15)), isTrue);
      expect(status.fechadoEmDia(DateTime(2026, 11, 20)), isFalse);
      expect(StatusRu().fechadoEmDia(DateTime(2026, 11, 19)), isFalse);
      expect(StatusRu.fromMap(null).fechadoEm, isNull);
    });

    test('chaveDia tem zeros à esquerda', () {
      expect(chaveDia(DateTime(2026, 3, 5)), '2026-03-05');
    });
  });

  group('lista do dia', () {
    test('ordem alfabética, sem canceladas, só a refeição pedida', () {
      final reservas = [
        _reserva(id: 'a', nome: 'Zeca', codigo: 'ZZZ222'),
        _reserva(id: 'b', nome: 'ana', codigo: 'AAA222', vegetariana: true),
        _reserva(
            id: 'c', nome: 'Bia', status: StatusReserva.cancelada),
        _reserva(id: 'd', nome: 'Caio', tipo: TipoRefeicao.janta),
        _reserva(id: 'e', nome: '', codigo: 'XXX333'),
      ];
      final linhas = montarListaDoDia(
        reservas: reservas,
        tipo: TipoRefeicao.almoco,
        nomes: {'e': 'Davi'},
      );
      expect(linhas.map((l) => l.nome).toList(), ['ana', 'Davi', 'Zeca']);
      expect(linhas.first.vegetariana, isTrue);
      expect(linhas.first.codigo, 'AAA222');
    });

    test('texto copiável: cabeçalho, totais, linhas com [ ] e código', () {
      final linhas = [
        const LinhaListaDia(nome: 'Ana', vegetariana: true, codigo: 'AAA222'),
        const LinhaListaDia(nome: 'Zeca', vegetariana: false, codigo: ''),
      ];
      final texto = textoListaDoDia(
        dia: DateTime(2026, 11, 9),
        tipo: TipoRefeicao.almoco,
        linhas: linhas,
      );
      expect(texto, contains('RU UEMG Passos - Almoço - 09/11/2026'));
      expect(texto, contains('Total: 2 marmitas | Vegetarianas: 1'));
      expect(texto, contains('1. [ ] Ana | AAA 222 | VEGETARIANA'));
      expect(texto, contains('2. [ ] Zeca | ------'));
      expect(texto, contains('descartar depois do uso'));
    });

    test('texto copiável de lista vazia avisa que não há reservas', () {
      final texto = textoListaDoDia(
        dia: DateTime(2026, 11, 9),
        tipo: TipoRefeicao.janta,
        linhas: const [],
      );
      expect(texto, contains('Janta'));
      expect(texto, contains('Nenhuma reserva'));
    });

    test('reserva antiga sem nome e sem cadastro vira "(sem nome)"', () {
      final linhas = montarListaDoDia(
        reservas: [_reserva(nome: '')],
        tipo: TipoRefeicao.almoco,
      );
      expect(linhas.single.nome, '(sem nome)');
    });
  });

  group('avisos', () {
    Aviso aviso(String id, {bool importante = false, int minutosAtras = 0}) {
      final base = DateTime(2026, 11, 19, 10);
      return Aviso(
        id: id,
        titulo: id,
        mensagem: 'm',
        importante: importante,
        criadoEm: base.subtract(Duration(minutes: minutosAtras)),
        expiraEm: base.add(const Duration(hours: 5)),
        criadoPor: 'admin',
      );
    }

    test('importantes primeiro, depois o mais recente', () {
      final ordem = ordenarAvisos([
        aviso('velho', minutosAtras: 60),
        aviso('novo', minutosAtras: 5),
        aviso('urgente', importante: true, minutosAtras: 120),
      ]).map((a) => a.id).toList();
      expect(ordem, ['urgente', 'novo', 'velho']);
    });

    test('ativoEm respeita a expiração', () {
      final a = aviso('x');
      expect(a.ativoEm(DateTime(2026, 11, 19, 14, 59)), isTrue);
      expect(a.ativoEm(DateTime(2026, 11, 19, 15, 0)), isFalse);
    });
  });

  group('formatação de tempo', () {
    test('minutosSegundos', () {
      expect(minutosSegundos(180), '03:00');
      expect(minutosSegundos(59), '00:59');
      expect(minutosSegundos(-5), '00:00');
    });

    test('horaCompleta e diaMesHora', () {
      final d = DateTime(2026, 11, 9, 7, 5, 3);
      expect(horaCompleta(d), '07:05:03');
      expect(diaMesHora(d), '09/11 às 07h05');
    });
  });
}