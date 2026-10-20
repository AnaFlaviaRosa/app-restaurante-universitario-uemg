import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../models/reserva.dart';
import '../../models/disponibilidade.dart';
import '../../services/reserva_service.dart';
import '../../services/saldo_service.dart';
import '../../theme/cores.dart';

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
  }

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

  String _rotuloStatus(StatusReserva s) {
    switch (s) {
      case StatusReserva.confirmada:
        return 'Confirmada';
      case StatusReserva.cancelada:
        return 'Cancelada';
      case StatusReserva.utilizada:
        return 'Utilizada';
      case StatusReserva.naoRetirada:
        return 'Não retirada';
    }
  }

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

  String _mensagemDeErro(Object e) {
    if (e is SaldoInsuficienteException) return e.message;
    if (e is MarmitaEsgotadaException) return e.message;
    if (e is ReservaJaExisteException) return e.message;
    if (e is ForaDoPrazoException) return e.message;
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
                  onPressed: (esgotado || _reservando) ? null : _reservar,
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
                          disp == null
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
    final podeCancelar = r.status == StatusReserva.confirmada;
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