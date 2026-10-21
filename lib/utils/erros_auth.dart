import 'package:firebase_auth/firebase_auth.dart';

/// Traduz erros do Firebase Auth para mensagens simples em português,
/// usadas nas telas de perfil (editar e-mail / alterar senha).
String mensagemErroAuth(Object erro) {
  if (erro is FirebaseAuthException) {
    switch (erro.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Senha atual incorreta.';
      case 'weak-password':
        return 'A nova senha é muito fraca. Use pelo menos 6 caracteres.';
      case 'email-already-in-use':
        return 'Este e-mail já está em uso por outra conta.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos e tente de novo.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet e tente de novo.';
      case 'requires-recent-login':
        return 'Por segurança, saia da conta, entre novamente e repita '
            'a alteração.';
    }
  }
  return 'Não foi possível concluir. Tente novamente.';
}