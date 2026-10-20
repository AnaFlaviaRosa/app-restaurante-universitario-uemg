import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../models/movimentacao.dart';
import '../../services/saldo_service.dart';
import '../../theme/cores.dart';

/// Fluxo C definido pelo grupo: ver saldo, recarregar e ver histórico.
///
/// MVP: a recarga é SIMULADA (não existe PIX/cartão de verdade).
/// O usuário escolhe PIX ou cartão, informa um valor e confirma; o saldo
/// é atualizado na hora.
///
/// Visual: cabeçalho verde + cartão azul-escuro com saldo, botões de
/// recarga e lista de movimentações em um painel branco arredondado.
class SaldoTab extends StatefulWidget {
  final Usuario usuario;

  /// Chamado ao tocar na seta do cabeçalho (ex.: voltar para a aba Início).
  final VoidCallback? onVoltar;

  /// Chamado ao tocar no ícone de sair do cabeçalho.
  final VoidCallback? onSair;

  const SaldoTab({
    super.key,
    required this.usuario,
    this.onVoltar,
    this.onSair,
  });

  @override
  State<SaldoTab> createState() => _SaldoTabState();
}

class _SaldoTabState extends State<SaldoTab> {
  final _saldoService = SaldoService();
  final _valorController = TextEditingController();
  bool _recarregando = false;
  bool _ocultarSaldo = false;

  // Streams criados uma única vez (evita reassinar a consulta do Firestore
  // a cada setState).
  late Stream<double> _saldoStream;
  late Stream<List<Movimentacao>> _historicoStream;

  static const _meses = [
    'JANEIRO',
    'FEVEREIRO',
    'MARÇO',
    'ABRIL',
    'MAIO',
    'JUNHO',
    'JULHO',
    'AGOSTO',
    'SETEMBRO',
    'OUTUBRO',
    'NOVEMBRO',
    'DEZEMBRO',
  ];

  @override
  void initState() {
    super.initState();
    _criarStreams();
  }

