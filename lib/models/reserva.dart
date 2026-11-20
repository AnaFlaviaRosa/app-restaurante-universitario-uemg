enum TipoRefeicao { almoco, janta }

/// Ciclo de vida da reserva:
///   confirmada  -> paga, aguardando a pessoa chegar.
///   liberada    -> a pessoa passou na catraca (a ponte da catraca marca).
///   utilizada   -> o protocolo foi aberto/entregue: a marmita foi retirada.
///   naoRetirada -> a refeição acabou sem retirada (não há estorno).
///   cancelada   -> cancelada pelo usuário (com estorno) ou RU fechado.
enum StatusReserva {
  confirmada,
  liberada,
  cancelada,
  utilizada,
  naoRetirada,
}

TipoRefeicao tipoRefeicaoFromString(String v) =>
    v == 'janta' ? TipoRefeicao.janta : TipoRefeicao.almoco;

String tipoRefeicaoToString(TipoRefeicao t) =>
    t == TipoRefeicao.janta ? 'janta' : 'almoco';

StatusReserva statusReservaFromString(String v) {
  switch (v) {
    case 'cancelada':
      return StatusReserva.cancelada;
    case 'liberada':
      return StatusReserva.liberada;
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
    case StatusReserva.liberada:
      return 'liberada';
    case StatusReserva.utilizada:
      return 'utilizada';
    case StatusReserva.naoRetirada:
      return 'naoRetirada';
    case StatusReserva.confirmada:
      return 'confirmada';
  }
}

/// Rótulo em português para exibir o status ao usuário.
String statusReservaRotulo(StatusReserva s) {
  switch (s) {
    case StatusReserva.confirmada:
      return 'Confirmada';
    case StatusReserva.liberada:
      return 'Liberada na catraca';
    case StatusReserva.cancelada:
      return 'Cancelada';
    case StatusReserva.utilizada:
      return 'Utilizada';
    case StatusReserva.naoRetirada:
      return 'Não retirada';
  }
}

/// Alfabeto do código/protocolo da reserva: sem 0/O, 1/I/L, para não
/// confundir quando o funcionário lê o código na tela ou na lista.
const String alfabetoCodigoReserva = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const int tamanhoCodigoReserva = 6;

/// Quanto tempo (em segundos) o protocolo fica visível depois de aberto.
const int duracaoProtocoloSegundos = 180;

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
/// - O protocolo (código curto + tela com relógio) é aberto pelo
///   usuário na hora da retirada: a abertura grava `protocoloAbertoEm`
///   (hora do SERVIDOR) e muda o status para `utilizada`. Ele só pode
///   ser aberto uma vez; depois de [duracaoProtocoloSegundos] a tela
///   mostra "já utilizado".
class Reserva {
  final String id;
  final String usuarioId;
  final DateTime data; // dia da refeição (sem hora)
  final TipoRefeicao tipoRefeicao;
  final double valor;
  final StatusReserva status;
  final DateTime criadaEm;

  /// Opção vegetariana escolhida na reserva (false em reservas antigas).
  final bool vegetariana;

  /// Nome do usuário gravado na reserva (o funcionário/lista impressa
  /// mostra o nome sem precisar ler o documento do usuário, onde fica o
  /// CPF). Vazio em reservas antigas.
  final String nome;

  /// Código curto do protocolo (6 caracteres). Vazio em reservas antigas.
  final String codigo;

  /// Quando a catraca liberou a reserva (passagem reconhecida).
  final DateTime? liberadaEm;

  /// Quando o protocolo foi aberto (hora do servidor). Nulo se ainda
  /// não foi aberto.
  final DateTime? protocoloAbertoEm;

  Reserva({
    required this.id,
    required this.usuarioId,
    required this.data,
    required this.tipoRefeicao,
    required this.valor,
    required this.status,
    required this.criadaEm,
    this.vegetariana = false,
    this.nome = '',
    this.codigo = '',
    this.liberadaEm,
    this.protocoloAbertoEm,
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
      vegetariana: map['vegetariana'] ?? false,
      nome: map['nome'] ?? '',
      codigo: map['codigo'] ?? '',
      liberadaEm: map['liberadaEm']?.toDate(),
      protocoloAbertoEm: map['protocoloAbertoEm']?.toDate(),
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
      'vegetariana': vegetariana,
      'nome': nome,
      'codigo': codigo,
    };
  }

  /// Segundos que ainda faltam para o protocolo expirar, em [agora].
  /// Nulo se o protocolo nunca foi aberto. Nunca negativo.
  int? protocoloSegundosRestantes(DateTime agora) {
    final aberto = protocoloAbertoEm;
    if (aberto == null) return null;
    final restante =
        duracaoProtocoloSegundos - agora.difference(aberto).inSeconds;
    return restante < 0 ? 0 : restante;
  }

  /// O protocolo foi aberto e ainda está dentro da validade.
  bool protocoloValido(DateTime agora) {
    final r = protocoloSegundosRestantes(agora);
    return r != null && r > 0;
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