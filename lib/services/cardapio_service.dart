import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cardapio.dart';
import '../models/reserva.dart';

class CardapioService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _chave(DateTime data, TipoRefeicao tipo) {
    return '${data.year.toString().padLeft(4, '0')}-'
        '${data.month.toString().padLeft(2, '0')}-'
        '${data.day.toString().padLeft(2, '0')}_'
        '${tipoRefeicaoToString(tipo)}';
  }

  Stream<Cardapio?> cardapioStream(DateTime data, TipoRefeicao tipo) {
    final id = _chave(data, tipo);
    return _db.collection('cardapios').doc(id).snapshots().map(
        (doc) => doc.exists ? Cardapio.fromMap(doc.id, doc.data()!) : null);
  }

  /// Admin cadastra/atualiza o cardápio do dia.
  /// No MVP, `imagemUrl` é só um link (ex: já hospedado em algum lugar).
  /// Upload direto de imagem pelo app fica como evolução futura
  /// (usando Firebase Storage).
  Future<void> salvarCardapio({
    required DateTime data,
    required TipoRefeicao tipo,
    required String imagemUrl,
  }) {
    final id = _chave(data, tipo);
    return _db.collection('cardapios').doc(id).set(Cardapio(
      id: id,
      data: DateTime(data.year, data.month, data.day),
      tipoRefeicao: tipo,
      imagemUrl: imagemUrl,
    ).toMap());
  }
}
