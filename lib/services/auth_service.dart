import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario.dart';

/// Responsável por cadastro/login/logout (Firebase Authentication)
/// e por criar/ler o documento correspondente em `usuarios` (Firestore).
///
/// Observação: login é feito por e-mail + senha. O CPF é guardado só
/// como dado cadastral, não é usado para autenticar.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get usuarioAtualAuth => _auth.currentUser;

  Future<Usuario> cadastrar({
    required String nome,
    required String cpf,
    required String email,
    required String senha,
  }) async {
    final credencial = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: senha,
    );

    final uid = credencial.user!.uid;
    final usuario = Usuario(
      id: uid,
      nome: nome,
      cpf: cpf,
      email: email,
      tipo: TipoUsuario.estudante,
      saldoAtual: 0,
      criadoEm: DateTime.now(),
    );

    await _db.collection('usuarios').doc(uid).set(usuario.toMap());
    return usuario;
  }

  Future<Usuario> login({
    required String email,
    required String senha,
  }) async {
    final credencial = await _auth.signInWithEmailAndPassword(
      email: email,
      password: senha,
    );
    return buscarUsuario(credencial.user!.uid);
  }

  Future<Usuario> buscarUsuario(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    if (!doc.exists) {
      throw Exception('Usuário não encontrado no banco de dados.');
    }
    return Usuario.fromMap(doc.id, doc.data()!);
  }

  Future<void> logout() => _auth.signOut();
}
