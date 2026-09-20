import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../models/movimentacao.dart';
import '../../services/saldo_service.dart';

/// Fluxo C definido pelo grupo: ver saldo e recarregar.
///
/// MVP: a recarga é SIMULADA (não existe PIX/cartão de verdade).
/// O usuário informa um valor e confirma; o saldo é atualizado na hora.
class SaldoTab extends StatefulWidget {
  final Usuario usuario;
  const SaldoTab({super.key, required this.usuario});

  @override
  State<SaldoTab> createState() => _SaldoTabState();
}

class _SaldoTabState extends State<SaldoTab> {
  final _saldoService = SaldoService();
  final _valorController = TextEditingController();
  bool _recarregando = false;

  Future<void> _abrirDialogoRecarga() async {
    _valorController.clear();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recarregar saldo (simulado)'),
        content: TextField(
          controller: _valorController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: 'R\$ ',
            labelText: 'Valor',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final valor = double.tryParse(
                  _valorController.text.replaceAll(',', '.'));
              if (valor == null || valor <= 0) return;
              Navigator.pop(context);
              setState(() => _recarregando = true);
              try {
                await _saldoService.simularRecarga(
                  usuarioId: widget.usuario.id,
                  valor: valor,
                );
              } finally {
                if (mounted) setState(() => _recarregando = false);
              }
            },
            child: const Text('Confirmar pagamento'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StreamBuilder<double>(
          stream: _saldoService.saldoStream(widget.usuario.id),
          builder: (context, snapshot) {
            final saldo = snapshot.data ?? 0;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saldo atual',
                        style: TextStyle(color: Colors.black54)),
                    Text('R\$ ${saldo.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _recarregando ? null : _abrirDialogoRecarga,
                      icon: const Icon(Icons.add),
                      label: Text(_recarregando ? 'Processando...' : 'Recarregar'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const Text('Histórico',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<List<Movimentacao>>(
          stream: _saldoService.historicoStream(widget.usuario.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final movimentacoes = snapshot.data!;
            if (movimentacoes.isEmpty) {
              return const Text('Nenhuma movimentação ainda.');
            }
            return Column(
              children: movimentacoes.map((m) {
                final positivo = m.tipo != TipoMovimentacao.consumo;
                return ListTile(
                  leading: Icon(
                    positivo ? Icons.arrow_upward : Icons.arrow_downward,
                    color: positivo ? Colors.green : Colors.red,
                  ),
                  title: Text(tipoMovimentacaoToStringHelper(m.tipo)),
                  subtitle: Text(
                      '${m.data.day.toString().padLeft(2, '0')}/'
                      '${m.data.month.toString().padLeft(2, '0')} às '
                      '${m.data.hour.toString().padLeft(2, '0')}:'
                      '${m.data.minute.toString().padLeft(2, '0')}'),
                  trailing: Text(
                      '${positivo ? '+' : '-'} R\$ ${m.valor.toStringAsFixed(2)}'),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
