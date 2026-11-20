import 'dart:math';
import '../models/reserva.dart';

/// Gera o código curto do protocolo da reserva (6 caracteres, sem
/// caracteres confusos — ver [alfabetoCodigoReserva]).
///
/// Não é um segredo: quem garante o uso único é o STATUS da reserva no
/// servidor (depois de "utilizada" o protocolo não vale mais). O código
/// serve para o funcionário conferir a tela do aluno com a lista
/// impressa do dia.
String gerarCodigoReserva([Random? aleatorio]) {
  final r = aleatorio ?? Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < tamanhoCodigoReserva; i++) {
    buffer.write(alfabetoCodigoReserva[r.nextInt(alfabetoCodigoReserva.length)]);
  }
  return buffer.toString();
}

/// "ABC234" -> "ABC 234" (mais fácil de ler em voz alta e na tela).
String codigoComEspaco(String codigo) {
  if (codigo.length != tamanhoCodigoReserva) return codigo;
  return '${codigo.substring(0, 3)} ${codigo.substring(3)}';
}
