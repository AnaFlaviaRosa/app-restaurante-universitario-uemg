import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../models/lotacao.dart';
import '../../services/lotacao_service.dart';
import '../../theme/cores.dart';

/// Fluxo A definido pelo grupo: "descobrir se vale a pena ir ao RU agora".
///
/// Mostra a lotação atual (atualizada manualmente pelo administrador no
/// MVP) e o cardápio do dia, que é uma IMAGEM única (o mesmo cardápio vale
/// para almoço e janta). A imagem fica em assets/images/cardapio.jpeg;
/// para atualizar o cardápio, basta trocar esse arquivo.
///
/// Visual: cabeçalho verde com avatar e "Olá, Nome" + painel branco
/// arredondado com lotação, última atualização e a imagem do cardápio.
class InicioTab extends StatefulWidget {
  final Usuario usuario;

  /// Chamado ao tocar no ícone de sair do cabeçalho.
  final VoidCallback? onSair;

  const InicioTab({super.key, required this.usuario, this.onSair});

  @override
  State<InicioTab> createState() => _InicioTabState();
}

class _InicioTabState extends State<InicioTab> {
  static const _imagemCardapio = 'assets/images/cardapio.jpeg';

  final _lotacaoService = LotacaoService();
  late Stream<Lotacao?> _lotacaoStream;

  @override
  void initState() {
    super.initState();
    _lotacaoStream = _lotacaoService.lotacaoStream();
  }

  // ---------- formatação ----------

  String _dois(int n) => n.toString().padLeft(2, '0');

  /// Ex.: "11h15"
  String _horaFormatada(DateTime d) => '${_dois(d.hour)}h${_dois(d.minute)}';

  Color _corStatus(String status) {
    switch (status) {
      case 'Baixo movimento':
        return Cores.verdeVivo;
      case 'Médio movimento':
        return Colors.orange;
      case 'Alta ocupação':
        return Cores.vermelho;
      default:
        return Colors.grey;
    }
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
    final primeiroNome = widget.usuario.nome.trim().isEmpty
        ? 'Usuário'
        : widget.usuario.nome.trim().split(' ').first;

    return Container(
      color: Cores.verde,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 8, 0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFFD9D9D9),
                  child: Icon(Icons.person, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Olá, $primeiroNome',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14.5),
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
            _blocoLotacao(),
            const SizedBox(height: 22),
            _blocoCardapio(),
          ],
        ),
      ),
    );
  }

  // ---------- lotação ----------

  Widget _blocoLotacao() {
    const estilo = TextStyle(color: Colors.black87, fontSize: 13);

    return StreamBuilder<Lotacao?>(
      stream: _lotacaoStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('ERRO LOTAÇÃO: ${snapshot.error}');
          return const Text('Não foi possível carregar a lotação.',
              style: estilo);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('LOTAÇÃO: carregando...', style: estilo);
        }
        final lotacao = snapshot.data;
        if (lotacao == null) {
          return const Text('LOTAÇÃO: sem informação ainda.', style: estilo);
        }
        final cor = _corStatus(lotacao.statusTexto);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LOTAÇÃO: ${lotacao.quantidadeAtual}/${lotacao.capacidadeMaxima}',
              style: estilo,
            ),
            Text(
              'ÚLTIMA ATUALIZAÇÃO: ${_horaFormatada(lotacao.atualizadoEm)}',
              style: estilo,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: cor),
                const SizedBox(width: 6),
                Text(
                  lotacao.statusTexto,
                  style: TextStyle(
                    color: cor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ---------- cardápio (imagem) ----------

  Widget _blocoCardapio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CARDÁPIO (ALMOÇO E JANTA)',
          style: TextStyle(color: Colors.black87, fontSize: 13),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _abrirCardapioAmpliado,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              _imagemCardapio,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              errorBuilder: (context, erro, stack) {
                debugPrint('ERRO IMAGEM CARDÁPIO: $erro');
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 36, horizontal: 20),
                  color: Cores.fundo,
                  child: const Text(
                    'Não foi possível carregar o cardápio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF666666), fontSize: 12),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Toque na imagem para ampliar.',
          style: TextStyle(color: Color(0xFF999999), fontSize: 10),
        ),
      ],
    );
  }

  /// Abre o cardápio em tela cheia, com zoom por pinça.
  void _abrirCardapioAmpliado() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.asset(_imagemCardapio, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(dialogContext),
              tooltip: 'Fechar',
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}