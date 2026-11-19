/// Cálculos da lotação por catraca (funções puras, fáceis de testar).

/// Janelas de visualização oferecidas ao usuário, em minutos.
const List<int> janelasLotacaoMin = [5, 10, 30, 60];

/// Estimativa de pessoas dentro do RU agora.
///
/// Ideia: se cada pessoa fica, em média, [permanenciaMediaMin] minutos,
/// quem entrou nesse intervalo ainda está lá. Logo:
///
///   presentes ≈ entradas nos últimos [permanenciaMediaMin] minutos
///
/// É uma APROXIMAÇÃO: quem almoça rápido já saiu, quem demora ainda
/// está. Como a catraca só registra entradas, o erro depende de quanto
/// o tempo real varia em torno da média. O resultado nunca passa da
/// capacidade física do RU (se ela for informada).
int estimarPresentes({
  required int entradasNaPermanencia,
  int capacidadeMaxima = 0,
}) {
  final n = entradasNaPermanencia < 0 ? 0 : entradasNaPermanencia;
  if (capacidadeMaxima > 0 && n > capacidadeMaxima) return capacidadeMaxima;
  return n;
}

/// Rótulo curto para uma janela: 5 → "5 min", 60 → "1 h".
String rotuloJanela(int minutos) {
  if (minutos % 60 == 0) return '${minutos ~/ 60} h';
  return '$minutos min';
}
