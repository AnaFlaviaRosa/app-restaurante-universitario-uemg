import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/usuario.dart';
import '../../../services/saldo_service.dart';
import '../../../theme/cores.dart';
import '../../../utils/mascaras_cartao.dart';
import '../../../utils/pagamento.dart';
import '../../../widgets/auth_layout.dart';
import '../../../widgets/pagamento_scaffold.dart';
import '../../../widgets/seletor_valor_recarga.dart';
import 'comprovante_recarga_screen.dart';

/// Recarga via cartão (simulada), no caminho de um pagamento real:
/// valor -> dados do cartão (com bandeira, validações e prévia do
/// cartão) -> "autorizando com o banco" -> aprovado ou recusado.
///
/// Cartões de teste: qualquer número válido é aprovado, exceto os que
/// terminam em 0002 (recusado) e 9995 (limite insuficiente).
///
/// Segurança: o app NUNCA grava o número completo nem o CVV. No
/// histórico fica só o resumo (ex.: "Crédito Visa •••• 4242").
class RecargaCartaoScreen extends StatefulWidget {
  final Usuario usuario;
  const RecargaCartaoScreen({super.key, required this.usuario});

  @override
  State<RecargaCartaoScreen> createState() => _RecargaCartaoScreenState();
}

class _RecargaCartaoScreenState extends State<RecargaCartaoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numeroController = TextEditingController();
  final _nomeController = TextEditingController();
  final _validadeController = TextEditingController();
  final _cvvController = TextEditingController();
  final _saldoService = SaldoService();

  double? _valor;
  bool _credito = true;
  bool _processando = false;
  String? _erro;

  BandeiraCartao get _bandeira => detectarBandeira(_numeroController.text);

  @override
  void dispose() {
    _numeroController.dispose();
    _nomeController.dispose();
    _validadeController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _pagar() async {
    if (erroValorRecarga(_valor) != null) {
      setState(() => _erro = 'Escolha um valor para a recarga.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final valor = _valor!;
    final numero = apenasDigitos(_numeroController.text);
    final ultimos4 = numero.substring(numero.length - 4);
    final detalhe = '${_credito ? 'Crédito' : 'Débito'} '
        '${nomeBandeira(_bandeira)} •••• $ultimos4';

    setState(() {
      _processando = true;
      _erro = null;
    });

    // Tempo de "autorização com o banco emissor".
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    try {
      final motivo = motivoRecusaSimulada(numero);
      if (motivo != null) {
        await _saldoService.registrarRecargaRecusada(
          usuarioId: widget.usuario.id,
          valor: valor,
          metodo: 'cartao',
          detalhe: detalhe,
        );
        if (!mounted) return;
        setState(() {
          _processando = false;
          _erro = motivo;
        });
        return;
      }

      final agora = DateTime.now();
      final autorizacao = gerarCodigoAutorizacao();
      final novoSaldo = await _saldoService.simularRecarga(
        usuarioId: widget.usuario.id,
        valor: valor,
        metodo: 'cartao',
        transacaoId: autorizacao,
        detalhe: detalhe,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ComprovanteRecargaScreen(
            dados: DadosComprovanteRecarga(
              valor: valor,
              formaPagamento: detalhe,
              rotuloTransacao: 'Código de autorização',
              transacaoId: autorizacao,
              data: agora,
              novoSaldo: novoSaldo,
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('ERRO CARTÃO: $e');
      if (!mounted) return;
      setState(() {
        _processando = false;
        _erro = 'Não foi possível concluir o pagamento. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final valorOk = erroValorRecarga(_valor) == null;
    final bandeira = _bandeira;

    return PagamentoScaffold(
      titulo: 'Recarga via cartão',
      children: [
        const AvisoSimulacao(),
        const SizedBox(height: 22),
        SeletorValorRecarga(onChanged: (v) => setState(() => _valor = v)),
        const SizedBox(height: 26),
        _CartaoPrevia(
          numero: _numeroController.text,
          nome: _nomeController.text,
          validade: _validadeController.text,
          bandeira: bandeira,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Crédito'),
              selected: _credito,
              onSelected: (_) => setState(() => _credito = true),
            ),
            const SizedBox(width: 10),
            ChoiceChip(
              label: const Text('Débito'),
              selected: !_credito,
              onSelected: (_) => setState(() => _credito = false),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _numeroController,
                enabled: !_processando,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  NumeroCartaoFormatter(),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Número do cartão',
                  border: const OutlineInputBorder(),
                  suffixText: bandeira == BandeiraCartao.desconhecida
                      ? null
                      : nomeBandeira(bandeira),
                ),
                validator: (v) {
                  final d = apenasDigitos(v ?? '');
                  if (d.length != tamanhoNumeroCartao(detectarBandeira(d)) ||
                      !luhnValido(d)) {
                    return 'Número de cartão inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nomeController,
                enabled: !_processando,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Nome impresso no cartão',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Informe o nome como está no cartão'
                    : null,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _validadeController,
                      enabled: !_processando,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        ValidadeCartaoFormatter(),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Validade (MM/AA)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          validadeValida(v ?? '', DateTime.now())
                              ? null
                              : 'Validade inválida',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      enabled: !_processando,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v ?? '').length == tamanhoCvv(bandeira)
                              ? null
                              : 'CVV inválido',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 18, color: Cores.vermelho),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _erro!,
                    style:
                        const TextStyle(color: Cores.vermelho, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        AuthBotao(
          texto: valorOk ? 'Pagar ${formatarDinheiro(_valor!)}' : 'Pagar',
          carregando: _processando,
          onPressed: valorOk ? _pagar : null,
        ),
        if (_processando) ...[
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Autorizando com o banco emissor...',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: 18),
        const Text(
          'Modo de teste: use 4242 4242 4242 4242 para aprovar, '
          '4000 0000 0000 0002 para simular recusa e '
          '4000 0000 0000 9995 para limite insuficiente. '
          'Validade futura e CVV com qualquer número.',
          style: TextStyle(color: Colors.black45, fontSize: 11),
        ),
      ],
    );
  }
}

/// Prévia do cartão que vai sendo preenchida enquanto a pessoa digita.
class _CartaoPrevia extends StatelessWidget {
  final String numero;
  final String nome;
  final String validade;
  final BandeiraCartao bandeira;

  const _CartaoPrevia({
    required this.numero,
    required this.nome,
    required this.validade,
    required this.bandeira,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.586, // proporção de um cartão de verdade
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Cores.azulEscuro, Color(0xFF004A66)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.contactless_outlined,
                    color: Colors.white70, size: 28),
                Text(
                  bandeira == BandeiraCartao.desconhecida
                      ? ''
                      : nomeBandeira(bandeira).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            Text(
              numero.isEmpty ? '•••• •••• •••• ••••' : numero,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    nome.trim().isEmpty ? 'NOME DO TITULAR' : nome.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  validade.isEmpty ? 'MM/AA' : validade,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
