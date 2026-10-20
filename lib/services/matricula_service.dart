import 'package:cloud_firestore/cloud_firestore.dart';

class MatriculaInvalidaException implements Exception {
  final String message =
      'Matrícula não encontrada. Confira com a administração do RU.';
}

class MatriculaJaUsadaException implements Exception {
  final String message = 'Esta matrícula já está vinculada a uma conta.';
}

/// Coleção Firestore: matriculas_validas/{matricula}
/// Documento = { usada: bool, usadaEm: DateTime? }
///
/// Decisão de arquitetura (MVP): como não há integração com o sistema
/// acadêmico da UEMG, o administrador pré-carrega as matrículas
/// válidas nessa coleção. O cadastro do estudante só é concluído se a
/// matrícula existir aqui e ainda não tiver sido usada — isso é o que
/// "autentica" a matrícula no MVP.
class MatriculaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Cadastrada pelo admin: libera uma matrícula para ser usada em um
  /// cadastro futuro.
  Future<void> liberarMatricula(String matricula) {
    return _db.collection('matriculas_validas').doc(matricula).set({
      'usada': false,
    }, SetOptions(merge: true));
  }

  /// Chamado durante o cadastro do estudante. Roda em transação para
  /// que duas pessoas não consigam usar a mesma matrícula ao mesmo
  /// tempo.
  Future<void> validarEMarcarComoUsada(String matricula) async {
    final ref = _db.collection('matriculas_validas').doc(matricula);
    await _db.runTransaction((transacao) async {
      final snap = await transacao.get(ref);
      if (!snap.exists) {
        throw MatriculaInvalidaException();
      }
      final usada = snap.data()?['usada'] ?? false;
      if (usada == true) {
        throw MatriculaJaUsadaException();
      }
      transacao.update(ref, {
        'usada': true,
        'usadaEm': DateTime.now(),
      });
    });
  }

  /// Desfaz a marcação de "usada" — usado quando o cadastro falha
  /// depois de validar a matrícula (ex: CPF já existe) e é preciso
  /// devolver a matrícula para a lista de disponíveis.
  Future<void> liberarNovamente(String matricula) {
    return _db.collection('matriculas_validas').doc(matricula).set({
      'usada': false,
      'usadaEm': null,
    }, SetOptions(merge: true));
  }

  Stream<List<String>> matriculasLiberadasStream() {
    return _db
        .collection('matriculas_validas')
        .orderBy(FieldPath.documentId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }
}
