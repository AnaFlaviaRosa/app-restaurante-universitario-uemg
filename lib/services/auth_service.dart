import 'package:flutter/foundation.dart';
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
/// MUDANÇA (revisão de segurança/LGPD): o documento em `usuarios`
/// volta a ser indexado pelo `uid` do Firebase Auth (chave primária),
/// e não mais pelo CPF. O CPF é guardado só como CAMPO dentro do
/// documento do próprio usuário — deixa de aparecer no ID do
/// documento, em regras de segurança e em qualquer log que imprima o
/// path do documento.
///
/// Unicidade de CPF (impedir duas contas com o mesmo CPF) é garantida
/// por uma coleção só de checagem, `cpfs_em_uso/{cpf} = { uid }`, que
/// NÃO guarda nenhum outro dado do usuário — serve só pra essa
/// verificação no cadastro.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MatriculaService _matriculaService = MatriculaService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get usuarioAtualAuth => _auth.currentUser;

  Future<bool> _cpfJaExiste(String cpf) async {
    final doc = await _db.collection('cpfs_em_uso').doc(cpf).get();
    return doc.exists;
  }

  Future<void> _reservarCpf(String cpf, String uid) {
    return _db.collection('cpfs_em_uso').doc(cpf).set({'uid': uid});
  }

  /// Cadastro de ESTUDANTE: exige CPF (só para checagem de unicidade
  /// e cadastro no documento) + matrícula válida (ver MatriculaService).
  ///
  /// Ordem das operações (importante para não deixar dado "pela
  /// metade" se algo falhar no meio do caminho):
  /// 1. Cria a conta no Firebase Auth (email/senha) -> gera o uid.
  /// 2. Confere se o CPF já está cadastrado -> se sim, desfaz a conta
  ///    criada no passo 1 e lança CpfJaCadastradoException.
  /// 3. Valida e marca a matrícula como usada -> se for inválida ou já
  ///    usada, desfaz a conta do passo 1 e relança o erro.
  /// 4. Cria o documento usuarios/{uid} e reserva o CPF em cpfs_em_uso.
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
      id: uid,
      cpf: cpf,
      nome: nome,
      email: email,
      tipo: TipoUsuario.estudante,
      matricula: matricula,
      saldoAtual: 0,
      criadoEm: DateTime.now(),
    );

    try {
      await _db.collection('usuarios').doc(uid).set(usuario.toMap());
      await _reservarCpf(cpf, uid);
    } catch (e) {
      // Se falhar ao salvar no Firestore, devolve a matrícula e a
      // conta de autenticação criada, para não deixar lixo no banco.
      await _matriculaService.liberarNovamente(matricula);
      await credencial.user!.delete();
      rethrow;
    }

    return usuario;
  }

  /// Cadastro de usuário COMUM: exige CPF (só para checagem de
  /// unicidade e cadastro no documento). Sem matrícula, sem validação
  /// externa no MVP.
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
      id: uid,
      cpf: cpf,
      nome: nome,
      email: email,
      tipo: TipoUsuario.comum,
      saldoAtual: 0,
      criadoEm: DateTime.now(),
    );

    try {
      await _db.collection('usuarios').doc(uid).set(usuario.toMap());
      await _reservarCpf(cpf, uid);
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

  /// Busca o documento usuarios/{uid} diretamente — não precisa mais
  /// de nenhuma "tradução" (o uid do Auth já É o id do documento).
  ///
  /// Também mantém o e-mail do documento igual ao e-mail do Firebase
  /// Auth: quando a pessoa troca o e-mail pelo Perfil, o Auth só muda
  /// depois que ela confirma o link enviado ao novo endereço; na
  /// próxima leitura (login / abrir o app / abrir a aba Perfil) o
  /// documento é atualizado aqui.
  Future<Usuario> buscarUsuarioPorUid(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    if (!doc.exists) {
      throw Exception('Usuário não encontrado no banco de dados.');
    }
    var usuario = Usuario.fromMap(doc.id, doc.data()!);

    final atual = _auth.currentUser;
    final emailAuth = atual?.email;
    if (atual != null &&
        atual.uid == uid &&
        emailAuth != null &&
        emailAuth.toLowerCase() != usuario.email.toLowerCase()) {
      try {
        await doc.reference.update({'email': emailAuth});
        usuario = usuario.copyWith(email: emailAuth);
      } catch (e) {
        // Não impede o login se essa sincronização falhar.
        debugPrint('ERRO AO SINCRONIZAR E-MAIL: $e');
      }
    }
    return usuario;
  }

  /// Relê o usuário logado no Auth (para pegar um e-mail recém
  /// confirmado) e devolve o documento atualizado.
  Future<Usuario> recarregarUsuario(String uid) async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      debugPrint('ERRO AO RECARREGAR USUÁRIO: $e');
    }
    return buscarUsuarioPorUid(uid);
  }

  // ---------- Perfil ----------

  /// Confirma a identidade com a senha atual. O Firebase exige um login
  /// recente para trocar e-mail ou senha.
  Future<void> _reautenticar(String senhaAtual) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    final credencial = EmailAuthProvider.credential(
      email: email,
      password: senhaAtual,
    );
    await user.reauthenticateWithCredential(credencial);
  }

  /// Atualiza o nome no documento do usuário.
  Future<Usuario> atualizarNome(Usuario usuario, String novoNome) async {
    await _db
        .collection('usuarios')
        .doc(usuario.id)
        .update({'nome': novoNome});
    return usuario.copyWith(nome: novoNome);
  }

  /// Pede a troca de e-mail. O Firebase envia um link de confirmação
  /// para o NOVO endereço e só troca o e-mail de login depois que a
  /// pessoa clica nele (por isso não alteramos `usuarios.email` aqui —
  /// ver buscarUsuarioPorUid).
  Future<void> solicitarAlteracaoEmail({
    required String senhaAtual,
    required String novoEmail,
  }) async {
    await _reautenticar(senhaAtual);
    await _auth.currentUser!.verifyBeforeUpdateEmail(novoEmail);
  }

  /// Troca a senha (exige a senha atual).
  Future<void> alterarSenha({
    required String senhaAtual,
    required String novaSenha,
  }) async {
    await _reautenticar(senhaAtual);
    await _auth.currentUser!.updatePassword(novaSenha);
  }

  Future<void> logout() => _auth.signOut();

  /// Envia e-mail de redefinição de senha.
  ///
  /// Propositalmente NÃO diferencia "e-mail existe" de "e-mail não
  /// existe" pra quem chama — sempre parece ter dado certo do ponto
  /// de vista de quem usa. Isso evita que a tela vire uma forma de
  /// descobrir quais e-mails estão cadastrados no sistema
  /// (enumeração de usuários).
  Future<void> enviarRedefinicaoSenha(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // 'user-not-found' e 'invalid-email' não devem vazar pra quem
      // usa o app; qualquer outro erro (ex: rede) relança normalmente.
      if (e.code != 'user-not-found' && e.code != 'invalid-email') {
        rethrow;
      }
    }
  }
}