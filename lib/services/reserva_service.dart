import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reserva.dart';
import '../models/disponibilidade.dart';
import 'config_service.dart';
import 'preco_service.dart';

class SaldoInsuficienteException implements Exception {
  final String message = 'Saldo insuficiente para reservar a marmita.';
}

class MarmitaEsgotadaException implements Exception {
  final String message = 'Não há mais marmitas disponíveis para esta refeição.';
}

class ReservaJaExisteException implements Exception {
  final String message = 'Você já tem uma reserva para esta refeição neste dia.';
}

class ForaDoPrazoException implements Exception {
  final String message;
  ForaDoPrazoException(this.message);
}

/// IMPORTANTE: `usuarioId` em todo este arquivo é, na prática, o CPF
/// do usuário (chave primária de `usuarios` — ver Usuario.id em
/// usuario.dart). O nome do parâmetro foi mantido como `usuarioId`
/// para não quebrar as telas que já chamam este serviço passando
/// `widget.usuario.id`.
class ReservaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ConfigService _configService = ConfigService();
  final PrecoService _precoService = PrecoService();

  String _chave(DateTime data, TipoRefeicao tipo) {
    return '${data.year.toString().padLeft(4, '0')}-'
        '${data.month.toString().padLeft(2, '0')}-'
        '${data.day.toString().padLeft(2, '0')}_'
        '${tipoRefeicaoToString(tipo)}';
  }

  Stream<List<Reserva>> reservasDoUsuario(String usuarioId) {
    return _db
        .collection('reservas')
        .where('usuarioId', isEqualTo: usuarioId)
        .orderBy('data', descending: true)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => Reserva.fromMap(d.id, d.data())).toList());
  }

  Stream<Disponibilidade?> disponibilidadeStream(
      DateTime data, TipoRefeicao tipo) {
    final id = _chave(data, tipo);
    return _db.collection('disponibilidades').doc(id).snapshots().map(
            (doc) => doc.exists ? Disponibilidade.fromMap(doc.id, doc.data()!) : null);
  }

  /// Valor que o usuário pagaria pela refeição agora, considerando seu
  /// tipo (estudante paga R$ 4, comum paga R$ 17 — ver PrecoService).
  /// Usado na tela de reserva para mostrar o preço antes de confirmar.
  Future<double> valorParaTipo(String tipoUsuarioString) async {
    final precos = await _precoService.buscarPrecos();
    return tipoUsuarioString == 'comum'
        ? precos[TipoUsuarioPreco.comum]!
        : precos[TipoUsuarioPreco.estudante]!;
  }

  String _chaveReservaAtiva(
      String usuarioId, DateTime data, TipoRefeicao tipo) {
    return '${usuarioId}_${_chave(data, tipo)}';
  }

  /// Cria a reserva.
  ///
  /// Tudo roda em UMA transação do Firestore para garantir que, mesmo
  /// com várias pessoas reservando ao mesmo tempo, a quantidade
  /// disponível nunca fique negativa e o saldo do usuário fique correto.
  ///
  /// Regras aplicadas (definidas pelo grupo):
  /// 1. Usuário só pode ter 1 reserva confirmada por tipo de refeição/dia.
  ///    Isso é garantido por um documento "marcador" com ID
  ///    determinístico (`reservas_ativas/{cpf}_{data}_{tipo}`), lido
  ///    e criado DENTRO da mesma transação — o Firestore não permite
  ///    rodar uma query (`where`) dentro de uma transação, então essa
  ///    é a forma de conseguir uma checagem atômica de "já existe?".
  /// 2. Precisa ter saldo suficiente. O valor cobrado depende do TIPO do
  ///    usuário (estudante = R$ 4, comum = R$ 17), lido de dentro da
  ///    própria transação a partir de usuarios/{cpf}.tipo — garante que
  ///    ninguém pague o preço errado mesmo que o app tenha um dado
  ///    desatualizado em tela.
  /// 3. Precisa haver marmita disponível.
  /// 4. Só pode reservar até o horário de abertura da refeição.
  Future<void> criarReserva({
    required String usuarioId, // = CPF
    required DateTime data,
    required TipoRefeicao tipoRefeicao,
  }) async {
    final horarios = await _configService.buscarHorarios();
    final horario = horarios[tipoRefeicaoToString(tipoRefeicao)]!;
    final aberturaRefeicao = DateTime(
        data.year, data.month, data.day, horario.inicioHora);

    if (DateTime.now().isAfter(aberturaRefeicao)) {
      throw ForaDoPrazoException(
          'O horário de reserva para esta refeição já encerrou.');
    }

    final precos = await _precoService.buscarPrecos();

    final inicioDia = DateTime(data.year, data.month, data.day);
    final dispId = _chave(data, tipoRefeicao);
    final dispRef = _db.collection('disponibilidades').doc(dispId);
    final usuarioRef = _db.collection('usuarios').doc(usuarioId);
    final reservaRef = _db.collection('reservas').doc();
    final movimentacaoRef = _db.collection('movimentacoes').doc();
    final reservaAtivaRef = _db
        .collection('reservas_ativas')
        .doc(_chaveReservaAtiva(usuarioId, data, tipoRefeicao));

    await _db.runTransaction((transacao) async {
      // --- LEITURAS (todas antes de qualquer escrita) ---
      final reservaAtivaSnap = await transacao.get(reservaAtivaRef);
      final dispSnap = await transacao.get(dispRef);
      final usuarioSnap = await transacao.get(usuarioRef);

      if (reservaAtivaSnap.exists) {
        throw ReservaJaExisteException();
      }
      if (!dispSnap.exists) {
        throw MarmitaEsgotadaException();
      }
      final disponivel = dispSnap.data()!['quantidadeDisponivel'] ?? 0;
      if (disponivel <= 0) {
        throw MarmitaEsgotadaException();
      }

      final saldoAtual = (usuarioSnap.data()?['saldoAtual'] ?? 0).toDouble();
      final tipoUsuario = usuarioSnap.data()?['tipo'] ?? 'estudante';
      final valorRefeicao = tipoUsuario == 'comum'
          ? precos[TipoUsuarioPreco.comum]!
          : precos[TipoUsuarioPreco.estudante]!;

      if (saldoAtual < valorRefeicao) {
        throw SaldoInsuficienteException();
      }

      // --- ESCRITAS ---

      // 1. Debita o saldo (valor conforme o tipo do usuário)
      transacao.update(usuarioRef, {'saldoAtual': saldoAtual - valorRefeicao});

      // 2. Reduz a disponibilidade
      transacao.update(dispRef, {'quantidadeDisponivel': disponivel - 1});

      // 3. Cria a reserva (guarda o valor efetivamente cobrado)
      transacao.set(reservaRef, Reserva(
        id: reservaRef.id,
        usuarioId: usuarioId,
        data: inicioDia,
        tipoRefeicao: tipoRefeicao,
        valor: valorRefeicao,
        status: StatusReserva.confirmada,
        criadaEm: DateTime.now(),
      ).toMap());

      // 4. Cria o marcador de "reserva ativa" (garante a unicidade)
      transacao.set(reservaAtivaRef, {
        'usuarioId': usuarioId,
        'reservaId': reservaRef.id,
      });

      // 5. Registra a movimentação de consumo (para o histórico)
      transacao.set(movimentacaoRef, {
        'usuarioId': usuarioId,
        'tipo': 'consumo',
        'valor': valorRefeicao,
        'status': 'aprovada',
        'data': DateTime.now(),
        'reservaId': reservaRef.id,
      });
    });
  }

  /// Cancela a reserva e devolve a marmita para a disponibilidade.
  ///
  /// Regra: só pode cancelar até 1 hora antes da abertura da refeição.
  /// O estorno usa `reserva.valor` (o que foi cobrado de fato), não o
  /// preço atual da tabela — evita inconsistência se o preço mudar
  /// entre a reserva e o cancelamento.
  Future<void> cancelarReserva(Reserva reserva) async {
    final horarios = await _configService.buscarHorarios();
    final horario = horarios[tipoRefeicaoToString(reserva.tipoRefeicao)]!;
    final aberturaRefeicao = DateTime(reserva.data.year, reserva.data.month,
        reserva.data.day, horario.inicioHora);
    final limiteCancelamento =
    aberturaRefeicao.subtract(const Duration(hours: 1));

    if (DateTime.now().isAfter(limiteCancelamento)) {
      throw ForaDoPrazoException(
          'Não é mais possível cancelar: falta menos de 1 hora para a abertura.');
    }

    final reservaRef = _db.collection('reservas').doc(reserva.id);
    final dispId = _chave(reserva.data, reserva.tipoRefeicao);
    final dispRef = _db.collection('disponibilidades').doc(dispId);
    final usuarioRef = _db.collection('usuarios').doc(reserva.usuarioId);
    final movimentacaoRef = _db.collection('movimentacoes').doc();
    final reservaAtivaRef = _db.collection('reservas_ativas').doc(
        _chaveReservaAtiva(
            reserva.usuarioId, reserva.data, reserva.tipoRefeicao));

    await _db.runTransaction((transacao) async {
      // --- LEITURAS (todas antes de qualquer escrita) ---
      final dispSnap = await transacao.get(dispRef);
      final usuarioSnap = await transacao.get(usuarioRef);

      final disponivel = dispSnap.data()?['quantidadeDisponivel'] ?? 0;
      final saldoAtual = (usuarioSnap.data()?['saldoAtual'] ?? 0).toDouble();

      // --- ESCRITAS ---
      transacao.update(reservaRef, {'status': 'cancelada'});
      transacao.update(dispRef, {'quantidadeDisponivel': disponivel + 1});
      transacao.update(usuarioRef, {'saldoAtual': saldoAtual + reserva.valor});
      // Remove o marcador de "reserva ativa" — libera o usuário para
      // fazer uma nova reserva no mesmo dia/refeição, se quiser.
      transacao.delete(reservaAtivaRef);

      transacao.set(movimentacaoRef, {
        'usuarioId': reserva.usuarioId,
        'tipo': 'estorno',
        'valor': reserva.valor,
        'status': 'aprovada',
        'data': DateTime.now(),
        'reservaId': reserva.id,
      });
    });
  }
}