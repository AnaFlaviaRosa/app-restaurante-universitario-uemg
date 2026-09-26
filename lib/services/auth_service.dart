import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario.dart';
import 'matricula_service.dart';

class CpfJaCadastradoException implements Exception {
  final String message = 'Já existe uma conta cadastrada com este CPF.';
}

/// Responsável por cadastro/login/logout (Firebase Authentication) e
/// por criar/ler o documento correspondente em `usuarios` (Firestore).
///
/// MUDANÇA IMPORTANTE: o documento em `usuarios` agora é indexado pelo
/// CPF (chave primária), não pelo uid do Firebase Auth. Como o Auth só
/// devolve o uid no login, mantemos uma coleção auxiliar
/// `uid_cpf/{uid} = { cpf }` para conseguir achar o usuário certo
/// depois do login. Essa "tradução" uid -> cpf acontece dentro de
/// `buscarUsuarioPorUid`.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MatriculaService _matriculaService = MatriculaService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get usuarioAtualAuth => _auth.currentUser;

  Future<bool> _cpfJaExiste(String cpf) async {
    final doc = await _db.collection('usuarios').doc(cpf).get();
    return doc.exists;
  }

  Future<void> _salvarIndiceUidCpf(String uid, String cpf) {
    return _db.collection('uid_cpf').doc(uid).set({'cpf': cpf});
  }

  /// Cadastro de ESTUDANTE: exige CPF (chave primária) + matrícula
  /// válida (ver MatriculaService). A matrícula só CONFIRMA que a
  /// pessoa é estudante — quem identifica o usuário no banco é o CPF.
  ///
  /// Ordem das operações (importante para não deixar dado "pela
  /// metade" se algo falhar no meio do caminho):
  /// 1. Cria a conta no Firebase Auth (email/senha).
  /// 2. Confere se o CPF já está cadastrado -> se sim, desfaz a conta
  ///    criada no passo 1 e lança CpfJaCadastradoException.
  /// 3. Valida e marca a matrícula como usada -> se for inválida ou já
  ///    usada, desfaz a conta do passo 1 e relança o erro.
  /// 4. Cria o documento usuarios/{cpf} e o índice uid_cpf/{uid}.
  Future<Usuario> cadastrarEstudante({
    required String nome,
    required String cpf,
    required String matricula,
    required String email,
    required String senha,
  }) async {
    final credencial = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: senha,
    );
    final uid = credencial.user!.uid;

    if (await _cpfJaExiste(cpf)) {
      await credencial.user!.delete();
      throw CpfJaCadastradoException();
    }

    try {
      await _matriculaService.validarEMarcarComoUsada(matricula);
    } catch (e) {
      await credencial.user!.delete();
      rethrow;
    }

    final usuario = Usuario(
      id: cpf,
      uid: uid,
      nome: nome,
      email: email,
      tipo: TipoUsuario.estudante,
      matricula: matricula,
      saldoAtual: 0,
      criadoEm: DateTime.now(),
    );

    try {
      await _db.collection('usuarios').doc(cpf).set(usuario.toMap());
      await _salvarIndiceUidCpf(uid, cpf);
    } catch (e) {
      // Se falhar ao salvar no Firestore, devolve a matrícula e a
      // conta de autenticação criada, para não deixar lixo no banco.
      await _matriculaService.liberarNovamente(matricula);
      await credencial.user!.delete();
      rethrow;
    }

    return usuario;
  }

  /// Cadastro de usuário COMUM: exige CPF (chave primária). Sem
  /// matrícula, sem validação externa no MVP.
  Future<Usuario> cadastrarComum({
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

    if (await _cpfJaExiste(cpf)) {
      await credencial.user!.delete();
      throw CpfJaCadastradoException();
    }

    final usuario = Usuario(
      id: cpf,
      uid: uid,
      nome: nome,
      email: email,
      tipo: TipoUsuario.comum,
      saldoAtual: 0,
      criadoEm: DateTime.now(),
    );

    try {
      await _db.collection('usuarios').doc(cpf).set(usuario.toMap());
      await _salvarIndiceUidCpf(uid, cpf);
    } catch (e) {
      await credencial.user!.delete();
      rethrow;
    }

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
    return buscarUsuarioPorUid(credencial.user!.uid);
  }

  /// Traduz uid (Firebase Auth) -> cpf (chave primária) -> Usuario.
  /// Use este método (e não mais `buscarUsuario`) sempre que só se
  /// tiver o uid em mãos, como no PortaoDeEntrada em main.dart.
  Future<Usuario> buscarUsuarioPorUid(String uid) async {
    final indice = await _db.collection('uid_cpf').doc(uid).get();
    if (!indice.exists) {
      throw Exception('Usuário não encontrado (índice uid->cpf ausente).');
    }
    final cpf = indice.data()!['cpf'] as String;
    return buscarUsuarioPorCpf(cpf);
  }

  Future<Usuario> buscarUsuarioPorCpf(String cpf) async {
    final doc = await _db.collection('usuarios').doc(cpf).get();
    if (!doc.exists) {
      throw Exception('Usuário não encontrado no banco de dados.');
    }
    return Usuario.fromMap(doc.id, doc.data()!);
  }

  Future<void> logout() => _auth.signOut();
}
