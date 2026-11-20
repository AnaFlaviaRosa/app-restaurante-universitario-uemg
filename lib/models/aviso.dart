/// Aviso do quadro de avisos (a administração informa algo aos usuários,
/// por exemplo "não abriremos hoje").
/// Coleção Firestore: avisos/{id}
///
/// - `importante`: avisos importantes aparecem em destaque (banner) na
///   tela inicial; os demais aparecem em lista.
/// - `expiraEm`: depois desse horário o aviso deixa de aparecer sozinho
///   (o app só lista avisos com `expiraEm` no futuro).
/// - `origem`: 'manual' (admin escreveu) ou 'ru_fechado' (criado pelo
///   botão "RU fechado hoje").
class Aviso {
  final String id;
  final String titulo;
  final String mensagem;
  final bool importante;
  final DateTime criadoEm;
  final DateTime expiraEm;
  final String criadoPor; // uid do admin
  final String origem;

  Aviso({
    required this.id,
    required this.titulo,
    required this.mensagem,
    required this.importante,
    required this.criadoEm,
    required this.expiraEm,
    required this.criadoPor,
    this.origem = 'manual',
  });

  bool ativoEm(DateTime agora) => expiraEm.isAfter(agora);

  factory Aviso.fromMap(String id, Map<String, dynamic> map) {
    return Aviso(
      id: id,
      titulo: map['titulo'] ?? '',
      mensagem: map['mensagem'] ?? '',
      importante: map['importante'] ?? false,
      criadoEm: map['criadoEm']?.toDate() ?? DateTime.now(),
      expiraEm: map['expiraEm']?.toDate() ?? DateTime.now(),
      criadoPor: map['criadoPor'] ?? '',
      origem: map['origem'] ?? 'manual',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'mensagem': mensagem,
      'importante': importante,
      'criadoEm': criadoEm,
      'expiraEm': expiraEm,
      'criadoPor': criadoPor,
      'origem': origem,
    };
  }
}

/// Ordena avisos para exibição: importantes primeiro, depois do mais
/// recente para o mais antigo. Função pura (testável).
List<Aviso> ordenarAvisos(Iterable<Aviso> avisos) {
  final lista = avisos.toList();
  lista.sort((a, b) {
    if (a.importante != b.importante) return a.importante ? -1 : 1;
    return b.criadoEm.compareTo(a.criadoEm);
  });
  return lista;
}
