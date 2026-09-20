import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/lotacao.dart';
import '../../services/lotacao_service.dart';

/// Atualização manual da lotação (decisão do grupo: sem câmera/catraca
/// no MVP). Um funcionário/administrador informa quantas pessoas
/// estão no RU agora.
class LotacaoAdminTab extends StatefulWidget {
  const LotacaoAdminTab({super.key});

  @override
  State<LotacaoAdminTab> createState() => _LotacaoAdminTabState();
}

class _LotacaoAdminTabState extends State<LotacaoAdminTab> {
  final _lotacaoService = LotacaoService();
  final _quantidadeController = TextEditingController();
  final _capacidadeController = TextEditingController(text: '200');
  bool _salvando = false;

  Future<void> _salvar() async {
    final quantidade = int.tryParse(_quantidadeController.text);
    final capacidade = int.tryParse(_capacidadeController.text);
    if (quantidade == null || capacidade == null) return;

    setState(() => _salvando = true);
    try {
      await _lotacaoService.atualizarLotacao(
        quantidadeAtual: quantidade,
        capacidadeMaxima: capacidade,
        adminId: FirebaseAuth.instance.currentUser!.uid,
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
  Widget build(BuildContext context) {
    return StreamBuilder<Lotacao?>(
      stream: _lotacaoService.lotacaoStream(),
      builder: (context, snapshot) {
        final lotacaoAtual = snapshot.data;
        if (lotacaoAtual != null && _quantidadeController.text.isEmpty) {
          _quantidadeController.text = lotacaoAtual.quantidadeAtual.toString();
          _capacidadeController.text = lotacaoAtual.capacidadeMaxima.toString();
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (lotacaoAtual != null)
              Text(
                'Valor atual: ${lotacaoAtual.quantidadeAtual} / '
                '${lotacaoAtual.capacidadeMaxima} — ${lotacaoAtual.statusTexto}',
                style: const TextStyle(color: Colors.black54),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantidadeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pessoas presentes agora',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _capacidadeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Capacidade máxima do RU',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _salvando ? null : _salvar,
              child: Text(_salvando ? 'Salvando...' : 'Atualizar lotação'),
            ),
          ],
        );
      },
    );
  }
}
