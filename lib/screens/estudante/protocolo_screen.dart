import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/reserva.dart';
import '../../services/reserva_service.dart';
import '../../theme/cores.dart';
import '../../utils/codigo_reserva.dart';
import '../../utils/datas.dart';

/// Protocolo de retirada da marmita, mostrado ao funcionário do RU.
///
/// O funcionário confere na tela do aluno:
///  - nome, refeição, data e se é vegetariana;
///  - o código de 6 caracteres (que também está na lista impressa do dia);
///  - o RELÓGIO rodando com segundos e a HORA EM QUE O PROTOCOLO FOI
///    ABERTO (hora do servidor): um print parado se denuncia ao comparar
///    com o relógio da parede;
///  - a contagem regressiva ([duracaoProtocoloSegundos]).
///
/// Uso único: a abertura já mudou o status da reserva para `utilizada`
/// no servidor. Depois da contagem, a tela mostra "expirado".
class ProtocoloScreen extends StatefulWidget {
  final String reservaId;
  const ProtocoloScreen({super.key, required this.reservaId});

  @override
  State<ProtocoloScreen> createState() => _ProtocoloScreenState();
}

class _ProtocoloScreenState extends State<ProtocoloScreen> {
  final _reservaService = ReservaService();
  late final Stream<Reserva?> _stream;
  Timer? _timer;
  DateTime _agora = DateTime.now();

  @override
  void initState() {
    super.initState();
    _stream = _reservaService.reservaStream(widget.reservaId);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _agora = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _nomeRefeicao(TipoRefeicao t) =>
      t == TipoRefeicao.janta ? 'Janta' : 'Almoço';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.azulEscuro,
      appBar: AppBar(
        backgroundColor: Cores.azulEscuro,
        foregroundColor: Colors.white,
        title: const Text('Protocolo de retirada'),
      ),
      body: SafeArea(
        child: StreamBuilder<Reserva?>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _mensagem('Não foi possível carregar o protocolo.');
            }
            final reserva = snapshot.data;
            if (reserva == null) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }
            // O horário do servidor ainda não voltou (escrita pendente).
            if (reserva.protocoloAbertoEm == null) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 14),
                    Text('Abrindo protocolo...',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              );
            }
            final restante = reserva.protocoloSegundosRestantes(_agora) ?? 0;
            return restante > 0
                ? _protocoloValido(reserva, restante)
                : _protocoloExpirado(reserva);
          },
        ),
      ),
    );
  }

  Widget _mensagem(String texto) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15)),
        ),
      );

  Widget _protocoloValido(Reserva r, int restante) {
    final aberto = r.protocoloAbertoEm!;
    final nome = r.nome.isEmpty ? 'Nome não registrado' : r.nome;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Text(
                nome.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87),
              ),
              const SizedBox(height: 6),
              Text(
                '${_nomeRefeicao(r.tipoRefeicao)} • ${diaMes(r.data)}',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              if (r.vegetariana) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Cores.verdeVivo,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('VEGETARIANA',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
              ],
              const SizedBox(height: 18),
              const Text('CÓDIGO',
                  style: TextStyle(
                      fontSize: 12, color: Colors.black54, letterSpacing: 2)),
              Text(
                r.codigo.isEmpty ? '—' : codigoComEspaco(r.codigo),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: Cores.azulEscuro,
                ),
              ),
              const Divider(height: 28),
              _linha('Hora agora', horaCompleta(_agora)),
              const SizedBox(height: 6),
              _linha('Protocolo aberto às', horaCompleta(aberto)),
              const SizedBox(height: 14),
              Text(
                minutosSegundos(restante),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: restante <= 30 ? Cores.vermelho : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: restante / duracaoProtocoloSegundos,
                  minHeight: 10,
                  color: restante <= 30 ? Cores.vermelho : Cores.verde,
                  backgroundColor: const Color(0xFFE5E5E5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Funcionário: confira se a hora de abertura combina com o relógio '
          'da parede e se o código está na lista do dia. Print ou foto de '
          'protocolo antigo não vale.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _linha(String rotulo, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(rotulo,
            style: const TextStyle(fontSize: 14, color: Colors.black54)),
        Text(valor,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
      ],
    );
  }

  Widget _protocoloExpirado(Reserva r) {
    final aberto = r.protocoloAbertoEm!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_off_outlined,
                  size: 48, color: Cores.vermelho),
              const SizedBox(height: 12),
              const Text('PROTOCOLO EXPIRADO',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87)),
              const SizedBox(height: 10),
              Text(
                'Retirada registrada em ${diaMesHora(aberto)}.\n'
                'Esta tela não vale mais como comprovante.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
