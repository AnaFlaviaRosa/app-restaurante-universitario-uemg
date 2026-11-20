import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lotacao.dart';
import '../services/lotacao_service.dart';
import '../theme/cores.dart';
import '../utils/lotacao_calculo.dart';

/// Intervalo da atualização automática da estimativa.
/// Ninguém precisa da lotação ao segundo; 5 min mantém o consumo de
/// leituras do Firestore baixo (plano gratuito: 50 mil leituras/dia).
const Duration kIntervaloAtualizacaoLotacao = Duration(minutes: 5);

Color _corDoStatus(String status) {
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

String _dois(int n) => n.toString().padLeft(2, '0');
String _hora(DateTime d) => '${_dois(d.hour)}h${_dois(d.minute)}';

/// "Atualizado às 11h05" se for de hoje; com a data se for de outro dia
/// ("Atualizado em 18/11 às 11h05"), para não passar a impressão de que
/// um dado antigo é de agora.
String _textoAtualizado(DateTime d) {
  final agora = DateTime.now();
  final ehHoje =
      d.year == agora.year && d.month == agora.month && d.day == agora.day;
  return ehHoje
      ? 'Atualizado às ${_hora(d)}'
      : 'Atualizado em ${_dois(d.day)}/${_dois(d.month)} às ${_hora(d)}';
}

/// Cartão visual da lotação: medidor circular colorido, número grande,
/// situação ("Baixo movimento"...) e horário da atualização.
/// Usado nos dois modos (manual e catraca) para manter o mesmo visual.
class MedidorLotacao extends StatelessWidget {
  final int quantidade;
  final int capacidade;
  final DateTime? atualizadoEm;
  final bool aproximado; // true = estimativa (mostra "~")
  final String? legenda;
  final VoidCallback? onAtualizar;

  const MedidorLotacao({
    super.key,
    required this.quantidade,
    required this.capacidade,
    this.atualizadoEm,
    this.aproximado = false,
    this.legenda,
    this.onAtualizar,
  });

  @override
  Widget build(BuildContext context) {
    final status = Lotacao.statusPara(quantidade, capacidade);
    final cor = _corDoStatus(status);
    final proporcao =
        capacidade > 0 ? (quantidade / capacidade).clamp(0.0, 1.0) : 0.0;
    final percentual = (proporcao * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 18),
      decoration: BoxDecoration(
        color: Cores.fundo,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded,
                  color: Cores.azulEscuro, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'LOTAÇÃO DO RU',
                  style: TextStyle(
                    color: Cores.azulEscuro,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (onAtualizar != null)
                IconButton(
                  onPressed: onAtualizar,
                  tooltip: 'Atualizar agora',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh_rounded,
                      color: Cores.azulEscuro),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              SizedBox(
                width: 118,
                height: 118,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 118,
                      height: 118,
                      child: CircularProgressIndicator(
                        value: proporcao,
                        strokeWidth: 12,
                        backgroundColor: const Color(0xFFE2E2E2),
                        valueColor: AlwaysStoppedAnimation<Color>(cor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${aproximado ? '~' : ''}$quantidade',
                          style: TextStyle(
                            color: cor,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'de $capacidade',
                          style: const TextStyle(
                              color: Color(0xFF666666), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      capacidade > 0
                          ? '$percentual% da capacidade'
                          : 'Capacidade não informada',
                      style: const TextStyle(
                          color: Colors.black87, fontSize: 13),
                    ),
                    if (legenda != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        legenda!,
                        style: const TextStyle(
                            color: Color(0xFF666666), fontSize: 11),
                      ),
                    ],
                    if (atualizadoEm != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 13, color: Color(0xFF666666)),
                          const SizedBox(width: 4),
                          Text(
                            _textoAtualizado(atualizadoEm!),
                            style: const TextStyle(
                                color: Color(0xFF666666), fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Seletor "Quem chegou nos últimos…" (5 min, 10 min, 30 min, 1 h).
/// Aparece SEMPRE na tela do estudante, nos dois modos de lotação.
/// A contagem só é feita quando o usuário TOCA no botão (1 leitura).
class SeletorJanelasLotacao extends StatefulWidget {
  const SeletorJanelasLotacao({super.key});

  @override
  State<SeletorJanelasLotacao> createState() => SeletorJanelasLotacaoState();
}

class SeletorJanelasLotacaoState extends State<SeletorJanelasLotacao> {
  final _service = LotacaoService();

  int? _janelaMin; // nenhuma janela escolhida até o toque
  int? _entradasJanela;
  DateTime? _contadaEm;
  bool _carregando = false;
  bool _erro = false;

  /// Conta de novo a janela escolhida (usado pelo ícone de atualizar).
  void recontar() {
    final j = _janelaMin;
    if (j != null) _contar(j);
  }

  Future<void> _contar(int minutos) async {
    if (_carregando) return;
    setState(() {
      _janelaMin = minutos;
      _entradasJanela = null;
      _carregando = true;
      _erro = false;
    });
    try {
      final n = await _service.entradasNosUltimos(minutos);
      if (!mounted) return;
      setState(() {
        _entradasJanela = n;
        _contadaEm = DateTime.now();
      });
    } catch (e) {
      debugPrint('ERRO CONTAGEM JANELA: $e');
      if (mounted) setState(() => _erro = true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QUEM CHEGOU NOS ÚLTIMOS…',
          style: TextStyle(
            color: Cores.azulEscuro,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final min in janelasLotacaoMin) ...[
              Expanded(child: _botao(min)),
              if (min != janelasLotacaoMin.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _resultado(),
      ],
    );
  }

  Widget _botao(int min) {
    final selecionado = _janelaMin == min;
    return GestureDetector(
      onTap: () => _contar(min),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selecionado ? Cores.verde : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selecionado ? Cores.verde : const Color(0xFFD0D0D0),
            width: 1.5,
          ),
        ),
        child: Text(
          rotuloJanela(min),
          style: TextStyle(
            color: selecionado ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _resultado() {
    Widget conteudo;
    if (_erro) {
      conteudo = const Text('Não foi possível contar agora. Tente de novo.',
          style: TextStyle(color: Color(0xFF666666), fontSize: 12));
    } else if (_janelaMin == null) {
      conteudo = const Text(
        'Toque em um período para ver quantas pessoas entraram.',
        style: TextStyle(color: Color(0xFF666666), fontSize: 12),
      );
    } else if (_entradasJanela == null) {
      conteudo = const Row(
        children: [
          SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5)),
          SizedBox(width: 10),
          Text('Contando...', style: TextStyle(fontSize: 12)),
        ],
      );
    } else {
      conteudo = Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$_entradasJanela',
            style: const TextStyle(
              color: Cores.azulEscuro,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _entradasJanela == 1
                  ? 'pessoa entrou em ${rotuloJanela(_janelaMin!)}'
                  : 'pessoas entraram em ${rotuloJanela(_janelaMin!)}',
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
          if (_contadaEm != null)
            Text('às ${_hora(_contadaEm!)}',
                style:
                    const TextStyle(color: Color(0xFF666666), fontSize: 11)),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Cores.fundo,
        borderRadius: BorderRadius.circular(18),
      ),
      child: conteudo,
    );
  }
}

/// Lotação no modo catraca: medidor com a ESTIMATIVA de pessoas no RU
/// (entradas dentro da permanência média), atualizado sozinho a cada
/// 5 min (1 leitura), mais o seletor de janelas.
///
/// A atualização automática pausa quando o app vai para segundo plano e
/// retoma (com uma consulta) ao voltar. Ao sair da aba Início o widget é
/// descartado e o timer para.
class LotacaoJanela extends StatefulWidget {
  final Lotacao lotacao;

  const LotacaoJanela({super.key, required this.lotacao});

  @override
  State<LotacaoJanela> createState() => _LotacaoJanelaState();
}

class _LotacaoJanelaState extends State<LotacaoJanela>
    with WidgetsBindingObserver {
  final _service = LotacaoService();
  final _seletorKey = GlobalKey<SeletorJanelasLotacaoState>();

  int? _entradasPermanencia;
  DateTime? _estimativaEm;
  bool _erro = false;
  bool _carregando = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _atualizarEstimativa();
    _iniciarTimer();
  }

  @override
  void didUpdateWidget(covariant LotacaoJanela antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.lotacao.permanenciaMediaMin !=
        widget.lotacao.permanenciaMediaMin) {
      _atualizarEstimativa();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _iniciarTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
        kIntervaloAtualizacaoLotacao, (_) => _atualizarEstimativa());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      _atualizarEstimativa();
      _iniciarTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _atualizarEstimativa() async {
    if (_carregando) return;
    _carregando = true;
    try {
      final n = await _service
          .entradasNosUltimos(widget.lotacao.permanenciaMediaMin);
      if (!mounted) return;
      setState(() {
        _entradasPermanencia = n;
        _estimativaEm = DateTime.now();
        _erro = false;
      });
    } catch (e) {
      debugPrint('ERRO LOTAÇÃO CATRACA: $e');
      if (mounted) setState(() => _erro = true);
    } finally {
      _carregando = false;
    }
  }

  void _atualizarTudo() {
    _atualizarEstimativa();
    _seletorKey.currentState?.recontar();
  }

  @override
  Widget build(BuildContext context) {
    final lotacao = widget.lotacao;
    Widget topo;
    if (_entradasPermanencia == null) {
      topo = _aviso(_erro
          ? 'Não foi possível carregar a lotação.'
          : 'Carregando a lotação...');
    } else {
      topo = MedidorLotacao(
        quantidade: estimarPresentes(
          entradasNaPermanencia: _entradasPermanencia!,
          capacidadeMaxima: lotacao.capacidadeMaxima,
        ),
        capacidade: lotacao.capacidadeMaxima,
        atualizadoEm: _estimativaEm,
        aproximado: true,
        legenda: 'Estimativa: entradas dos últimos '
            '${lotacao.permanenciaMediaMin} min',
        onAtualizar: _atualizarTudo,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        topo,
        const SizedBox(height: 18),
        SeletorJanelasLotacao(key: _seletorKey),
        const SizedBox(height: 8),
        const Text(
          'Valores aproximados: consideram que cada pessoa fica em média o '
          'tempo informado pelo RU.',
          style: TextStyle(color: Color(0xFF999999), fontSize: 10),
        ),
      ],
    );
  }

  Widget _aviso(String texto) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: Cores.fundo,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
      ),
    );
  }
}
