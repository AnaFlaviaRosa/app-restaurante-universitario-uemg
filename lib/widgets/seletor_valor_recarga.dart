import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/pagamento.dart';

/// Escolha do valor da recarga: botões rápidos (R$ 10, 20, 30, 50) ou
/// um valor digitado. Avisa a tela através de [onChanged] (null quando
/// ainda não há valor).
class SeletorValorRecarga extends StatefulWidget {
  final ValueChanged<double?> onChanged;
  const SeletorValorRecarga({super.key, required this.onChanged});

  @override
  State<SeletorValorRecarga> createState() => _SeletorValorRecargaState();
}

class _SeletorValorRecargaState extends State<SeletorValorRecarga> {
  final _controller = TextEditingController();
  double? _rapido; // valor do botão rápido selecionado
  double? _digitado; // valor digitado no campo

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _escolherRapido(double valor) {
    setState(() {
      _rapido = valor;
      _digitado = null;
      _controller.clear();
    });
    widget.onChanged(valor);
  }

  void _digitar(String texto) {
    final v = double.tryParse(texto.replaceAll(',', '.'));
    setState(() {
      _rapido = null;
      _digitado = v == null ? null : (v * 100).round() / 100;
    });
    widget.onChanged(_digitado);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quanto você quer recarregar?',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final v in valoresRapidosRecarga)
              ChoiceChip(
                label: Text('R\$ ${v.toStringAsFixed(0)}'),
                selected: _rapido == v,
                onSelected: (_) => _escolherRapido(v),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _controller,
          onChanged: _digitar,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
          ],
          decoration: InputDecoration(
            labelText: 'Outro valor',
            prefixText: 'R\$ ',
            border: const OutlineInputBorder(),
            helperText: 'Mínimo ${formatarDinheiro(valorMinimoRecarga)} · '
                'máximo ${formatarDinheiro(valorMaximoRecarga)}',
            errorText: _controller.text.isEmpty
                ? null
                : erroValorRecarga(_digitado),
          ),
        ),
      ],
    );
  }
}
