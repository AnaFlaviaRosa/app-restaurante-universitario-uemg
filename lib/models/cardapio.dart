import 'reserva.dart';

/// Cardápio de um dia/refeição.
/// Coleção Firestore: cardapios/{id}
/// id sugerido = "AAAA-MM-DD_tipoRefeicao", mesmo padrão de Disponibilidade.
///
/// MVP (decisão do grupo): o cardápio é só uma imagem por enquanto.
/// A URL da imagem fica no Firebase Storage; aqui guardamos só o link.
class Cardapio {
  final String id;
  final DateTime data;
  final TipoRefeicao tipoRefeicao;
  final String imagemUrl;

  Cardapio({
    required this.id,
    required this.data,
    required this.tipoRefeicao,
    required this.imagemUrl,
  });

  factory Cardapio.fromMap(String id, Map<String, dynamic> map) {
    return Cardapio(
      id: id,
      data: map['data']?.toDate() ?? DateTime.now(),
      tipoRefeicao: tipoRefeicaoFromString(map['tipoRefeicao'] ?? 'almoco'),
      imagemUrl: map['imagemUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'tipoRefeicao': tipoRefeicaoToString(tipoRefeicao),
      'imagemUrl': imagemUrl,
    };
  }
}
