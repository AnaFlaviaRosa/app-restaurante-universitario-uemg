/// Lotação atual do RU.
/// Coleção Firestore: lotacao/atual  (documento único, sempre sobrescrito)
///
/// Dois modos de funcionamento (campo `modo`):
/// - `manual`: um administrador informa quantas pessoas estão no RU
///   (comportamento original do MVP).
/// - `catraca`: cada passagem pela catraca grava um evento em
///   `lotacao_eventos`; o app CONTA os eventos da janela escolhida e
///   ESTIMA quantas pessoas estão dentro usando a permanência média
///   (`permanenciaMediaMin`). Ver lib/utils/lotacao_calculo.dart.
class Lotacao {
  static const modoManual = 'manual';
  static const modoCatraca = 'catraca';

  /// Valor usado quando o documento ainda não tem a permanência média.
  static const permanenciaPadraoMin = 30;

  final int quantidadeAtual;
  final int capacidadeMaxima;
  final DateTime atualizadoEm;
  final String atualizadoPor; // uid do administrador
  final String modo; // 'manual' ou 'catraca'
  final int permanenciaMediaMin; // tempo médio de uma pessoa no RU

  Lotacao({
    required this.quantidadeAtual,
    required this.capacidadeMaxima,
    required this.atualizadoEm,
    required this.atualizadoPor,
    this.modo = modoManual,
    this.permanenciaMediaMin = permanenciaPadraoMin,
  });

  bool get usaCatraca => modo == modoCatraca;

  /// Classificação simples usada na tela do estudante
  /// ("Baixo movimento" / "Médio movimento" / "Alta ocupação").
  String get statusTexto => statusPara(quantidadeAtual, capacidadeMaxima);

  /// Mesma classificação para qualquer quantidade (usada com a
  /// estimativa vinda da catraca).
  static String statusPara(int quantidade, int capacidade) {
    if (capacidade <= 0) return 'Sem informação';
    final percentual = quantidade / capacidade;
    if (percentual < 0.5) return 'Baixo movimento';
    if (percentual < 0.85) return 'Médio movimento';
    return 'Alta ocupação';
  }

  factory Lotacao.fromMap(Map<String, dynamic> map) {
    final permanencia = map['permanenciaMediaMin'];
    return Lotacao(
      quantidadeAtual: map['quantidadeAtual'] ?? 0,
      capacidadeMaxima: map['capacidadeMaxima'] ?? 0,
      atualizadoEm: map['atualizadoEm']?.toDate() ?? DateTime.now(),
      atualizadoPor: map['atualizadoPor'] ?? '',
      modo: map['modo'] == modoCatraca ? modoCatraca : modoManual,
      permanenciaMediaMin: permanencia is int && permanencia > 0
          ? permanencia
          : permanenciaPadraoMin,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quantidadeAtual': quantidadeAtual,
      'capacidadeMaxima': capacidadeMaxima,
      'atualizadoEm': atualizadoEm,
      'atualizadoPor': atualizadoPor,
      'modo': modo,
      'permanenciaMediaMin': permanenciaMediaMin,
    };
  }
}
