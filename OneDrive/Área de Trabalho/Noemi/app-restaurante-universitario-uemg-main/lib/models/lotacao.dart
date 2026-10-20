/// Lotação atual do RU.
/// Coleção Firestore: lotacao/atual  (documento único, sempre sobrescrito)
///
/// Decisão do grupo: no MVP não existe câmera/catraca/reconhecimento facial.
/// Um administrador atualiza esse número manualmente. A integração
/// automática (sensor, câmera, etc.) fica documentada como melhoria futura.
class Lotacao {
  final int quantidadeAtual;
  final int capacidadeMaxima;
  final DateTime atualizadoEm;
  final String atualizadoPor; // uid do administrador

  Lotacao({
    required this.quantidadeAtual,
    required this.capacidadeMaxima,
    required this.atualizadoEm,
    required this.atualizadoPor,
  });

  /// Classificação simples usada na tela do estudante
  /// ("Baixo movimento" / "Médio movimento" / "Alta ocupação").
  String get statusTexto {
    if (capacidadeMaxima <= 0) return 'Sem informação';
    final percentual = quantidadeAtual / capacidadeMaxima;
    if (percentual < 0.5) return 'Baixo movimento';
    if (percentual < 0.85) return 'Médio movimento';
    return 'Alta ocupação';
  }

  factory Lotacao.fromMap(Map<String, dynamic> map) {
    return Lotacao(
      quantidadeAtual: map['quantidadeAtual'] ?? 0,
      capacidadeMaxima: map['capacidadeMaxima'] ?? 0,
      atualizadoEm: map['atualizadoEm']?.toDate() ?? DateTime.now(),
      atualizadoPor: map['atualizadoPor'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quantidadeAtual': quantidadeAtual,
      'capacidadeMaxima': capacidadeMaxima,
      'atualizadoEm': atualizadoEm,
      'atualizadoPor': atualizadoPor,
    };
  }
}
