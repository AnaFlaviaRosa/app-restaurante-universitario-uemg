/// Tipo de movimentação financeira do usuário.
enum TipoMovimentacao { recarga, consumo, estorno }

/// Status da movimentação (importante principalmente para RECARGA,
/// já que no MVP a recarga é simulada e passa por um estado pendente).
enum StatusMovimentacao { pendente, aprovada, recusada }

TipoMovimentacao tipoMovimentacaoFromString(String v) {
  switch (v) {
    case 'consumo':
      return TipoMovimentacao.consumo;
    case 'estorno':
      return TipoMovimentacao.estorno;
    case 'recarga':
    default:
      return TipoMovimentacao.recarga;
  }
}

StatusMovimentacao statusMovimentacaoFromString(String v) {
  switch (v) {
    case 'aprovada':
      return StatusMovimentacao.aprovada;
    case 'recusada':
      return StatusMovimentacao.recusada;
    case 'pendente':
    default:
      return StatusMovimentacao.pendente;
  }
}

/// Registra toda alteração de saldo do usuário.
/// Coleção Firestore: movimentacoes/{id}
///
/// Regra de negócio (decisão do grupo): saldo e histórico são conceitos
/// diferentes, mas vinculados. O saldo atual fica em `usuarios.saldoAtual`;
/// cada alteração desse saldo gera um documento aqui.
class Movimentacao {
  final String id;
  final String usuarioId;
  final TipoMovimentacao tipo;
  final double valor;
  final StatusMovimentacao status;
  final DateTime data;
  final String? reservaId; // preenchido quando tipo == consumo/estorno

  Movimentacao({
    required this.id,
    required this.usuarioId,
    required this.tipo,
    required this.valor,
    required this.status,
    required this.data,
    this.reservaId,
  });

  factory Movimentacao.fromMap(String id, Map<String, dynamic> map) {
    return Movimentacao(
      id: id,
      usuarioId: map['usuarioId'] ?? '',
      tipo: tipoMovimentacaoFromString(map['tipo'] ?? 'recarga'),
      valor: (map['valor'] ?? 0).toDouble(),
      status: statusMovimentacaoFromString(map['status'] ?? 'pendente'),
      data: map['data']?.toDate() ?? DateTime.now(),
      reservaId: map['reservaId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuarioId': usuarioId,
      'tipo': tipoMovimentacaoToStringHelper(tipo),
      'valor': valor,
      'status': statusMovimentacaoToStringHelper(status),
      'data': data,
      'reservaId': reservaId,
    };
  }
}

String tipoMovimentacaoToStringHelper(TipoMovimentacao t) {
  switch (t) {
    case TipoMovimentacao.consumo:
      return 'consumo';
    case TipoMovimentacao.estorno:
      return 'estorno';
    case TipoMovimentacao.recarga:
      return 'recarga';
  }
}

String statusMovimentacaoToStringHelper(StatusMovimentacao s) {
  switch (s) {
    case StatusMovimentacao.aprovada:
      return 'aprovada';
    case StatusMovimentacao.recusada:
      return 'recusada';
    case StatusMovimentacao.pendente:
      return 'pendente';
  }
}
