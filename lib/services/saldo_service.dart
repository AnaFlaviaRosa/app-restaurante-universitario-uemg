import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/movimentacao.dart';

/// Cuida do saldo do usuário e das movimentações financeiras.
///
/// MVP (decisão do grupo): não existe integração real de pagamento
/// (PIX/cartão). A recarga é SIMULADA: as telas de Pix e cartão imitam
/// o caminho de um pagamento de verdade e, quando "aprovado", este
/// serviço atualiza o saldo. Trocar para um gateway real no futuro não
/// exige redesenhar o banco — só trocar o método `simularRecarga` por
/// uma chamada a um provedor de pagamento.
class SaldoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<double> saldoStream(String usuarioId) {
    return _db
        .collection('usuarios')
        .doc(usuarioId)
        .snapshots()
        .map((doc) => (doc.data()?['saldoAtual'] ?? 0).toDouble());
  }

  /// Histórico do usuário, do mais recente para o mais antigo.
  ///
  /// A ordenação é feita aqui no app (e não com `orderBy` no Firestore)
  /// porque `where('usuarioId') + orderBy('data')` exige um índice
  /// composto criado no console do Firebase. Sem ele, a consulta falha
  /// com `failed-precondition`. Para o volume de um MVP, ordenar no
  /// cliente é suficiente.
  Stream<List<Movimentacao>> historicoStream(String usuarioId) {
    return _db
        .collection('movimentacoes')
        .where('usuarioId', isEqualTo: usuarioId)
        .snapshots()
        .map((snap) {
      final lista = snap.docs
          .map((d) => Movimentacao.fromMap(d.id, d.data()))
          .toList();
      lista.sort((a, b) => b.data.compareTo(a.data));
      return lista;
    });
  }

  /// Registra uma recarga APROVADA: cria a movimentação e incrementa o
  /// saldo do usuário, tudo em uma transação (para não haver saldo
  /// inconsistente se duas recargas acontecerem juntas).
  ///
  /// As telas de Pix e cartão (lib/screens/estudante/recarga/) simulam
  /// todo o caminho do pagamento e só chamam isto quando o pagamento é
  /// "aprovado". Devolve o novo saldo, para o comprovante.
  Future<double> simularRecarga({
    required String usuarioId,
    required double valor,
    String? metodo, // 'pix' ou 'cartao'
    String? transacaoId, // ID Pix ou código de autorização do cartão
    String? detalhe, // ex.: "Crédito Visa •••• 4242"
  }) async {
    if (valor <= 0) {
      throw Exception('O valor da recarga precisa ser maior que zero.');
    }

    final usuarioRef = _db.collection('usuarios').doc(usuarioId);
    final movimentacaoRef = _db.collection('movimentacoes').doc();
    var novoSaldo = 0.0;

    await _db.runTransaction((transacao) async {
      final usuarioSnap = await transacao.get(usuarioRef);
      final saldoAtual = (usuarioSnap.data()?['saldoAtual'] ?? 0).toDouble();
      novoSaldo = saldoAtual + valor;

      transacao.update(usuarioRef, {'saldoAtual': novoSaldo});
      transacao.set(movimentacaoRef, {
        'usuarioId': usuarioId,
        'tipo': 'recarga',
        'valor': valor,
        'status': 'aprovada',
        'data': DateTime.now(),
        'reservaId': null,
        'metodo': metodo,
        'transacaoId': transacaoId,
        'detalhe': detalhe,
      });
    });
    return novoSaldo;
  }

  /// Registra uma tentativa de recarga RECUSADA (ex.: cartão recusado).
  /// Aparece no histórico como "(RECUSADA)" e NÃO altera o saldo.
  Future<void> registrarRecargaRecusada({
    required String usuarioId,
    required double valor,
    String? metodo,
    String? detalhe,
  }) async {
    await _db.collection('movimentacoes').add({
      'usuarioId': usuarioId,
      'tipo': 'recarga',
      'valor': valor,
      'status': 'recusada',
      'data': DateTime.now(),
      'reservaId': null,
      'metodo': metodo,
      'transacaoId': null,
      'detalhe': detalhe,
    });
  }
}
