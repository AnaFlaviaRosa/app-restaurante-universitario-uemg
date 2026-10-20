import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lotacao.dart';

/// Lotação atual do RU.
///
/// MVP: sem câmera/catraca. Um administrador atualiza manualmente
/// (ver decisão do grupo em Sprint 0.3). O documento é único:
/// lotacao/atual — sempre sobrescrito, não cria histórico.
class LotacaoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<Lotacao?> lotacaoStream() {
    return _db.collection('lotacao').doc('atual').snapshots().map(
        (doc) => doc.exists ? Lotacao.fromMap(doc.data()!) : null);
  }

  Future<void> atualizarLotacao({
    required int quantidadeAtual,
    required int capacidadeMaxima,
    required String adminId,
  }) {
    return _db.collection('lotacao').doc('atual').set(Lotacao(
      quantidadeAtual: quantidadeAtual,
      capacidadeMaxima: capacidadeMaxima,
      atualizadoEm: DateTime.now(),
      atualizadoPor: adminId,
    ).toMap());
  }
}
