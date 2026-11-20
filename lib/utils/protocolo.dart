import '../models/reserva.dart';
import '../services/config_service.dart';

/// Regra de quando o botão "Retirar marmita" (abrir o protocolo) pode
/// aparecer para o usuário. Função pura, testável.
///
/// - Reserva `liberada` (a catraca reconheceu a pessoa): pode abrir.
/// - Reserva `confirmada`:
///     * com a integração da catraca ATIVA: não pode (a pessoa precisa
///       passar na catraca antes);
///     * com a integração INATIVA (ponte ainda não existe ou caiu):
///       pode, mas só dentro do horário de funcionamento da refeição.
/// - Qualquer outro status: não pode. (Se já foi aberta, a tela de
///   protocolo é tratada à parte: ver [Reserva.protocoloValido].)
/// - Só vale para a reserva do próprio dia.
bool podeAbrirProtocolo({
  required Reserva reserva,
  required bool integracaoCatracaAtiva,
  required HorarioRefeicao horario,
  required DateTime agora,
}) {
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final diaReserva =
      DateTime(reserva.data.year, reserva.data.month, reserva.data.day);
  if (diaReserva != hoje) return false;

  switch (reserva.status) {
    case StatusReserva.liberada:
      return true;
    case StatusReserva.confirmada:
      return !integracaoCatracaAtiva && horario.estaAbertoEm(agora);
    case StatusReserva.utilizada:
    case StatusReserva.naoRetirada:
    case StatusReserva.cancelada:
      return false;
  }
}
