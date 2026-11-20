import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/aviso.dart';
import '../../services/admin_service.dart';
import '../../services/aviso_service.dart';
import '../../services/config_service.dart';
import '../../theme/cores.dart';
import '../../utils/datas.dart';

/// Quadro de avisos do admin:
///  - botão "RU fechado hoje" (bloqueia reservas, zera as marmitas,
///    estorna as reservas confirmadas e publica um aviso importante);
///  - publicação de avisos com validade;
///  - lista dos avisos ativos, com opção de apagar.
class AvisosAdminTab extends StatefulWidget {
  const AvisosAdminTab({super.key});

  @override
  State<AvisosAdminTab> createState() => _AvisosAdminTabState();
}

class _AvisosAdminTabState extends State<AvisosAdminTab> {
  final _avisoService = AvisoService();
  final _adminService = AdminService();
  final _configService = ConfigService();

  final _tituloController = TextEditingController();
  final _mensagemController = TextEditingController();
  final _motivoController = TextEditingController();

  bool _importante = false;
  bool _publicando = false;
  bool _fechando = false;
  int _validadeIndice = 0;

  static const _validades = ['Até o fim de hoje', '24 horas', '3 dias', '7 dias'];

  @override
  void dispose() {
    _tituloController.dispose();
    _mensagemController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  DateTime get _hoje {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  Duration _duracaoValidade() {
    switch (_validadeIndice) {
      case 1:
        return const Duration(hours: 24);
      case 2:
        return const Duration(days: 3);
      case 3:
        return const Duration(days: 7);
      case 0:
      default:
        final agora = DateTime.now();
        final fimDoDia = DateTime(agora.year, agora.month, agora.day, 23, 59);
        final d = fimDoDia.difference(agora);
        // Se for quase meia-noite, garante pelo menos 1 hora no ar.
        return d < const Duration(hours: 1) ? const Duration(hours: 1) : d;
    }
  }

  void _msg(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _publicar() async {
    final titulo = _tituloController.text.trim();
    final mensagem = _mensagemController.text.trim();
    if (titulo.isEmpty || mensagem.isEmpty) {
      _msg('Preencha o título e a mensagem.');
      return;
    }
    if (titulo.length > 80 || mensagem.length > 500) {
      _msg('Título: até 80 caracteres. Mensagem: até 500.');
      return;
    }
    setState(() => _publicando = true);
    try {
      await _avisoService.publicar(
        titulo: titulo,
        mensagem: mensagem,
        importante: _importante,
        validade: _duracaoValidade(),
        adminId: FirebaseAuth.instance.currentUser!.uid,
      );
      _tituloController.clear();
      _mensagemController.clear();
      setState(() => _importante = false);
      _msg('Aviso publicado.');
    } catch (e) {
      debugPrint('ERRO PUBLICAR AVISO: $e');
      _msg('Não foi possível publicar o aviso.');
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  Future<void> _fecharRu() async {
    final motivo = _motivoController.text.trim();
    if (motivo.length > 200) {
      _msg('O motivo pode ter até 200 caracteres.');
      return;
    }
    setState(() => _fechando = true);
    try {
      final n = await _adminService.contarReservasParaEstorno(_hoje);
      if (!mounted) return;
      final confirmou = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Fechar o RU hoje?'),
          content: Text(
            'Isto vai:\n'
            '• bloquear novas reservas de hoje;\n'
            '• zerar a quantidade de marmitas de hoje;\n'
            '• publicar um aviso importante para todos;\n'
            '• CANCELAR e ESTORNAR $n reserva(s) confirmada(s) de hoje.\n\n'
            'Reservas já liberadas na catraca ou retiradas não são alteradas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Cores.vermelho),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Fechar o RU'),
            ),
          ],
        ),
      );
      if (confirmou != true) return;

      final estornadas = await _adminService.fecharRuHoje(
        data: _hoje,
        motivo: motivo,
        adminId: FirebaseAuth.instance.currentUser!.uid,
      );
      _motivoController.clear();
      _msg('RU fechado. $estornadas reserva(s) estornada(s).');
    } catch (e) {
      debugPrint('ERRO FECHAR RU: $e');
      _msg('Não foi possível fechar o RU. Se parou no meio, aperte de '
          'novo: só as reservas ainda confirmadas são processadas.');
    } finally {
      if (mounted) setState(() => _fechando = false);
    }
  }

  Future<void> _reabrirRu() async {
    try {
      await _adminService.reabrirRu(_hoje);
      _msg('RU reaberto. Defina a quantidade de marmitas na aba Marmitas.');
    } catch (e) {
      debugPrint('ERRO REABRIR RU: $e');
      _msg('Não foi possível reabrir o RU.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _cartaoRuFechado(),
        const SizedBox(height: 16),
        _cartaoNovoAviso(),
        const SizedBox(height: 16),
        _cartaoAvisosAtivos(),
      ],
    );
  }

  Widget _cartaoRuFechado() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<StatusRu>(
          stream: _configService.statusRuStream(),
          builder: (context, snapshot) {
            final status = snapshot.data ?? StatusRu();
            final fechado = status.fechadoEmDia(_hoje);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RU fechado hoje',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (fechado) ...[
                  Text(
                    status.motivo.isEmpty
                        ? 'O RU está marcado como FECHADO hoje.'
                        : 'FECHADO hoje: ${status.motivo}',
                    style: const TextStyle(color: Cores.vermelho),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _reabrirRu,
                    child: const Text('Reabrir o RU'),
                  ),
                ] else ...[
                  const Text(
                    'Para dias em que o RU não abrirá. Bloqueia reservas, '
                    'zera as marmitas, estorna as reservas confirmadas e '
                    'avisa todo mundo.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _motivoController,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Motivo (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Cores.vermelho),
                    onPressed: _fechando ? null : _fecharRu,
                    icon: const Icon(Icons.block),
                    label: Text(_fechando ? 'Fechando...' : 'RU fechado hoje'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _cartaoNovoAviso() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Novo aviso',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _tituloController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mensagemController,
              maxLength: 500,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Mensagem',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Importante (destaque na tela inicial)'),
              value: _importante,
              onChanged: (v) => setState(() => _importante = v),
            ),
            DropdownButtonFormField<int>(
              value: _validadeIndice,
              decoration: const InputDecoration(
                labelText: 'Fica no ar',
                border: OutlineInputBorder(),
              ),
              items: [
                for (var i = 0; i < _validades.length; i++)
                  DropdownMenuItem(value: i, child: Text(_validades[i])),
              ],
              onChanged: (v) => setState(() => _validadeIndice = v ?? 0),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _publicando ? null : _publicar,
              child: Text(_publicando ? 'Publicando...' : 'Publicar aviso'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartaoAvisosAtivos() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Avisos no ar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<List<Aviso>>(
              stream: _avisoService.avisosAtivosStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('ERRO AVISOS ADMIN: ${snapshot.error}');
                  return const Text('Não foi possível carregar os avisos.');
                }
                final avisos = snapshot.data;
                if (avisos == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (avisos.isEmpty) {
                  return const Text('Nenhum aviso no ar.');
                }
                return Column(
                  children: [
                    for (final a in avisos)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          a.importante
                              ? Icons.priority_high
                              : Icons.info_outline,
                          color: a.importante ? Cores.vermelho : Colors.grey,
                        ),
                        title: Text(a.titulo),
                        subtitle: Text(
                            '${a.mensagem}\nAté ${diaMesHora(a.expiraEm)}'),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Apagar aviso',
                          onPressed: () => _avisoService.remover(a.id),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
