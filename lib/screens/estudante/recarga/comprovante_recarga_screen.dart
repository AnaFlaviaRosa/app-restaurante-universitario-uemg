import 'package:flutter/material.dart';
import '../../../theme/cores.dart';
import '../../../utils/pagamento.dart';
import '../../../widgets/auth_layout.dart';
import '../../../widgets/pagamento_scaffold.dart';

/// Dados exibidos no comprovante de uma recarga aprovada.
class DadosComprovanteRecarga {
  final double valor;
  final String formaPagamento; // ex.: "Pix" ou "Crédito Visa •••• 4242"
  final String rotuloTransacao; // ex.: "ID da transação (Pix)"
  final String transacaoId;
  final DateTime data;
  final double novoSaldo;

  const DadosComprovanteRecarga({
    required this.valor,
    required this.formaPagamento,
    required this.rotuloTransacao,
    required this.transacaoId,
    required this.data,
    required this.novoSaldo,
  });
}

/// Tela final do fluxo: "Recarga aprovada" + comprovante.
class ComprovanteRecargaScreen extends StatelessWidget {
  final DadosComprovanteRecarga dados;
  const ComprovanteRecargaScreen({super.key, required this.dados});

  @override
  Widget build(BuildContext context) {
    return PagamentoScaffold(
      titulo: 'Comprovante',
      mostrarVoltar: false,
      children: [
        const SizedBox(height: 4),
        const Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: Cores.verdeVivo,
            child: Icon(Icons.check, size: 44, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Recarga aprovada!',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            formatarDinheiro(dados.valor),
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 26),
        _linha('Status', 'Aprovado'),
        _linha('Forma de pagamento', dados.formaPagamento),
        _linha('Data e hora', formatarDataHora(dados.data)),
        _linha(dados.rotuloTransacao, dados.transacaoId, selecionavel: true),
        _linha('Novo saldo disponível', formatarDinheiro(dados.novoSaldo)),
        const SizedBox(height: 26),
        AuthBotao(
          texto: 'Concluir',
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
        ),
        const SizedBox(height: 14),
        const AvisoSimulacao(),
      ],
    );
  }

  Widget _linha(String rotulo, String valor, {bool selecionavel = false}) {
    final estiloValor = const TextStyle(
      color: Colors.black87,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  rotulo,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 5,
                child: selecionavel
                    ? SelectableText(valor,
                        textAlign: TextAlign.right, style: estiloValor)
                    : Text(valor,
                        textAlign: TextAlign.right, style: estiloValor),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
      ],
    );
  }
}
