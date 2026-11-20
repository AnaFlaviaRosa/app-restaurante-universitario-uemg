import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../models/reserva.dart';
import '../../models/disponibilidade.dart';
import '../../services/config_service.dart';
import '../../services/reserva_service.dart';
import '../../services/saldo_service.dart';
import '../../theme/cores.dart';
import 'protocolo_screen.dart';

/// Texto "3 minutos" a partir da duração do protocolo (usado no aviso).
const String duracaoProtocoloSegundosMinutos =
    '${duracaoProtocoloSegundos ~/ 60} minutos';

/// Fluxo B definido pelo grupo: reservar marmita.
///
/// Visual: cabeçalho verde + painel branco arredondado com a quantidade
/// disponível e um cartão azul que mostra os dados do usuário (nome,
/// RA/CPF e valor a ser descontado) para ele conferir antes de reservar.
///
/// Regras (ver ReservaService): 1 marmita por pessoa por refeição, saldo
/// suficiente, marmita disponível e dentro do horário de reserva.
class ReservaTab extends StatefulWidget {
  final Usuario usuario;

  /// Chamado ao tocar na seta do cabeçalho (ex.: voltar para a aba Início).
  final VoidCallback? onVoltar;

  /// Chamado ao tocar no ícone de sair do cabeçalho.
  final VoidCallback? onSair;

  const ReservaTab({
    super.key,
    required this.usuario,
    this.onVoltar,
    this.onSair,
  });

  @override
  State<ReservaTab> createState() => _ReservaTabState();
}

class _ReservaTabState extends State<ReservaTab> {
  final _reservaService = ReservaService();
  final _saldoService = SaldoService();
  final _configService = ConfigService();

  // Situação do RU hoje (aberto/fechado) e se a catraca está integrada.
  // Ficam em escuta para a tela reagir na hora quando o admin muda.
  StatusRu _statusRu = StatusRu();
  bool _integracaoCatraca = false;
  StreamSubscription<StatusRu>? _statusRuSub;
  StreamSubscription<bool>? _integracaoSub;

  TipoRefeicao _refeicaoSelecionada = TipoRefeicao.almoco;
  bool _vegetariana = false;
  bool _reservando = false;

  // Streams/futures criados uma vez (evita reassinar a cada setState).
  late Stream<Disponibilidade?> _dispStream;
  late Stream<List<Reserva>> _reservasStream;
  late Stream<double> _saldoStream;
  late Future<double> _valorFuture;

  DateTime get _hoje {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  @override
  void initState() {
    super.initState();
    _dispStream = _criarDispStream();
    _reservasStream = _reservaService.reservasDoUsuario(widget.usuario.id);
    _saldoStream = _saldoService.saldoStream(widget.usuario.id);
    _valorFuture = _reservaService
        .valorParaTipo(tipoUsuarioToString(widget.usuario.tipo));
    _statusRuSub = _configService.statusRuStream().listen((s) {
      if (mounted) setState(() => _statusRu = s);
    }, onError: (Object e) => debugPrint('ERRO STATUS RU: $e'));
    _integracaoSub = _configService.integracaoCatracaStream().listen((v) {
      if (mounted) setState(() => _integracaoCatraca = v);
    }, onError: (Object e) => debugPrint('ERRO INTEGRAÇÃO: $e'));
  }

  @override
  void dispose() {
    _statusRuSub?.cancel();
    _integracaoSub?.cancel();
    super.dispose();
  }

  bool get _ruFechadoHoje => _statusRu.fechadoEmDia(_hoje);

  Stream<Disponibilidade?> _criarDispStream() =>
      _reservaService.disponibilidadeStream(_hoje, _refeicaoSelecionada);

  // ---------- formatação ----------

  String _dinheiro(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  String _formatarCpf(String cpf) {
    final n = cpf.replaceAll(RegExp(r'\D'), '');
    if (n.length != 11) return cpf;
    return '${n.substring(0, 3)}.${n.substring(3, 6)}.'
        '${n.substring(6, 9)}-${n.substring(9)}';
  }

  /// Estudante com matrícula mostra o RA; os demais mostram o CPF.
  ({String rotulo, String valor}) get _identificacao {
    final mat = widget.usuario.matricula;
    if (widget.usuario.isEstudante && mat != null && mat.isNotEmpty) {
      return (rotulo: 'RA:', valor: mat);
    }
    return (rotulo: 'CPF:', valor: _formatarCpf(widget.usuario.cpf));
  }

  String _nomeRefeicao(TipoRefeicao t) =>
      t == TipoRefeicao.janta ? 'Janta' : 'Almoço';

  String _dataCurta(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _rotuloStatus(StatusReserva s) => statusReservaRotulo(s);

  // ---------- ações ----------

  Future<void> _reservar() async {
    setState(() => _reservando = true);
    try {
      await _reservaService.criarReserva(
        usuarioId: widget.usuario.id,
        data: _hoje,
        tipoRefeicao: _refeicaoSelecionada,
        vegetariana: _vegetariana,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marmita reservada com sucesso!')),
        );
      }
    } catch (e) {
      debugPrint('ERRO RESERVA: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_mensagemDeErro(e))));
      }
    } finally {
      if (mounted) setState(() => _reservando = false);
    }
  }

  Future<void> _cancelar(Reserva reserva) async {
    try {
      await _reservaService.cancelarReserva(reserva);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reserva cancelada.')),
        );
      }
    } catch (e) {
      debugPrint('ERRO CANCELAR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_mensagemDeErro(e))));
      }
    }
  }

