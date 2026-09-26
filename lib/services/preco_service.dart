import 'package:cloud_firestore/cloud_firestore.dart';

/// Documento único: config/precos = { precoEstudante, precoComum }
///
/// Valores definidos pelo grupo: estudante paga R$ 4,00, usuário comum
/// paga R$ 17,00. Ficam configuráveis pelo admin (mesmo padrão do
/// ConfigService/horarios) em vez de fixos no código — mas o valor
/// inicial (default, caso o documento ainda não exista no Firestore)
/// já é exatamente o combinado pelo grupo.
class PrecoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const double precoEstudantePadrao = 4.0;
  static const double precoComumPadrao = 17.0;

  Future<Map<TipoUsuarioPreco, double>> buscarPrecos() async {
    final doc = await _db.collection('config').doc('precos').get();
    final data = doc.data() ?? {};
    return {
      TipoUsuarioPreco.estudante:
          (data['precoEstudante'] ?? precoEstudantePadrao).toDouble(),
      TipoUsuarioPreco.comum:
          (data['precoComum'] ?? precoComumPadrao).toDouble(),
    };
  }

  Stream<Map<TipoUsuarioPreco, double>> precosStream() {
    return _db.collection('config').doc('precos').snapshots().map((doc) {
      final data = doc.data() ?? {};
      return {
        TipoUsuarioPreco.estudante:
            (data['precoEstudante'] ?? precoEstudantePadrao).toDouble(),
        TipoUsuarioPreco.comum:
            (data['precoComum'] ?? precoComumPadrao).toDouble(),
      };
    });
  }

  Future<void> salvarPrecos({
    required double precoEstudante,
    required double precoComum,
  }) {
    return _db.collection('config').doc('precos').set({
      'precoEstudante': precoEstudante,
      'precoComum': precoComum,
    });
  }

  /// Garante que o documento config/precos exista com os valores
  /// combinados pelo grupo. Chamar uma vez (ex: na tela de
  /// configurações do admin, ou manualmente no Firestore Console).
  Future<void> inicializarComPadrao() async {
    final doc = await _db.collection('config').doc('precos').get();
    if (!doc.exists) {
      await salvarPrecos(
        precoEstudante: precoEstudantePadrao,
        precoComum: precoComumPadrao,
      );
    }
  }
}

enum TipoUsuarioPreco { estudante, comum }
