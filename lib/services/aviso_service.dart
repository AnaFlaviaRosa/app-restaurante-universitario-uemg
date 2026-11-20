import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/aviso.dart';

/// Quadro de avisos. Coleção Firestore: avisos/{id}
///
/// Custo de leituras (plano gratuito): o estudante lê os avisos UMA vez
/// ao abrir a tela inicial (e quando puxa para atualizar), com limite
/// de poucos avisos — sem atualização automática por tempo.
class AvisoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const limiteExibicao = 8;

  /// Avisos ainda válidos (não expirados), importantes primeiro.
  Future<List<Aviso>> avisosAtivos() async {
    final agora = DateTime.now();
    final snap = await _db
        .collection('avisos')
        .where('expiraEm', isGreaterThan: Timestamp.fromDate(agora))
        .orderBy('expiraEm')
        .limit(30)
        .get();
    final avisos = snap.docs
        .map((d) => Aviso.fromMap(d.id, d.data()))
        .where((a) => a.ativoEm(agora));
    return ordenarAvisos(avisos).take(limiteExibicao).toList();
  }

  /// Versão em tempo real, usada só na tela do admin (poucos usuários).
  Stream<List<Aviso>> avisosAtivosStream() {
    return _db
        .collection('avisos')
        .where('expiraEm', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('expiraEm')
        .snapshots()
        .map((snap) => ordenarAvisos(
            snap.docs.map((d) => Aviso.fromMap(d.id, d.data()))));
  }

  Future<void> publicar({
    required String titulo,
    required String mensagem,
    required bool importante,
    required Duration validade,
    required String adminId,
  }) {
    final agora = DateTime.now();
    return _db.collection('avisos').add(Aviso(
          id: '',
          titulo: titulo.trim(),
          mensagem: mensagem.trim(),
          importante: importante,
          criadoEm: agora,
          expiraEm: agora.add(validade),
          criadoPor: adminId,
        ).toMap());
  }

  Future<void> remover(String id) {
    return _db.collection('avisos').doc(id).delete();
  }
}