  /// Abre o protocolo de retirada (uso único). Antes, avisa que ele é
  /// consumido e expira: o usuário só deve abrir diante do funcionário.
  Future<void> _retirar(Reserva reserva) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Abrir o protocolo agora?'),
        content: const Text(
          'Ao abrir, o protocolo é consumido: ele fica visível por '
          '$duracaoProtocoloSegundosMinutos e depois expira, sem poder ser '
          'usado de novo.\n\n'
          'Só abra quando estiver diante do funcionário, pronto para '
          'retirar a marmita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Abrir protocolo'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    try {
      await _reservaService.abrirProtocolo(reserva);
      if (!mounted) return;
      _verProtocolo(reserva);
    } catch (e) {
      debugPrint('ERRO PROTOCOLO: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_mensagemDeErro(e))));
      }
    }
  }

  void _verProtocolo(Reserva reserva) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ProtocoloScreen(reservaId: reserva.id),
    ));
  }

  String _mensagemDeErro(Object e) {
    if (e is SaldoInsuficienteException) return e.message;
    if (e is MarmitaEsgotadaException) return e.message;
    if (e is ReservaJaExisteException) return e.message;
    if (e is ForaDoPrazoException) return e.message;
    if (e is RuFechadoException) return e.message;
    if (e is ProtocoloIndisponivelException) return e.message;
    return 'Não foi possível concluir a operação.';
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return Container(
      // Verde atrás dos cantos arredondados do painel branco.
      color: Cores.verde,
      child: Column(
        children: [
          _cabecalho(),
          Expanded(child: _painelBranco()),
        ],
      ),
    );
  }

  Widget _cabecalho() {
    return Container(
      color: Cores.verde,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onVoltar,
                  tooltip: 'Voltar',
                  icon: const Icon(Icons.chevron_left,
                      color: Colors.white, size: 27),
                ),
                const Expanded(
                  child: Text(
                    'Controle de Marmitas',
                    style: TextStyle(color: Colors.white, fontSize: 14.5),
                  ),
                ),
                if (widget.onSair != null)
                  IconButton(
                    onPressed: widget.onSair,
                    tooltip: 'Sair',
                    icon: const Icon(Icons.logout,
                        color: Colors.white, size: 22),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _painelBranco() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(42),
          topRight: Radius.circular(42),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(42),
          topRight: Radius.circular(42),
        ),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'RESERVA DE MARMITAS',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'RU UEMG',
                  style: TextStyle(
                    color: Cores.azulEscuro,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            if (_ruFechadoHoje) ...[
              const SizedBox(height: 12),
              _bannerRuFechado(),
            ],
            const SizedBox(height: 10),
            StreamBuilder<Disponibilidade?>(
              stream: _dispStream,
              builder: (context, snapshot) {
                final disp = snapshot.data;
                final qtd = disp?.quantidadeDisponivel ?? 0;
                return RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        color: Colors.black87, fontSize: 13),
                    children: [
                      const TextSpan(text: 'QUANTIDADE DISPONÍVEL:  '),
                      TextSpan(
                        text: disp == null
                            ? 'nenhuma cadastrada'
                            : '$qtd ${qtd == 1 ? 'Unidade' : 'Unidades'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<TipoRefeicao>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Cores.azulEscuro,
                  selectedForegroundColor: Colors.white,
                ),
                segments: const [
                  ButtonSegment(
                      value: TipoRefeicao.almoco, label: Text('Almoço')),
                  ButtonSegment(
                      value: TipoRefeicao.janta, label: Text('Janta')),
                ],
                selected: {_refeicaoSelecionada},
                onSelectionChanged: (novo) => setState(() {
                  _refeicaoSelecionada = novo.first;
                  _dispStream = _criarDispStream();
                }),
              ),
            ),
            const SizedBox(height: 22),
            const Center(
              child: Text(
                'Quantidade a reservar:',
                style: TextStyle(fontSize: 19, color: Colors.black87),
              ),
            ),
            const Center(
              child: Text(
                '1',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _cartaoConferencia(),
            const SizedBox(height: 28),
            const Text(
              'Minhas reservas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            _listaReservas(),
          ],
        ),
      ),
    );
  }

  Widget _bannerRuFechado() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Cores.vermelho),
      ),
      child: Row(
        children: [
          const Icon(Icons.block, color: Cores.vermelho),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusRu.motivo.isEmpty
                  ? 'O RU está fechado hoje. Novas reservas estão bloqueadas.'
                  : 'RU fechado hoje: ${_statusRu.motivo}',
              style: const TextStyle(color: Cores.vermelho, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  /// Cartão azul com os dados do usuário para conferência + opção
  /// vegetariana + botão de reservar.
  Widget _cartaoConferencia() {
    const branco = TextStyle(color: Colors.white, fontSize: 13);
    const brancoNegrito = TextStyle(
      color: Colors.white,
      fontSize: 13.5,
      fontWeight: FontWeight.bold,
    );
    final id = _identificacao;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: Cores.azulEscuro,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text(
            '${_nomeRefeicao(_refeicaoSelecionada)} de hoje • '
            '${_dataCurta(_hoje)}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 10),
          const Text('Reserva de 1 marmita para:', style: branco),
          const SizedBox(height: 4),
          Text(
            widget.usuario.nome.toUpperCase(),
            textAlign: TextAlign.center,
            style: brancoNegrito,
          ),
          const SizedBox(height: 14),
          Text(id.rotulo, style: brancoNegrito),
          const SizedBox(height: 2),
          Text(id.valor, style: branco),
          const SizedBox(height: 14),
          const Text('Valor a ser descontado:', style: branco),
          const SizedBox(height: 2),
          FutureBuilder<double>(
            future: _valorFuture,
            builder: (context, snap) => Text(
              snap.hasData ? _dinheiro(snap.data!) : 'carregando...',
              style: brancoNegrito,
            ),
          ),
          const SizedBox(height: 14),
          const Text('Saldo atual:', style: branco),
          const SizedBox(height: 2),
          StreamBuilder<double>(
            stream: _saldoStream,
            builder: (context, snap) => Text(
              _dinheiro(snap.data ?? widget.usuario.saldoAtual),
              style: brancoNegrito,
            ),
          ),
          const SizedBox(height: 18),
          const Text('Opção Vegetariana?', style: branco),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _botaoOpcao('Sim', selecionado: _vegetariana, onTap: () {
                setState(() => _vegetariana = true);
              }),
              const SizedBox(width: 18),
              _botaoOpcao('Não', selecionado: !_vegetariana, onTap: () {
                setState(() => _vegetariana = false);
              }),
            ],
          ),
          const SizedBox(height: 22),
          StreamBuilder<Disponibilidade?>(
            stream: _dispStream,
            builder: (context, snapshot) {
              final disp = snapshot.data;
              final esgotado = disp == null || disp.esgotado;
              final fechado = _ruFechadoHoje;
              return SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Cores.verde,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white24,
                    disabledForegroundColor: Colors.white60,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed:
                      (esgotado || fechado || _reservando) ? null : _reservar,
                  child: _reservando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          fechado
                              ? 'RU fechado hoje'
                              : disp == null
                              ? 'Sem marmitas cadastradas'
                              : esgotado
                                  ? 'Esgotado'
                                  : 'Reservar',
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _botaoOpcao(
    String rotulo, {
    required bool selecionado,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selecionado ? Cores.verde : Cores.verde.withAlpha(90),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 64,
          height: 28,
          alignment: Alignment.center,
          child: Text(
            rotulo,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _listaReservas() {
    return StreamBuilder<List<Reserva>>(
      stream: _reservasStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('ERRO RESERVAS: ${snapshot.error}');
          return const Text(
            'Não foi possível carregar suas reservas.',
            style: TextStyle(color: Color(0xFF666666), fontSize: 12),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reservas = snapshot.data!;
        if (reservas.isEmpty) {
          return const Text(
            'Você ainda não fez nenhuma reserva.',
            style: TextStyle(color: Color(0xFF666666), fontSize: 12),
          );
        }
        return Column(
          children: reservas.map(_itemReserva).toList(),
        );
      },
    );
  }

  Widget _itemReserva(Reserva r) {
    final agora = DateTime.now();
    final ehHoje = r.data.year == agora.year &&
        r.data.month == agora.month &&
        r.data.day == agora.day;
    final podeCancelar = r.status == StatusReserva.confirmada;
    // Pode retirar: liberada na catraca, ou confirmada enquanto a
    // integração da catraca estiver desligada (o serviço confere o
    // horário da refeição ao tocar).
    final podeRetirar = ehHoje &&
        (r.status == StatusReserva.liberada ||
            (r.status == StatusReserva.confirmada && !_integracaoCatraca));
    final podeVerProtocolo =
        r.status == StatusReserva.utilizada && r.protocoloValido(agora);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: Cores.fundo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_nomeRefeicao(r.tipoRefeicao)} - ${_dataCurta(r.data)}'
                  '${r.vegetariana ? ' • Vegetariana' : ''}',
                  style: const TextStyle(
                    color: Color(0xFF444444),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_rotuloStatus(r.status)} • ${_dinheiro(r.valor)}',
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (podeRetirar)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Cores.verde,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () => _retirar(r),
              child: const Text('Retirar'),
            ),
          if (podeVerProtocolo)
            TextButton(
              onPressed: () => _verProtocolo(r),
              child: const Text('Ver protocolo'),
            ),
          if (podeCancelar)
            TextButton(
              onPressed: () => _cancelar(r),
              child: const Text('Cancelar'),
            ),
        ],
      ),
    );
  }
}