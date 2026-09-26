/// Remove tudo que não for dígito (pontos, traço, espaços). Use isso
/// antes de SALVAR o CPF no banco — garante que fica sempre só com
/// números, independente de como a pessoa digitou.
String limparCpf(String cpf) => cpf.replaceAll(RegExp(r'[^0-9]'), '');

/// Validação de CPF (dígito verificador, algoritmo módulo 11).
///
/// Isso confirma que o número é MATEMATICAMENTE possível (mesmo
/// algoritmo que a Receita Federal usa para gerar os 2 últimos
/// dígitos). Não confirma que a pessoa é realmente dona daquele CPF
/// — isso exigiria integração com a Receita Federal, fora do escopo
/// do MVP.
bool validarCpf(String cpfComOuSemFormatacao) {
  final cpf = limparCpf(cpfComOuSemFormatacao);

  if (cpf.length != 11) return false;

  // Rejeita sequências óbvias (todos os dígitos iguais). Elas passariam
  // no cálculo abaixo matematicamente, mas nunca são CPFs reais
  // (ex: 111.111.111-11, 000.000.000-00).
  if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

  final digitos = cpf.split('').map(int.parse).toList();

  int calcularDigitoVerificador(List<int> base) {
    int soma = 0;
    int peso = base.length + 1;
    for (final d in base) {
      soma += d * peso;
      peso--;
    }
    final resto = soma % 11;
    return resto < 2 ? 0 : 11 - resto;
  }

  final digito1 = calcularDigitoVerificador(digitos.sublist(0, 9));
  if (digito1 != digitos[9]) return false;

  final digito2 = calcularDigitoVerificador(digitos.sublist(0, 10));
  if (digito2 != digitos[10]) return false;

  return true;
}

/// Formata CPF só para EXIBIÇÃO (000.000.000-00).
/// Não usar o resultado disso para salvar no banco — lá o CPF
/// continua só números, sem pontuação (é o `Usuario.cpf`).
String formatarCpf(String cpf) {
  final limpo = limparCpf(cpf);
  if (limpo.length != 11) return cpf;
  return '${limpo.substring(0, 3)}.${limpo.substring(3, 6)}.'
      '${limpo.substring(6, 9)}-${limpo.substring(9, 11)}';
}