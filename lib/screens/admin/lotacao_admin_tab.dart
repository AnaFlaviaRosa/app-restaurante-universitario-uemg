import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/lotacao.dart';
import '../../services/lotacao_service.dart';
import '../../theme/cores.dart';
import '../../utils/lotacao_calculo.dart';
import 'cardapio_admin_card.dart';

/// Configuração da lotação. Dois modos:
/// - manual: o administrador informa quantas pessoas estão no RU;
/// - catraca: o app conta as entradas registradas pela catraca e estima
///   quem está dentro usando a permanência média informada aqui.
/// Logo abaixo, na mesma aba, fica o envio da imagem do cardápio do dia
/// (CardapioAdminCard).
class LotacaoAdminTab extends StatefulWidget {
  const LotacaoAdminTab({super.key});

  @override
  State<LotacaoAdminTab> createState() => _LotacaoAdminTabState();
}

class _LotacaoAdminTabState extends State<LotacaoAdminTab> {
  final _lotacaoService = LotacaoService();
  final _quantidadeController = TextEditingController();
  final _capacidadeController = TextEditingController(text: '200');
  final _permanenciaController =
      TextEditingController(text: '${Lotacao.permanenciaPadraoMin}');
  bool _usaCatraca = false;
  bool _carregouValores = false;
  bool _salvando = false;
  bool _ocupado = false;
  final Map<int, int> _contagens = {};

  Future<void> _salvar() async {
    final quantidade = int.tryParse(_quantidadeController.text) ?? 0;
    final capacidade = int.tryParse(_capacidadeController.text);
    final permanencia = int.tryParse(_permanenciaController.text);
    if (capacidade == null || permanencia == null || permanencia <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Confira a capacidade e a permanência média.')));
      return;
    }

    setState(() => _salvando = true);
    try {
      await _lotacaoService.atualizarLotacao(
        quantidadeAtual: quantidade,
        capacidadeMaxima: capacidade,
        adminId: FirebaseAuth.instance.currentUser!.uid,
        modo: _usaCatraca ? Lotacao.modoCatraca : Lotacao.modoManual,
        permanenciaMediaMin: permanencia,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Lotação atualizada.')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _carregarContagens().catchError((_) {});
  }

  /// Executa uma ação do simulador, mostra o resultado e recarrega as
  /// contagens. Qualquer erro aparece na tela (antes falhava em silêncio).
  Future<void> _executarSimulacao(
      Future<String> Function() acao) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    String mensagem;
    try {
      mensagem = await acao();
      await _carregarContagens();
    } on FirebaseException catch (e) {
      mensagem = e.code == 'permission-denied'
          ? 'Sem permissão. Publique o firestore.rules atualizado no '
              'Firebase Console e confirme que você é administrador.'
          : 'Erro: ${e.code}';
    } catch (e) {
      mensagem = 'Erro: $e';
    }
    if (!mounted) return;
    setState(() => _ocupado = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  /// Conta as entradas de cada janela (4 leituras) para o admin conferir.
  Future<void> _carregarContagens() async {
    final r = await Future.wait(
        [for (final m in janelasLotacaoMin) _lotacaoService.entradasNosUltimos(m)]);
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < janelasLotacaoMin.length; i++) {
        _contagens[janelasLotacaoMin[i]] = r[i];
      }
    });
  }

  /// Cartão do simulador: funciona sem a catraca real.
  Widget _cartaoSimulador() {
    Widget botao(String texto, IconData icone, Future<String> Function() acao) {
      return OutlinedButton.icon(
        onPressed: _ocupado ? null : () => _executarSimulacao(acao),
        icon: Icon(icone, size: 18),
        label: Text(texto),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Cores.fundo,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sensor_door_outlined, color: Cores.azulEscuro),
              SizedBox(width: 8),
              Text('SIMULADOR DA CATRACA',
                  style: TextStyle(
                      color: Cores.azulEscuro,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Cria entradas de teste, como se a catraca tivesse enviado os '
            'bips. Os botões de período dos estudantes contam essas '
            'entradas. Use com o modo catraca ligado e salvo.',
            style: TextStyle(color: Color(0xFF666666), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              botao('+1 agora', Icons.add, () async {
                await _lotacaoService.registrarEntrada(origem: 'manual');
                return '1 entrada registrada agora.';
              }),
              botao('+10 agora', Icons.group_add, () async {
                await _lotacaoService.registrarEntradas(10);
                return '10 entradas registradas agora.';
              }),
              botao('Movimento: 60 em 30 min', Icons.timeline, () async {
                await _lotacaoService.simularMovimento(
                    total: 60, ultimosMin: 30);
                return '60 entradas espalhadas nos últimos 30 min.';
              }),
              botao('Movimento: 150 em 1 h', Icons.stacked_line_chart,
                  () async {
                await _lotacaoService.simularMovimento(
                    total: 150, ultimosMin: 60);
                return '150 entradas espalhadas na última hora.';
              }),
              botao('Limpar simulações', Icons.delete_outline, () async {
                final n = await _lotacaoService.limparSimulacao();
                return '$n entradas de simulação apagadas.';
              }),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text('Entradas registradas:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: _ocupado
                    ? null
                    : () => _executarSimulacao(() async {
                          return 'Contagens atualizadas.';
                        }),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Contar'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final m in janelasLotacaoMin)
                Chip(
                  label: Text(
                      '${rotuloJanela(m)}: ${_contagens[m]?.toString() ?? '–'}'),
                ),
            ],
          ),
          if (_ocupado)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Lotacao?>(
      stream: _lotacaoService.lotacaoStream(),
      builder: (context, snapshot) {
        final lotacaoAtual = snapshot.data;
        // Preenche os campos uma única vez com o valor salvo.
        if (lotacaoAtual != null && !_carregouValores) {
          _carregouValores = true;
          _quantidadeController.text = lotacaoAtual.quantidadeAtual.toString();
          _capacidadeController.text = lotacaoAtual.capacidadeMaxima.toString();
          _permanenciaController.text =
              lotacaoAtual.permanenciaMediaMin.toString();
          _usaCatraca = lotacaoAtual.usaCatraca;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (lotacaoAtual != null)
              Text(
                lotacaoAtual.usaCatraca
                    ? 'Modo atual: catraca (contagem automática)'
                    : 'Valor atual: ${lotacaoAtual.quantidadeAtual} / '
                        '${lotacaoAtual.capacidadeMaxima} — '
                        '${lotacaoAtual.statusTexto}',
                style: const TextStyle(color: Colors.black54),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Usar contagem da catraca'),
              subtitle: const Text(
                  'O app conta as entradas e estima quantas pessoas estão '
                  'no RU. Desligado: valor informado manualmente.'),
              value: _usaCatraca,
              onChanged: (v) => setState(() => _usaCatraca = v),
            ),
            const SizedBox(height: 8),
            if (!_usaCatraca) ...[
              TextField(
                controller: _quantidadeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Pessoas presentes agora',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _capacidadeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Capacidade máxima do RU',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _permanenciaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Permanência média de uma pessoa (minutos)',
                helperText: 'Usada para estimar quem ainda está no RU.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _salvando ? null : _salvar,
              child: Text(_salvando ? 'Salvando...' : 'Atualizar lotação'),
            ),
            const SizedBox(height: 24),
            _cartaoSimulador(),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            const CardapioAdminCard(),
          ],
        );
      },
    );
  }
}
