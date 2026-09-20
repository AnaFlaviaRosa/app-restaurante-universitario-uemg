import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/movimentacao.dart';

/// Cuida do saldo do usuário e das movimentações financeiras.
///
/// MVP (decisão do grupo): não existe integração real de pagamento
/// (PIX/cartão). A recarga é SIMULADA: o usuário informa um valor,
/// clica em "confirmar pagamento" e o saldo é atualizado na hora.
/// A estrutura já guarda um `status`, então trocar para um gateway
/// real no futuro não exige redesenhar o banco — só trocar o método
/// `simularRecarga` por uma chamada a um provedor de pagamento.
class SaldoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<double> saldoStream(String usuarioId) {
    return _db
        .collection('usuarios')
        .doc(usuarioId)
        .snapshots()
        .map((doc) => (doc.data()?['saldoAtual'] ?? 0).toDouble());
  }

  Stream<List<Movimentacao>> historicoStream(String usuarioId) {
    return _db
        .collection('movimentacoes')
        .where('usuarioId', isEqualTo: usuarioId)
        .orderBy('data', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Movimentacao.fromMap(d.id, d.data()))
            .toList());
  }

  /// Simula uma recarga: cria a movimentação já como "aprovada" e
  /// incrementa o saldo do usuário, tudo em uma transação (para não
  /// haver saldo inconsistente se duas recargas acontecerem juntas).
  Future<void> simularRecarga({
    required String usuarioId,
    required double valor,
  }) async {
    if (valor <= 0) {
      throw Exception('O valor da recarga precisa ser maior que zero.');
    }

    final usuarioRef = _db.collection('usuarios').doc(usuarioId);
    final movimentacaoRef = _db.collection('movimentacoes').doc();

    await _db.runTransaction((transacao) async {
      final usuarioSnap = await transacao.get(usuarioRef);
      final saldoAtual = (usuarioSnap.data()?['saldoAtual'] ?? 0).toDouble();

      transacao.update(usuarioRef, {'saldoAtual': saldoAtual + valor});
      transacao.set(movimentacaoRef, {
        'usuarioId': usuarioId,
        'tipo': 'recarga',
        'valor': valor,
        'status': 'aprovada',
        'data': DateTime.now(),
        'reservaId': null,
      });
    });
  }
}
