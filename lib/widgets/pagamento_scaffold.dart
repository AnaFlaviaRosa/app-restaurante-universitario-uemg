import 'package:flutter/material.dart';
import '../theme/cores.dart';

/// Moldura das telas de pagamento: cabeçalho verde com seta de voltar e
/// título + painel branco arredondado (mesmo padrão das abas do app).
class PagamentoScaffold extends StatelessWidget {
  final String titulo;
  final List<Widget> children;
  final bool mostrarVoltar;

  const PagamentoScaffold({
    super.key,
    required this.titulo,
    required this.children,
    this.mostrarVoltar = true,
  });

  @override
  Widget build(BuildContext context) {
    const raio = Radius.circular(42);
    return Scaffold(
      backgroundColor: Cores.verde,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  if (mostrarVoltar)
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      tooltip: 'Voltar',
                      icon: const Icon(Icons.chevron_left,
                          color: Colors.white, size: 27),
                    )
                  else
                    const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      titulo,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: raio, topRight: raio),
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.only(topLeft: raio, topRight: raio),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  children: children,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso discreto de que o pagamento é de mentira.
class AvisoSimulacao extends StatelessWidget {
  final String texto;
  const AvisoSimulacao({
    super.key,
    this.texto = 'Ambiente de simulação: nenhuma cobrança real é feita.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF8A6100)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: Color(0xFF8A6100), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
