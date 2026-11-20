import 'package:flutter/material.dart';
import '../../services/config_service.dart';
import '../../services/matricula_service.dart';
import '../../services/preco_service.dart';

/// Nova aba do admin, necessária para o fluxo de cadastro funcionar:
/// - Liberar matrículas válidas (sem isso, nenhum estudante consegue
///   se cadastrar, porque o cadastro exige uma matrícula já cadastrada
///   aqui — ver MatriculaService).
/// - Editar os valores da refeição por tipo de usuário (padrão:
///   estudante R$ 4,00 / comum R$ 17,00 — ver PrecoService).
/// - Editar os horários das refeições (abertura e fechamento).
/// - Ligar/desligar a integração da catraca (ver ConfigService).
class ConfiguracoesAdminTab extends StatefulWidget {
  const ConfiguracoesAdminTab({super.key});

  @override
  State<ConfiguracoesAdminTab> createState() => _ConfiguracoesAdminTabState();
}

class _ConfiguracoesAdminTabState extends State<ConfiguracoesAdminTab> {
  final _matriculaService = MatriculaService();
  final _precoService = PrecoService();
  final _configService = ConfigService();

  final _almocoInicioController = TextEditingController();
  final _almocoFimController = TextEditingController();
  final _jantaInicioController = TextEditingController();
  final _jantaFimController = TextEditingController();
  bool _horariosCarregados = false;
  bool _salvandoHorarios = false;

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
      _mensagem('Matrícula liberada para cadastro.');
    } catch (e) {
      debugPrint('ERRO LIBERAR MATRÍCULA: $e');
      _mensagem('Não foi possível liberar a matrícula.');
    } finally {
      if (mounted) setState(() => _liberando = false);
    }
  }

  Future<void> _salvarPrecos() async {
    final precoEstudante =
        double.tryParse(_precoEstudanteController.text.replaceAll(',', '.'));
    final precoComum =
        double.tryParse(_precoComumController.text.replaceAll(',', '.'));
    final invalido = precoEstudante == null ||
        precoComum == null ||
        precoEstudante <= 0 ||
        precoComum <= 0 ||
        precoEstudante > 1000 ||
        precoComum > 1000;
    if (invalido) {
      _mensagem('Informe preços maiores que zero (e até R\$ 1000).');
      return;
    }

    setState(() => _salvandoPrecos = true);
    try {
      await _precoService.salvarPrecos(
        precoEstudante: precoEstudante,
        precoComum: precoComum,
      );
      _mensagem('Preços atualizados.');
    } catch (e) {
      debugPrint('ERRO SALVAR PREÇOS: $e');
      _mensagem('Não foi possível salvar os preços.');
    } finally {
      if (mounted) setState(() => _salvandoPrecos = false);
    }
  }

  void _mensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _salvarHorarios() async {
    final ai = int.tryParse(_almocoInicioController.text.trim());
    final af = int.tryParse(_almocoFimController.text.trim());
    final ji = int.tryParse(_jantaInicioController.text.trim());
    final jf = int.tryParse(_jantaFimController.text.trim());
    if (ai == null || af == null || ji == null || jf == null) {
      _mensagem('Informe as quatro horas (números de 0 a 23).');
      return;
    }
    final erro = ConfigService.validarHorarios(
      almocoInicio: ai,
      almocoFim: af,
      jantaInicio: ji,
      jantaFim: jf,
    );
    if (erro != null) {
      _mensagem(erro);
      return;
    }
    setState(() => _salvandoHorarios = true);
    try {
      await _configService.salvarHorarios(
        almocoInicio: ai,
        almocoFim: af,
        jantaInicio: ji,
        jantaFim: jf,
      );
      _mensagem('Horários atualizados.');
    } catch (e) {
      debugPrint('ERRO SALVAR HORÁRIOS: $e');
      _mensagem('Não foi possível salvar os horários.');
    } finally {
      if (mounted) setState(() => _salvandoHorarios = false);
    }
  }

  Widget _campoHora(TextEditingController c, String rotulo) {
    return Expanded(
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: rotulo,
          suffixText: 'h',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _cartaoHorarios() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Horários das refeições',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Reservas fecham na abertura; o cancelamento fecha 1 h antes '
              'da abertura; o fechamento define até quando a retirada vale.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            StreamBuilder<Map<String, HorarioRefeicao>>(
              stream: _configService.horariosStream(),
              builder: (context, snapshot) {
                final h = snapshot.data;
                if (h != null && !_horariosCarregados) {
                  _horariosCarregados = true;
                  _almocoInicioController.text = '${h['almoco']!.inicioHora}';
                  _almocoFimController.text = '${h['almoco']!.fimHora}';
                  _jantaInicioController.text = '${h['janta']!.inicioHora}';
                  _jantaFimController.text = '${h['janta']!.fimHora}';
                }
                return Column(
                  children: [
                    Row(children: [
                      _campoHora(_almocoInicioController, 'Almoço abre'),
                      const SizedBox(width: 12),
                      _campoHora(_almocoFimController, 'Almoço fecha'),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      _campoHora(_jantaInicioController, 'Janta abre'),
                      const SizedBox(width: 12),
                      _campoHora(_jantaFimController, 'Janta fecha'),
                    ]),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _salvandoHorarios ? null : _salvarHorarios,
              child:
                  Text(_salvandoHorarios ? 'Salvando...' : 'Salvar horários'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartaoIntegracaoCatraca() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: StreamBuilder<bool>(
          stream: _configService.integracaoCatracaStream(),
          builder: (context, snapshot) {
            final ativa = snapshot.data ?? false;
            return SwitchListTile(
              title: const Text('Integração da catraca ativa',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                ativa
                    ? 'LIGADA: o protocolo só abre depois que a catraca '
                        'liberar a reserva. Se a ponte da catraca cair, '
                        'DESLIGUE para os alunos poderem retirar pela reserva.'
                    : 'DESLIGADA: o protocolo abre direto da reserva '
                        'confirmada, dentro do horário da refeição. Ligue '
                        'só quando a ponte da catraca estiver funcionando.',
                style: const TextStyle(fontSize: 12),
              ),
              value: ativa,
              onChanged: (v) => _configService
                  .definirIntegracaoCatraca(v)
                  .catchError((Object e) {
                debugPrint('ERRO INTEGRAÇÃO: $e');
                _mensagem('Não foi possível alterar.');
              }),
            );
          },
        ),
      ),
    );
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
        const SizedBox(height: 16),
        _cartaoHorarios(),
        const SizedBox(height: 16),
        _cartaoIntegracaoCatraca(),
      ],
    );
  }
}