  @override
  void didUpdateWidget(covariant SaldoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.usuario.id != widget.usuario.id) {
      _criarStreams();
    }
  }

  void _criarStreams() {
    _saldoStream = _saldoService.saldoStream(widget.usuario.id);
    _historicoStream = _saldoService.historicoStream(widget.usuario.id);
  }

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  // ---------- formatação ----------

  String _dinheiro(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  /// Ex.: "22 DE JULHO 17:43"
  String _dataFormatada(DateTime d) {
    final hora = d.hour.toString().padLeft(2, '0');
    final minuto = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')} DE ${_meses[d.month - 1]} '
        '$hora:$minuto';
  }

  String _titulo(Movimentacao m) {
    if (m.tipo == TipoMovimentacao.consumo) return 'CONSUMO NO RU';
    if (m.tipo == TipoMovimentacao.estorno) return 'ESTORNO DE RESERVA';

    final base = m.metodo == 'pix'
        ? 'TRANSFERENCIA PIX.'
        : m.metodo == 'cartao'
            ? 'DEPÓSITO CARTÃO DEB.'
            : 'RECARGA DE SALDO';
    final sufixo = switch (m.status) {
      StatusMovimentacao.aprovada => '',
      StatusMovimentacao.pendente => ' (PENDENTE)',
      StatusMovimentacao.recusada => ' (RECUSADA)',
    };
    return '$base$sufixo';
  }

  // ---------- recarga ----------

  Future<void> _abrirDialogoRecarga({required bool pix}) async {
    _valorController.clear();
    final valor = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(pix ? 'Recarga via PIX' : 'Recarga via cartão'),
        content: TextField(
          controller: _valorController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Valor da recarga',
            prefixText: 'R\$ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(
                _valorController.text.replaceAll(',', '.'),
              );
              if (v == null || v <= 0) return;
              Navigator.pop(dialogContext, v);
            },
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );

    if (valor == null || !mounted) return;

    setState(() => _recarregando = true);
    try {
      await _saldoService.simularRecarga(
        usuarioId: widget.usuario.id,
        valor: valor,
        metodo: pix ? 'pix' : 'cartao',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recarga de ${_dinheiro(valor)} realizada!')),
      );
    } catch (e) {
      debugPrint('ERRO RECARGA: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível concluir a recarga.')),
      );
    } finally {
      if (mounted) setState(() => _recarregando = false);
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return Container(
      // Verde atrás dos cantos arredondados do cartão azul.
      color: Cores.verde,
      child: Column(
        children: [
          _cabecalho(),
          Expanded(child: _cartaoPrincipal()),
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
                    'Saldo, Recarga e Histórico',
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

  Widget _cartaoPrincipal() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Cores.azulEscuro,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(42),
          topRight: Radius.circular(42),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(27, 36, 27, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _blocoSaldo()),
                const SizedBox(width: 15),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    'RU UEMG',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 27),
            height: 1,
            color: Colors.white24,
          ),
          const SizedBox(height: 10),
          const Text(
            'Realizar Recarga',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _botaoRecarga(
                icone: Icons.account_balance_wallet_outlined,
                rotulo: 'PIX',
                onTap: _recarregando
                    ? null
                    : () => _abrirDialogoRecarga(pix: true),
              ),
              const SizedBox(width: 28),
              _botaoRecarga(
                icone: Icons.credit_card_outlined,
                rotulo: 'CARTÃO',
                onTap: _recarregando
                    ? null
                    : () => _abrirDialogoRecarga(pix: false),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 27),
              child: Container(
                padding: const EdgeInsets.only(bottom: 4),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white, width: 2),
                  ),
                ),
                child: const Text(
                  'MOVIMENTAÇÕES',
                  style: TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(child: _painelHistorico()),
        ],
      ),
    );
  }

  Widget _blocoSaldo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Saldo disponível',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _ocultarSaldo = !_ocultarSaldo),
              child: Icon(
                _ocultarSaldo
                    ? Icons.visibility
                    : Icons.visibility_off_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        StreamBuilder<double>(
          stream: _saldoStream,
          builder: (context, snapshot) {
            final saldo = snapshot.data ?? 0;
            return Text(
              _ocultarSaldo ? 'R\$ •••••' : _dinheiro(saldo),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w400,
              ),
            );
          },
        ),
        if (_recarregando)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Processando recarga...',
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
      ],
    );
  }

  Widget _botaoRecarga({
    required IconData icone,
    required String rotulo,
    required VoidCallback? onTap,
  }) {
    return Column(
      children: [
        Material(
          color: onTap == null ? Colors.white54 : Colors.white,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icone, color: Cores.verde, size: 29),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          rotulo,
          style: const TextStyle(color: Colors.white, fontSize: 9),
        ),
      ],
    );
  }

  Widget _painelHistorico() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 20, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Cores.azulBorda, width: 2),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(38),
          topRight: Radius.circular(38),
        ),
      ),
      child: StreamBuilder<List<Movimentacao>>(
        stream: _historicoStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Mostra o erro real no console (índice faltando, permissão...).
            debugPrint('ERRO HISTÓRICO: ${snapshot.error}');
            return const Center(
              child: Text(
                'Não foi possível carregar o histórico.',
                style: TextStyle(color: Color(0xFF666666), fontSize: 12),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final movimentacoes = snapshot.data!;
          if (movimentacoes.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma movimentação ainda.',
                style: TextStyle(color: Color(0xFF666666), fontSize: 12),
              ),
            );
          }
          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: movimentacoes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _itemHistorico(movimentacoes[index]),
          );
        },
      ),
    );
  }

  Widget _itemHistorico(Movimentacao m) {
    final entrada = m.tipo != TipoMovimentacao.consumo;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: entrada ? Cores.verdeVivo : Cores.vermelho,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            entrada ? Icons.arrow_downward : Icons.arrow_upward,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titulo(m),
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _dataFormatada(m.data),
                style: const TextStyle(
                  color: Color(0xFFB9B9B9),
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${entrada ? '' : '- '}${_dinheiro(m.valor)}',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}