import 'package:flutter/material.dart';
import '../models/aviso.dart';
import '../theme/cores.dart';
import '../utils/datas.dart';

/// Quadro de avisos exibido na tela inicial do usuário.
/// Avisos importantes viram um banner em destaque; os demais, uma
/// lista simples. Se não há avisos, não ocupa espaço.
class QuadroAvisos extends StatelessWidget {
  final List<Aviso> avisos;
  const QuadroAvisos({super.key, required this.avisos});

  @override
  Widget build(BuildContext context) {
    if (avisos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final a in avisos) _cartao(a),
      ],
    );
  }

  Widget _cartao(Aviso a) {
    final cor = a.importante ? Cores.vermelho : Cores.azulEscuro;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: a.importante ? const Color(0xFFFDECEC) : const Color(0xFFEAF4F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(a.importante ? Icons.campaign : Icons.info_outline, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.titulo,
                    style: TextStyle(
                        color: cor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5)),
                const SizedBox(height: 4),
                Text(a.mensagem,
                    style:
                        const TextStyle(color: Colors.black87, fontSize: 12.5)),
                const SizedBox(height: 4),
                Text(diaMesHora(a.criadoEm),
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
