import 'reserva.dart';

/// Controla quantas marmitas existem e quantas ainda estão disponíveis
/// para uma data + tipo de refeição.
/// Coleção Firestore: disponibilidades/{id}
/// id sugerido = "AAAA-MM-DD_tipoRefeicao" (ex: "2026-09-02_almoco"),
/// isso evita duas pessoas criarem documentos duplicados para o mesmo dia.
///
/// Regra de negócio: quando `quantidadeDisponivel` chega a 0, o app
/// desabilita o botão de reserva (ver ReservaService).
class Disponibilidade {
  final String id;
  final DateTime data;
  final TipoRefeicao tipoRefeicao;
  final int quantidadeTotal;
  final int quantidadeDisponivel;

  Disponibilidade({
    required this.id,
    required this.data,
    required this.tipoRefeicao,
    required this.quantidadeTotal,
    required this.quantidadeDisponivel,
  });

  bool get esgotado => quantidadeDisponivel <= 0;

  factory Disponibilidade.fromMap(String id, Map<String, dynamic> map) {
    return Disponibilidade(
      id: id,
      data: map['data']?.toDate() ?? DateTime.now(),
      tipoRefeicao: tipoRefeicaoFromString(map['tipoRefeicao'] ?? 'almoco'),
      quantidadeTotal: map['quantidadeTotal'] ?? 0,
      quantidadeDisponivel: map['quantidadeDisponivel'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'tipoRefeicao': tipoRefeicaoToString(tipoRefeicao),
      'quantidadeTotal': quantidadeTotal,
      'quantidadeDisponivel': quantidadeDisponivel,
    };
  }
}
