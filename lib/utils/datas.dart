/// Chave de um dia no formato AAAA-MM-DD (usada em documentos de
/// configuração, ex.: config/status.fechadoEm).
String chaveDia(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String doisDigitos(int n) => n.toString().padLeft(2, '0');

/// "11h05"
String horaMinuto(DateTime d) => '${doisDigitos(d.hour)}h${doisDigitos(d.minute)}';

/// "19/11"
String diaMes(DateTime d) => '${doisDigitos(d.day)}/${doisDigitos(d.month)}';

/// "19/11 às 11h05"
String diaMesHora(DateTime d) => '${diaMes(d)} às ${horaMinuto(d)}';

/// "02:59" a partir de segundos restantes.
String minutosSegundos(int segundos) {
  final s = segundos < 0 ? 0 : segundos;
  return '${doisDigitos(s ~/ 60)}:${doisDigitos(s % 60)}';
}

/// "11:05:42" (com segundos). Usado no relógio da tela de protocolo.
String horaCompleta(DateTime d) =>
    '${doisDigitos(d.hour)}:${doisDigitos(d.minute)}:${doisDigitos(d.second)}';
