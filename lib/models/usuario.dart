/// Tipos de usuário do sistema.
/// O tipo define quais funcionalidades ficam disponíveis no app E
/// (nova regra) qual é o valor cobrado pela refeição — ver PrecoService.
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
/// Coleção Firestore: usuarios/{cpf}
///
/// MUDANÇA IMPORTANTE (decisão do grupo): a CHAVE PRIMÁRIA do usuário
/// no banco agora é o CPF, não mais o uid do Firebase Auth. Ou seja,
/// `Usuario.id` == CPF (sem pontos/traço) e é também o id do
/// documento em `usuarios`.
///
/// Isso cria um problema técnico: o login no Firebase Auth continua
/// sendo por e-mail/senha e o Auth só devolve um `uid`, não o CPF.
/// Para resolver isso sem duplicar a lógica de autenticação, existe
/// uma coleção auxiliar `uid_cpf/{uid} = { cpf }` que funciona como
/// um "índice": dado o uid que o Firebase Auth devolveu no login,
/// buscamos o cpf ali, e só então buscamos `usuarios/{cpf}`.
/// Ver AuthService para a implementação completa desse fluxo.
///
/// - `matricula`: preenchida SÓ quando tipo == estudante. Ela não é a
///   chave do documento — serve apenas para confirmar que a pessoa é
///   estudante (e portanto paga o valor de estudante na refeição).
/// - `uid`: guardado aqui também (além do índice uid_cpf) para
///   facilitar consultas futuras a partir do documento do usuário.
class Usuario {
  final String id; // CPF (chave primária, sem formatação: só números)
  final String uid; // uid do Firebase Auth (para referência)
  final String nome;
  final String email;
  final TipoUsuario tipo;
  final String? matricula; // preenchido só quando tipo == estudante
  final double saldoAtual;
  final DateTime criadoEm;

  Usuario({
    required this.id,
    required this.uid,
    required this.nome,
    required this.email,
    required this.tipo,
    this.matricula,
    required this.saldoAtual,
    required this.criadoEm,
  });

  bool get isAdmin => tipo == TipoUsuario.admin;
  bool get isEstudante => tipo == TipoUsuario.estudante;
  String get cpf => id;

  factory Usuario.fromMap(String id, Map<String, dynamic> map) {
    return Usuario(
      id: id,
      uid: map['uid'] ?? '',
      nome: map['nome'] ?? '',
      email: map['email'] ?? '',
      tipo: tipoUsuarioFromString(map['tipo'] ?? 'estudante'),
      matricula: map['matricula'],
      saldoAtual: (map['saldoAtual'] ?? 0).toDouble(),
      criadoEm: map['criadoEm']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nome': nome,
      'email': email,
      'tipo': tipoUsuarioToString(tipo),
      'matricula': matricula,
      'saldoAtual': saldoAtual,
      'criadoEm': criadoEm,
    };
  }
}
