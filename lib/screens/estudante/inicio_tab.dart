import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../models/lotacao.dart';
import '../../services/lotacao_service.dart';

/// Fluxo A definido pelo grupo: "descobrir se vale a pena ir ao RU agora".
/// Mostra a lotação atual (atualizada manualmente pelo administrador
/// no MVP — ver decisão sobre reconhecimento facial/câmeras).
class InicioTab extends StatelessWidget {
  final Usuario usuario;
  const InicioTab({super.key, required this.usuario});

  Color _corStatus(String status) {
    switch (status) {
      case 'Baixo movimento':
        return Colors.green;
      case 'Médio movimento':
        return Colors.orange;
      case 'Alta ocupação':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lotacaoService = LotacaoService();

    return StreamBuilder<Lotacao?>(
      stream: lotacaoService.lotacaoStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final lotacao = snapshot.data;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: lotacao == null
                  ? Colors.grey.shade200
                  : _corStatus(lotacao.statusTexto).withOpacity(0.12),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lotação do RU agora',
                        style: TextStyle(fontSize: 16, color: Colors.black54)),
                    const SizedBox(height: 8),
                    if (lotacao == null)
                      const Text('Ainda sem informação de lotação.')
                    else ...[
                      Text(
                        '${lotacao.quantidadeAtual} / ${lotacao.capacidadeMaxima} pessoas',
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.circle,
                              size: 12, color: _corStatus(lotacao.statusTexto)),
                          const SizedBox(width: 6),
                          Text(lotacao.statusTexto,
                              style: TextStyle(
                                  color: _corStatus(lotacao.statusTexto),
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Atualizado às '
                        '${lotacao.atualizadoEm.hour.toString().padLeft(2, '0')}:'
                        '${lotacao.atualizadoEm.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.black45, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Use essa informação junto com sua rotina para decidir a '
              'melhor hora de ir ao RU. Se estiver cheio, considere '
              'reservar sua marmita para não perder tempo na fila.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        );
      },
    );
  }
}
