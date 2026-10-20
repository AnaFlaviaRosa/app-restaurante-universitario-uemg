import 'dart:convert';
import 'dart:typed_data';

/// Cardápio do dia: UMA imagem, que vale para almoço e janta.
/// Documento Firestore único: cardapios/atual
///
/// Decisão do grupo: não guardamos cardápios anteriores. Existe sempre
/// um só documento (`atual`), e cada nova publicação o SOBRESCREVE por
/// inteiro (`set`) — a imagem do dia anterior deixa de existir no
/// momento em que a nova é enviada. É como uma memória RAM: só o que
/// está valendo agora fica guardado.
///
/// A imagem fica como texto Base64 dentro do próprio documento (campo
/// `imagemBase64`), sem Firebase Storage — o Storage exige o plano pago
/// Blaze. Como um documento do Firestore aceita ~1 MiB no total, a imagem
/// é reduzida e comprimida no app antes de salvar (ver
/// CardapioAdminCard e CardapioService).
class Cardapio {
  final String imagemBase64;

  /// Imagem já decodificada (feita UMA vez ao ler o documento, para não
  /// decodificar o Base64 a cada rebuild da tela).
  final Uint8List imagemBytes;

  final DateTime atualizadoEm;
  final String atualizadoPor; // uid do administrador

  Cardapio({
    required this.imagemBase64,
    required this.atualizadoEm,
    required this.atualizadoPor,
  }) : imagemBytes = _decodificar(imagemBase64);

  static Uint8List _decodificar(String base64) {
    if (base64.isEmpty) return Uint8List(0);
    try {
      return base64Decode(base64);
    } catch (_) {
      // Documento corrompido: trata como "sem imagem" em vez de quebrar
      // a tela.
      return Uint8List(0);
    }
  }

  bool get temImagem => imagemBytes.isNotEmpty;

  /// `true` se o cardápio foi publicado hoje. Se for `false`, o admin
  /// ainda não enviou o cardápio do dia (a tela avisa os usuários).
  bool get ehDeHoje {
    final agora = DateTime.now();
    return atualizadoEm.year == agora.year &&
        atualizadoEm.month == agora.month &&
        atualizadoEm.day == agora.day;
  }

  factory Cardapio.fromMap(Map<String, dynamic> map) {
    return Cardapio(
      imagemBase64: map['imagemBase64'] ?? '',
      atualizadoEm: map['atualizadoEm']?.toDate() ?? DateTime.now(),
      atualizadoPor: map['atualizadoPor'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imagemBase64': imagemBase64,
      'atualizadoEm': atualizadoEm,
      'atualizadoPor': atualizadoPor,
    };
  }
}
