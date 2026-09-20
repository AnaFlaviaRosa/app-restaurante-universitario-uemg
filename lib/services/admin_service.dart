import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/disponibilidade.dart';
import '../models/reserva.dart';

/// Ações exclusivas do administrador: definir quantidade de marmitas
/// disponíveis por dia/refeição e visualizar as reservas.
///
/// Observação de arquitetura (decisão do grupo): não existe uma
/// entidade "Administrador" separada — é um `Usuario` com
/// `tipo == TipoUsuario.admin`. A proteção de quem pode chamar estes
/// métodos é feita nas regras de segurança do Firestore
/// (ver firestore.rules), não apenas no app.
class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _chave(DateTime data, TipoRefeicao tipo) {
    return '${data.year.toString().padLeft(4, '0')}-'
        '${data.month.toString().padLeft(2, '0')}-'
        '${data.day.toString().padLeft(2, '0')}_'
        '${tipoRefeicaoToString(tipo)}';
  }

  /// Define quantas marmitas existem para uma data/refeição.
  /// Se já existirem reservas feitas, `quantidadeDisponivel` é ajustada
  /// mantendo a proporção já consumida.
  Future<void> definirDisponibilidade({
    required DateTime data,
    required TipoRefeicao tipo,
    required int quantidadeTotal,
  }) async {
    final id = _chave(data, tipo);
    final ref = _db.collection('disponibilidades').doc(id);

    await _db.runTransaction((transacao) async {
      final snap = await transacao.get(ref);
      int jaReservadas = 0;
      if (snap.exists) {
        final total = snap.data()!['quantidadeTotal'] ?? 0;
        final disponivel = snap.data()!['quantidadeDisponivel'] ?? 0;
        jaReservadas = total - disponivel;
      }
      final novaDisponivel = (quantidadeTotal - jaReservadas)
          .clamp(0, quantidadeTotal);

      transacao.set(ref, Disponibilidade(
        id: id,
        data: DateTime(data.year, data.month, data.day),
        tipoRefeicao: tipo,
        quantidadeTotal: quantidadeTotal,
        quantidadeDisponivel: novaDisponivel,
      ).toMap());
    });
  }

  Stream<List<Reserva>> reservasPorDia(DateTime data) {
    final inicioDia = DateTime(data.year, data.month, data.day);
    final fimDia = inicioDia.add(const Duration(days: 1));
    return _db
        .collection('reservas')
        .where('data', isGreaterThanOrEqualTo: inicioDia)
        .where('data', isLessThan: fimDia)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Reserva.fromMap(d.id, d.data())).toList());
  }

  /// Marca uma reserva confirmada como "não retirada" (a pessoa não
  /// buscou a marmita). Não há estorno — a regra do grupo é que a
  /// marmita já foi paga na reserva.
  Future<void> marcarNaoRetirada(String reservaId) {
    return _db
        .collection('reservas')
        .doc(reservaId)
        .update({'status': 'naoRetirada'});
  }

  /// Marca a reserva como utilizada (a pessoa retirou a marmita).
  Future<void> marcarUtilizada(String reservaId) {
    return _db
        .collection('reservas')
        .doc(reservaId)
        .update({'status': 'utilizada'});
  }
}
