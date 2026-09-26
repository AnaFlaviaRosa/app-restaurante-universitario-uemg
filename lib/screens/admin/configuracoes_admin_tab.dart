import 'package:flutter/material.dart';
import '../../services/matricula_service.dart';
import '../../services/preco_service.dart';

/// Nova aba do admin, necessária para o fluxo de cadastro funcionar:
/// - Liberar matrículas válidas (sem isso, nenhum estudante consegue
///   se cadastrar, porque o cadastro exige uma matrícula já cadastrada
///   aqui — ver MatriculaService).
/// - Editar os valores da refeição por tipo de usuário (padrão:
///   estudante R$ 4,00 / comum R$ 17,00 — ver PrecoService).
class ConfiguracoesAdminTab extends StatefulWidget {
  const ConfiguracoesAdminTab({super.key});

  @override
  State<ConfiguracoesAdminTab> createState() => _ConfiguracoesAdminTabState();
}

class _ConfiguracoesAdminTabState extends State<ConfiguracoesAdminTab> {
  final _matriculaService = MatriculaService();
  final _precoService = PrecoService();

  final _matriculaController = TextEditingController();
  final _precoEstudanteController = TextEditingController();
  final _precoComumController = TextEditingController();

  bool _liberando = false;
  bool _salvandoPrecos = false;

  Future<void> _liberarMatricula() async {
    final matricula = _matriculaController.text.trim();
    if (matricula.isEmpty) return;
    setState(() => _liberando = true);
    try {
      await _matriculaService.liberarMatricula(matricula);
      _matriculaController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Matrícula liberada para cadastro.')),
        );
      }
    } finally {
      if (mounted) setState(() => _liberando = false);
    }
  }

  Future<void> _salvarPrecos() async {
    final precoEstudante =
        double.tryParse(_precoEstudanteController.text.replaceAll(',', '.'));
    final precoComum =
        double.tryParse(_precoComumController.text.replaceAll(',', '.'));
    if (precoEstudante == null || precoComum == null) return;

    setState(() => _salvandoPrecos = true);
    try {
      await _precoService.salvarPrecos(
        precoEstudante: precoEstudante,
        precoComum: precoComum,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preços atualizados.')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvandoPrecos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Liberar matrícula de estudante',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Um estudante só consegue se cadastrar se a matrícula '
                  'dele estiver liberada aqui.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _matriculaController,
                  decoration: const InputDecoration(
                    labelText: 'Matrícula',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _liberando ? null : _liberarMatricula,
                  child: Text(_liberando ? 'Liberando...' : 'Liberar matrícula'),
                ),
                const SizedBox(height: 12),
                const Divider(),
                const Text('Matrículas já liberadas:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                StreamBuilder<List<String>>(
                  stream: _matriculaService.matriculasLiberadasStream(),
                  builder: (context, snapshot) {
                    final matriculas = snapshot.data ?? [];
                    if (matriculas.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Nenhuma matrícula liberada ainda.'),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: matriculas
                          .map((m) => Chip(label: Text(m)))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Valor da refeição por tipo de usuário',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                StreamBuilder<Map<TipoUsuarioPreco, double>>(
                  stream: _precoService.precosStream(),
                  builder: (context, snapshot) {
                    final precos = snapshot.data;
                    if (precos != null &&
                        _precoEstudanteController.text.isEmpty) {
                      _precoEstudanteController.text =
                          precos[TipoUsuarioPreco.estudante]!.toStringAsFixed(2);
                      _precoComumController.text =
                          precos[TipoUsuarioPreco.comum]!.toStringAsFixed(2);
                    }
                    return Column(
                      children: [
                        TextField(
                          controller: _precoEstudanteController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            prefixText: 'R\$ ',
                            labelText: 'Preço — estudante',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _precoComumController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            prefixText: 'R\$ ',
                            labelText: 'Preço — comum',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _salvandoPrecos ? null : _salvarPrecos,
                  child: Text(_salvandoPrecos ? 'Salvando...' : 'Salvar preços'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
