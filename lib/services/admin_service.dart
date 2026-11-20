import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/aviso.dart';
import '../models/disponibilidade.dart';
import '../models/reserva.dart';
import '../utils/datas.dart';

/// Ações exclusivas do administrador: definir quantidade de marmitas
/// disponíveis por dia/refeição e visualizar as reservas.
///
/// Observação de arquitetura (decisão do grupo): não existe uma
/// entidade "Administrador" separada — é um `Usuario` com
/// `tipo == TipoUsuario.admin`. A proteção de quem pode chamar estes
/// métodos é feita nas regras de segurança do Firestore
/// (ver firestore.rules), não apenas no app.
class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Limite das regras do Firestore: no máximo 20 chamadas exists()/get()
  /// por lote de escritas, e cada escrita do admin gasta 2 (a checagem
  /// `souAdmin()`). Por isso os lotes do admin são PEQUENOS: 8 escritas
  /// de uma vez (16 chamadas) — e, no fechamento do RU, 2 reservas por
  /// lote (4 escritas cada). Lotes maiores seriam recusados pelas regras.
  static const int _escritasPorLote = 8;
  static const int _reservasPorLoteEstorno = 2;

  String _chave(DateTime data, TipoRefeicao tipo) {
    return '${data.year.toString().padLeft(4, '0')}-'
        '${data.month.toString().padLeft(2, '0')}-'
        '${data.day.toString().padLeft(2, '0')}_'
        '${tipoRefeicaoToString(tipo)}';
  }

  /// Define quantas marmitas existem para uma data/refeição.
  /// Se já existirem reservas feitas, `quantidadeDisponivel` é ajustada
  /// mantendo a proporção já consumida.
  Future<void> definirDisponibilidade({
    required DateTime data,
    required TipoRefeicao tipo,
    required int quantidadeTotal,
  }) async {
    final id = _chave(data, tipo);
    final ref = _db.collection('disponibilidades').doc(id);

    await _db.runTransaction((transacao) async {
      final snap = await transacao.get(ref);
      int jaReservadas = 0;
      if (snap.exists) {
        final total = snap.data()!['quantidadeTotal'] ?? 0;
        final disponivel = snap.data()!['quantidadeDisponivel'] ?? 0;
        jaReservadas = total - disponivel;
      }
      final novaDisponivel = (quantidadeTotal - jaReservadas)
          .clamp(0, quantidadeTotal);

      transacao.set(ref, Disponibilidade(
        id: id,
        data: DateTime(data.year, data.month, data.day),
        tipoRefeicao: tipo,
        quantidadeTotal: quantidadeTotal,
        quantidadeDisponivel: novaDisponivel,
      ).toMap());
    });
  }

  Stream<List<Reserva>> reservasPorDia(DateTime data) {
    final inicioDia = DateTime(data.year, data.month, data.day);
    final fimDia = inicioDia.add(const Duration(days: 1));
    return _db
        .collection('reservas')
        .where('data', isGreaterThanOrEqualTo: inicioDia)
        .where('data', isLessThan: fimDia)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Reserva.fromMap(d.id, d.data())).toList());
  }

  /// Marca uma reserva confirmada como "não retirada" (a pessoa não
  /// buscou a marmita). Não há estorno — a regra do grupo é que a
  /// marmita já foi paga na reserva.
  Future<void> marcarNaoRetirada(String reservaId) {
    return _db
        .collection('reservas')
        .doc(reservaId)
        .update({'status': 'naoRetirada'});
  }

  /// Marca a reserva como utilizada (a pessoa retirou a marmita).
  Future<void> marcarUtilizada(String reservaId) {
    return _db
        .collection('reservas')
        .doc(reservaId)
        .update({'status': 'utilizada'});
  }

  // ---------- reservas do dia ----------

  /// Busca (uma vez) as reservas do dia.
  Future<List<Reserva>> reservasDoDia(DateTime data) async {
    final inicioDia = DateTime(data.year, data.month, data.day);
    final fimDia = inicioDia.add(const Duration(days: 1));
    final snap = await _db
        .collection('reservas')
        .where('data', isGreaterThanOrEqualTo: inicioDia)
        .where('data', isLessThan: fimDia)
        .get();
    return snap.docs.map((d) => Reserva.fromMap(d.id, d.data())).toList();
  }

  /// Fim da refeição: marca como "não retirada" todas as reservas do
  /// dia/refeição que ficaram `confirmada` (nunca passaram) ou
  /// `liberada` (passaram na catraca mas não retiraram). Não há
  /// estorno. Devolve quantas foram marcadas.
  Future<int> encerrarRefeicao(DateTime data, TipoRefeicao tipo) async {
    final reservas = await reservasDoDia(data);
    final pendentes = reservas.where((r) =>
        r.tipoRefeicao == tipo &&
        (r.status == StatusReserva.confirmada ||
            r.status == StatusReserva.liberada));

    var marcadas = 0;
    var lote = _db.batch();
    var noLote = 0;
    for (final r in pendentes) {
      lote.update(_db.collection('reservas').doc(r.id),
          {'status': 'naoRetirada'});
      marcadas++;
      noLote++;
      if (noLote == _escritasPorLote) {
        await lote.commit();
        lote = _db.batch();
        noLote = 0;
      }
    }
    if (noLote > 0) await lote.commit();
    return marcadas;
  }

  /// Corrige um status marcado por engano (só o admin faz isso):
  /// volta a reserva para `confirmada` ou `liberada` e limpa o horário
  /// de abertura do protocolo, para ele poder ser aberto de novo.
  Future<void> reverterStatus(String reservaId, StatusReserva para) {
    assert(para == StatusReserva.confirmada || para == StatusReserva.liberada);
    return _db.collection('reservas').doc(reservaId).update({
      'status': statusReservaToString(para),
      'protocoloAbertoEm': FieldValue.delete(),
    });
  }

  // ---------- RU fechado hoje ----------

  /// Quantas reservas confirmadas (ainda não liberadas) o fechamento
  /// do dia vai cancelar e estornar. Usado na confirmação do botão.
  Future<int> contarReservasParaEstorno(DateTime data) async {
    final reservas = await reservasDoDia(data);
    return reservas.where((r) => r.status == StatusReserva.confirmada).length;
  }

  /// Botão "RU fechado hoje":
  ///  1. grava `config/status` (bloqueia novas reservas no dia);
  ///  2. publica um aviso importante (id fixo por dia, então apertar de
  ///     novo atualiza o mesmo aviso, sem duplicar);
  ///  3. zera a disponibilidade de marmitas do dia, se existir;
  ///  4. cancela e ESTORNA as reservas ainda `confirmadas` do dia.
  ///
  /// Reservas `liberada`/`utilizada` não são mexidas (a pessoa já
  /// estava no RU). Se algo falhar no meio do estorno, é seguro
  /// apertar o botão de novo: só as reservas ainda `confirmadas` são
  /// processadas. Devolve quantas reservas foram estornadas.
  Future<int> fecharRuHoje({
    required DateTime data,
    required String motivo,
    required String adminId,
  }) async {
    final dia = DateTime(data.year, data.month, data.day);
    final chave = chaveDia(dia);
    final agora = DateTime.now();
    final fimDoDia = DateTime(dia.year, dia.month, dia.day, 23, 59, 59);
    final textoMotivo = motivo.trim();

    // 1-3: bloqueio, aviso e disponibilidade zerada.
    final dispRefs = [
      for (final t in TipoRefeicao.values)
        _db.collection('disponibilidades').doc(_chave(dia, t)),
    ];
    final dispSnaps = await Future.wait(dispRefs.map((r) => r.get()));

    final base = _db.batch();
    base.set(_db.collection('config').doc('status'), {
      'fechadoEm': chave,
      'motivo': textoMotivo,
      'fechadoPor': adminId,
      'fechadoAs': agora,
    });
    base.set(
      _db.collection('avisos').doc('ru_fechado_$chave'),
      Aviso(
        id: 'ru_fechado_$chave',
        titulo: 'RU fechado hoje',
        mensagem: textoMotivo.isEmpty
            ? 'O restaurante universitário não abrirá hoje. '
                'Reservas confirmadas foram canceladas e estornadas.'
            : '$textoMotivo\nReservas confirmadas foram canceladas e '
                'estornadas.',
        importante: true,
        criadoEm: agora,
        expiraEm: fimDoDia.isAfter(agora)
            ? fimDoDia
            : agora.add(const Duration(hours: 1)),
        criadoPor: adminId,
        origem: 'ru_fechado',
      ).toMap(),
    );
    for (var i = 0; i < dispRefs.length; i++) {
      if (dispSnaps[i].exists) {
        base.update(dispRefs[i], {'quantidadeDisponivel': 0});
      }
    }
    await base.commit();

    // 4: cancela e estorna as reservas confirmadas (4 escritas cada;
    // 2 reservas por lote — ver [_reservasPorLoteEstorno]).
    final confirmadas = (await reservasDoDia(dia))
        .where((r) => r.status == StatusReserva.confirmada)
        .toList();

    var estornadas = 0;
    for (var i = 0; i < confirmadas.length; i += _reservasPorLoteEstorno) {
      final fatia = confirmadas.skip(i).take(_reservasPorLoteEstorno);
      final lote = _db.batch();
      for (final r in fatia) {
        lote.update(_db.collection('reservas').doc(r.id),
            {'status': 'cancelada'});
        lote.update(_db.collection('usuarios').doc(r.usuarioId),
            {'saldoAtual': FieldValue.increment(r.valor)});
        lote.delete(_db
            .collection('reservas_ativas')
            .doc('${r.usuarioId}_${_chave(r.data, r.tipoRefeicao)}'));
        lote.set(_db.collection('movimentacoes').doc(), {
          'usuarioId': r.usuarioId,
          'tipo': 'estorno',
          'valor': r.valor,
          'status': 'aprovada',
          'data': agora,
          'reservaId': r.id,
          'detalhe': 'RU fechado',
        });
        estornadas++;
      }
      await lote.commit();
    }
    return estornadas;
  }

  /// Desfaz o "RU fechado": libera novas reservas e retira o aviso.
  /// A quantidade de marmitas continua zerada: o admin precisa
  /// defini-la de novo na aba Marmitas.
  Future<void> reabrirRu(DateTime data) async {
    final chave = chaveDia(DateTime(data.year, data.month, data.day));
    final lote = _db.batch();
    lote.delete(_db.collection('config').doc('status'));
    lote.delete(_db.collection('avisos').doc('ru_fechado_$chave'));
    await lote.commit();
  }
}
