import 'package:flutter/material.dart';
import '../../models/reserva.dart';
import '../../services/admin_service.dart';

/// Admin define quantas marmitas existem hoje para almoço/janta.
/// Essa quantidade é o que controla o botão "Reservar"/"Esgotado"
/// na tela do estudante (ReservaTab).
class DisponibilidadeAdminTab extends StatefulWidget {
  const DisponibilidadeAdminTab({super.key});

  @override
  State<DisponibilidadeAdminTab> createState() =>
      _DisponibilidadeAdminTabState();
}

class _DisponibilidadeAdminTabState extends State<DisponibilidadeAdminTab> {
  final _adminService = AdminService();
  final _almocoController = TextEditingController();
  final _jantaController = TextEditingController();
  bool _salvandoAlmoco = false;
  bool _salvandoJanta = false;

  DateTime get _hoje {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  Future<void> _salvar(TipoRefeicao tipo) async {
    final controller =
        tipo == TipoRefeicao.almoco ? _almocoController : _jantaController;
    final quantidade = int.tryParse(controller.text);
    if (quantidade == null || quantidade < 0) return;

    setState(() {
      if (tipo == TipoRefeicao.almoco) {
        _salvandoAlmoco = true;
      } else {
        _salvandoJanta = true;
      }
    });
    try {
      await _adminService.definirDisponibilidade(
        data: _hoje,
        tipo: tipo,
        quantidadeTotal: quantidade,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quantidade de marmitas atualizada.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _salvandoAlmoco = false;
          _salvandoJanta = false;
        });
      }
    }
  }

  Widget _campoRefeicao(String titulo, TextEditingController controller,
      TipoRefeicao tipo, bool salvando) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantidade total de marmitas hoje',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: salvando ? null : () => _salvar(tipo),
              child: Text(salvando ? 'Salvando...' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _campoRefeicao(
            'Almoço de hoje', _almocoController, TipoRefeicao.almoco, _salvandoAlmoco),
        const SizedBox(height: 16),
        _campoRefeicao(
            'Janta de hoje', _jantaController, TipoRefeicao.janta, _salvandoJanta),
      ],
    );
  }
}
