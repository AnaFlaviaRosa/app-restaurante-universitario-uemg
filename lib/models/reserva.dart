enum TipoRefeicao { almoco, janta }

enum StatusReserva { confirmada, cancelada, utilizada, naoRetirada }

TipoRefeicao tipoRefeicaoFromString(String v) =>
    v == 'janta' ? TipoRefeicao.janta : TipoRefeicao.almoco;

String tipoRefeicaoToString(TipoRefeicao t) =>
    t == TipoRefeicao.janta ? 'janta' : 'almoco';

StatusReserva statusReservaFromString(String v) {
  switch (v) {
    case 'cancelada':
      return StatusReserva.cancelada;
    case 'utilizada':
      return StatusReserva.utilizada;
    case 'naoRetirada':
      return StatusReserva.naoRetirada;
    case 'confirmada':
    default:
      return StatusReserva.confirmada;
  }
}

String statusReservaToString(StatusReserva s) {
  switch (s) {
    case StatusReserva.cancelada:
      return 'cancelada';
    case StatusReserva.utilizada:
      return 'utilizada';
    case StatusReserva.naoRetirada:
      return 'naoRetirada';
    case StatusReserva.confirmada:
      return 'confirmada';
  }
}

/// Reserva de uma marmita para uma data e um tipo de refeição.
/// Coleção Firestore: reservas/{id}
///
/// Regras de negócio definidas pelo grupo:
/// - 1 marmita por pessoa, por refeição (não pode ter 2 reservas
///   confirmadas de almoço no mesmo dia, por exemplo).
/// - Pode existir reserva de almoço E de janta no mesmo dia para a
///   mesma pessoa (são refeições diferentes).
/// - A marmita é paga no momento da reserva (por isso não existe
///   reserva "não paga" no MVP: reservar == pagar).
/// - Cancelamento permitido até 1h antes da abertura da refeição.
///   Depois disso, não cancela mais.
/// - Se não buscar (`naoRetirada`), o valor continua cobrado
///   (não há estorno automático).
class Reserva {
  final String id;
  final String usuarioId;
  final DateTime data; // dia da refeição (sem hora)
  final TipoRefeicao tipoRefeicao;
  final double valor;
  final StatusReserva status;
  final DateTime criadaEm;

  Reserva({
    required this.id,
    required this.usuarioId,
    required this.data,
    required this.tipoRefeicao,
    required this.valor,
    required this.status,
    required this.criadaEm,
  });

  factory Reserva.fromMap(String id, Map<String, dynamic> map) {
    return Reserva(
      id: id,
      usuarioId: map['usuarioId'] ?? '',
      data: map['data']?.toDate() ?? DateTime.now(),
      tipoRefeicao: tipoRefeicaoFromString(map['tipoRefeicao'] ?? 'almoco'),
      valor: (map['valor'] ?? 0).toDouble(),
      status: statusReservaFromString(map['status'] ?? 'confirmada'),
      criadaEm: map['criadaEm']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuarioId': usuarioId,
      'data': data,
      'tipoRefeicao': tipoRefeicaoToString(tipoRefeicao),
      'valor': valor,
      'status': statusReservaToString(status),
      'criadaEm': criadaEm,
    };
  }

  /// Identificador de disponibilidade correspondente a esta reserva,
  /// no formato usado pela coleção `disponibilidades`
  /// (ver disponibilidade.dart): "AAAA-MM-DD_tipoRefeicao".
  String get chaveDisponibilidade =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}_'
      '${tipoRefeicaoToString(tipoRefeicao)}';
}
