import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/usuario.dart';
import '../../../services/saldo_service.dart';
import '../../../theme/cores.dart';
import '../../../utils/pagamento.dart';
import '../../../widgets/auth_layout.dart';
import '../../../widgets/pagamento_scaffold.dart';
import '../../../widgets/qr_code_simulado.dart';
import '../../../widgets/seletor_valor_recarga.dart';
import 'comprovante_recarga_screen.dart';

enum _EtapaPix { valor, aguardando, confirmando, expirado }

/// Recarga via Pix (simulada), no mesmo caminho de um Pix de verdade:
///  1. a pessoa escolhe o valor;
///  2. o app gera a cobrança: QR Code + "Pix copia e cola" + prazo de
///     expiração (10 minutos);
///  3. a pessoa "paga no app do banco" (aqui, pelo botão de simulação);
///  4. o app confirma o recebimento e mostra o comprovante.
///
/// O saldo só é creditado (e a movimentação só é gravada) quando o
/// pagamento é confirmado. Se a cobrança expirar ou a pessoa sair, nada
/// é gravado.
class RecargaPixScreen extends StatefulWidget {
  final Usuario usuario;
  const RecargaPixScreen({super.key, required this.usuario});

  @override
  State<RecargaPixScreen> createState() => _RecargaPixScreenState();
}

class _RecargaPixScreenState extends State<RecargaPixScreen> {
  static const _duracaoSegundos = 600; // 10 minutos

  final _saldoService = SaldoService();

  _EtapaPix _etapa = _EtapaPix.valor;
  double? _valor;
  String _codigo = '';
  int _segundosRestantes = _duracaoSegundos;
  Timer? _timer;
  String? _erro;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _gerarCobranca() {
    final valor = _valor;
    if (erroValorRecarga(valor) != null) return;

    _codigo = gerarPixCopiaECola(
      valor: valor!,
      chave: chavePixRuSimulada,
      txid: gerarTxid(),
    );
    _timer?.cancel();
    setState(() {
      _etapa = _EtapaPix.aguardando;
      _segundosRestantes = _duracaoSegundos;
      _erro = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _etapa != _EtapaPix.aguardando) return;
      setState(() {
        _segundosRestantes--;
        if (_segundosRestantes <= 0) {
          _etapa = _EtapaPix.expirado;
          t.cancel();
        }
      });
    });
  }

  Future<void> _copiarCodigo() async {
    await Clipboard.setData(ClipboardData(text: _codigo));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código Pix copiado!')),
    );
  }

  /// Faz de conta que a pessoa pagou no app do banco: espera um pouco
  /// ("identificando o pagamento") e então confirma a recarga.
  Future<void> _simularPagamento() async {
    setState(() {
      _etapa = _EtapaPix.confirmando;
      _erro = null;
    });
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    try {
      final agora = DateTime.now();
      final idPix = gerarIdTransacaoPix(agora);
      final novoSaldo = await _saldoService.simularRecarga(
        usuarioId: widget.usuario.id,
        valor: _valor!,
        metodo: 'pix',
        transacaoId: idPix,
      );
      _timer?.cancel();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ComprovanteRecargaScreen(
            dados: DadosComprovanteRecarga(
              valor: _valor!,
              formaPagamento: 'Pix',
              rotuloTransacao: 'ID da transação (Pix)',
              transacaoId: idPix,
              data: agora,
              novoSaldo: novoSaldo,
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('ERRO PIX: $e');
      if (!mounted) return;
      setState(() {
        _etapa = _EtapaPix.aguardando;
        _erro = 'Não foi possível confirmar o pagamento. Tente de novo.';
      });
    }
  }

  String get _tempoFormatado {
    final m = (_segundosRestantes ~/ 60).toString().padLeft(2, '0');
    final s = (_segundosRestantes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PagamentoScaffold(
      titulo: 'Recarga via Pix',
      children: switch (_etapa) {
        _EtapaPix.valor => _telaValor(),
        _EtapaPix.aguardando => _telaAguardando(),
        _EtapaPix.confirmando => _telaConfirmando(),
        _EtapaPix.expirado => _telaExpirado(),
      },
    );
  }

  // ---------- etapas ----------

  List<Widget> _telaValor() {
    return [
      const AvisoSimulacao(),
      const SizedBox(height: 22),
      SeletorValorRecarga(onChanged: (v) => setState(() => _valor = v)),
      const SizedBox(height: 14),
      const Text(
        'O Pix é instantâneo: assim que o pagamento for confirmado, o saldo '
        'cai na hora.',
        style: TextStyle(color: Colors.black54, fontSize: 12),
      ),
      const SizedBox(height: 24),
      AuthBotao(
        texto: 'Gerar QR Code Pix',
        onPressed: erroValorRecarga(_valor) == null ? _gerarCobranca : null,
      ),
    ];
  }

  List<Widget> _telaAguardando() {
    final urgente = _segundosRestantes <= 60;
    return [
      const AvisoSimulacao(),
      const SizedBox(height: 18),
      Center(
        child: Text(
          formatarDinheiro(_valor!),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 4),
      const Center(
        child: Text(
          'Pagamento para RU UEMG · Passos/MG',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ),
      const SizedBox(height: 18),
      Center(child: QrCodeSimulado(dados: _codigo)),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_outlined,
              size: 18, color: urgente ? Cores.vermelho : Colors.black54),
          const SizedBox(width: 6),
          Text(
            'Expira em $_tempoFormatado',
            style: TextStyle(
              color: urgente ? Cores.vermelho : Colors.black54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const Text(
        'Pix copia e cola',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _codigo,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ),
      const SizedBox(height: 10),
      AuthBotao(
        texto: 'Copiar código',
        secundario: true,
        onPressed: _copiarCodigo,
      ),
      const SizedBox(height: 20),
      const Text(
        'Como pagar',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      _passo('1', 'Abra o app do seu banco e escolha pagar com Pix.'),
      _passo('2', 'Leia o QR Code ou use o Pix copia e cola.'),
      _passo('3', 'Confira o valor e confirme o pagamento.'),
      if (_erro != null) ...[
        const SizedBox(height: 10),
        Text(
          _erro!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      ],
      const SizedBox(height: 22),
      AuthBotao(
        texto: 'Simular pagamento no app do banco',
        onPressed: _simularPagamento,
      ),
    ];
  }

  List<Widget> _telaConfirmando() {
    return [
      const SizedBox(height: 80),
      const Center(child: CircularProgressIndicator()),
      const SizedBox(height: 24),
      const Center(
        child: Text(
          'Identificando seu pagamento...',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Center(
        child: Text(
          'Isso leva só alguns segundos.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ),
    ];
  }

  List<Widget> _telaExpirado() {
    return [
      const SizedBox(height: 40),
      const Center(
        child: Icon(Icons.timer_off_outlined, size: 56, color: Cores.vermelho),
      ),
      const SizedBox(height: 16),
      const Center(
        child: Text(
          'QR Code expirado',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'O prazo para pagar acabou e nenhum valor foi cobrado. '
        'Gere um novo QR Code para continuar.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black54, fontSize: 12),
      ),
      const SizedBox(height: 28),
      AuthBotao(texto: 'Gerar novo QR Code', onPressed: _gerarCobranca),
    ];
  }

  Widget _passo(String numero, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: Cores.azulEscuro,
            child: Text(
              numero,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: Colors.black87, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
