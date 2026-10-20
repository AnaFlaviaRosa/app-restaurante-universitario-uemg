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
/// Coleção Firestore: usuarios/{uid}
///
/// MUDANÇA (decisão do grupo, revisão de segurança/LGPD): a chave
/// primária do documento voltou a ser o `uid` do Firebase Auth (não
/// mais o CPF). O CPF continua existindo, mas agora é só um CAMPO
/// dentro do documento — deixa de aparecer em toda referência,
/// regra de segurança e log do sistema (antes, com CPF como ID,
/// qualquer path tipo `usuarios/12345678900` já expunha o CPF real).
///
/// Unicidade de CPF (não pode haver 2 contas com o mesmo CPF) agora é
/// garantida por uma coleção auxiliar só de checagem:
/// `cpfs_em_uso/{cpf} = { uid }` — o inverso do antigo `uid_cpf`.
/// Ver AuthService para a implementação completa desse fluxo.
///
/// - `matricula`: preenchida SÓ quando tipo == estudante. Ela não é a
///   chave do documento — serve apenas para confirmar que a pessoa é
///   estudante (e portanto paga o valor de estudante na refeição).
class Usuario {
  final String id; // uid do Firebase Auth (chave primária do documento)
  final String cpf; // CPF, sem formatação (só números) — agora só um campo
  final String nome;
  final String email;
  final TipoUsuario tipo;
  final String? matricula; // preenchido só quando tipo == estudante
  final double saldoAtual;
  final DateTime criadoEm;

  Usuario({
    required this.id,
    required this.cpf,
    required this.nome,
    required this.email,
    required this.tipo,
    this.matricula,
    required this.saldoAtual,
    required this.criadoEm,
  });

  bool get isAdmin => tipo == TipoUsuario.admin;
  bool get isEstudante => tipo == TipoUsuario.estudante;

  factory Usuario.fromMap(String id, Map<String, dynamic> map) {
    return Usuario(
      id: id,
      cpf: map['cpf'] ?? '',
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
      'cpf': cpf,
      'nome': nome,
      'email': email,
      'tipo': tipoUsuarioToString(tipo),
      'matricula': matricula,
      'saldoAtual': saldoAtual,
      'criadoEm': criadoEm,
    };
  }
}