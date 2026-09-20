/// Tipos de usuário do sistema.
/// O tipo define quais funcionalidades ficam disponíveis no app.
enum TipoUsuario { estudante, comum, admin }

TipoUsuario tipoUsuarioFromString(String valor) {
  switch (valor) {
    case 'admin':
      return TipoUsuario.admin;
    case 'comum':
      return TipoUsuario.comum;
    case 'estudante':
    default:
      return TipoUsuario.estudante;
  }
}

String tipoUsuarioToString(TipoUsuario tipo) {
  switch (tipo) {
    case TipoUsuario.admin:
      return 'admin';
    case TipoUsuario.comum:
      return 'comum';
    case TipoUsuario.estudante:
      return 'estudante';
  }
}

/// Representa um usuário do sistema.
/// Coleção Firestore: usuarios/{uid}
/// O documento usa o mesmo uid do Firebase Authentication.
///
/// Observação de modelagem (decisão do grupo):
/// - CPF é único e usado só como dado cadastral (login é feito por e-mail/senha
///   no Firebase Auth, não por CPF).
/// - O saldo NÃO guarda histórico. As movimentações (recargas/consumos)
///   ficam na coleção separada `movimentacoes`.
/// - Não existe campo de biometria facial no MVP.
class Usuario {
  final String id; // uid do Firebase Auth
  final String nome;
  final String cpf;
  final String email;
  final TipoUsuario tipo;
  final double saldoAtual;
  final DateTime criadoEm;

  Usuario({
    required this.id,
    required this.nome,
    required this.cpf,
    required this.email,
    required this.tipo,
    required this.saldoAtual,
    required this.criadoEm,
  });

  bool get isAdmin => tipo == TipoUsuario.admin;

  factory Usuario.fromMap(String id, Map<String, dynamic> map) {
    return Usuario(
      id: id,
      nome: map['nome'] ?? '',
      cpf: map['cpf'] ?? '',
      email: map['email'] ?? '',
      tipo: tipoUsuarioFromString(map['tipo'] ?? 'estudante'),
      saldoAtual: (map['saldoAtual'] ?? 0).toDouble(),
      criadoEm: map['criadoEm']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'cpf': cpf,
      'email': email,
      'tipo': tipoUsuarioToString(tipo),
      'saldoAtual': saldoAtual,
      'criadoEm': criadoEm,
    };
  }
}
