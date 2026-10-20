import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cardapio.dart';

/// Limite de segurança para o campo imagemBase64.
///
/// O Firestore recusa documentos com mais de ~1 MiB (1.048.576 bytes) no
/// total. 700.000 caracteres Base64 equivalem a ~512 KB de imagem (o
/// Base64 deixa o arquivo ~33% maior), o que deixa folga para os demais
/// campos do documento e é mais que suficiente para a foto de um cardápio.
const int kTamanhoMaximoBase64 = 700000;

class ImagemMuitoGrandeException implements Exception {
  final String message =
      'A imagem ficou grande demais mesmo depois da compressão. Tente uma '
      'foto (JPG) ou um print com menos resolução.';
}

/// Cardápio do dia — um único documento: cardapios/atual.
///
/// Não existe histórico: publicar um novo cardápio SOBRESCREVE o
/// documento inteiro, então o do dia anterior é apagado automaticamente.
/// Quem pode escrever é só o administrador (ver firestore.rules); todo
/// usuário logado pode ler.
class CardapioService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _documento =>
      _db.collection('cardapios').doc('atual');

  Stream<Cardapio?> cardapioStream() {
    return _documento.snapshots().map(
        (doc) => doc.exists ? Cardapio.fromMap(doc.data()!) : null);
  }

  /// Publica o cardápio do dia (imagem já comprimida e em Base64).
  /// Lança [ImagemMuitoGrandeException] se a imagem passar do limite de
  /// um documento do Firestore.
  Future<void> publicarCardapio({
    required String imagemBase64,
    required String adminId,
  }) async {
    if (imagemBase64.length > kTamanhoMaximoBase64) {
      throw ImagemMuitoGrandeException();
    }
    // `set` SEM merge troca o documento inteiro — é isso que apaga o
    // cardápio anterior.
    await _documento.set(Cardapio(
      imagemBase64: imagemBase64,
      atualizadoEm: DateTime.now(),
      atualizadoPor: adminId,
    ).toMap());
  }
}
