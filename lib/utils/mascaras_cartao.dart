import 'package:flutter/services.dart';
import 'pagamento.dart';

/// Formata o número do cartão enquanto a pessoa digita
/// ("4242424242424242" vira "4242 4242 4242 4242").
class NumeroCartaoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue novo,
  ) {
    final texto = formatarNumeroCartao(novo.text);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Formata a validade enquanto a pessoa digita ("1228" vira "12/28").
class ValidadeCartaoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue novo,
  ) {
    final texto = formatarValidade(novo.text);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
