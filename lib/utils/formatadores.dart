/// Iniciais para o círculo do avatar do perfil.
///
/// - "Ana Clara Silva" -> "AS" (1ª letra do primeiro nome + 1ª
///   letra do último sobrenome)
/// - "Maria" -> "M"
/// - nome vazio -> "?"
String iniciaisDoNome(String nome) {
  final partes = nome
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (partes.isEmpty) return '?';
  if (partes.length == 1) return partes.first[0].toUpperCase();
  return (partes.first[0] + partes.last[0]).toUpperCase();
}