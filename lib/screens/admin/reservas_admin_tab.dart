import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/reserva.dart';
import '../../models/usuario.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/config_service.dart';
import '../../theme/cores.dart';
import '../../utils/codigo_reserva.dart';
import '../../utils/lista_do_dia.dart';

/// Reservas do dia para o administrador:
///  - resumo (total, vegetarianas, status) e lista com nome, código e
///    opção vegetariana;
///  - marcar retirada / não retirada, e REVERTER um status errado;
///  - "Encerrar refeição": marca como não retiradas as reservas que
///    sobraram depois do fechamento;
///  - "Lista do dia": texto copiável com nome, vegetariana, código e um
///    "[ ]" para marcar (plano B sem aparelho no balcão).
class ReservasAdminTab extends StatefulWidget {
  const ReservasAdminTab({super.key});

  @override
  State<ReservasAdminTab> createState() => _ReservasAdminTabState();
}

class _ReservasAdminTabState extends State<ReservasAdminTab> {
  final _adminService = AdminService();
  final _authService = AuthService();
  final _configService = ConfigService();

  // Cache simples em memória, só para reservas ANTIGAS que não guardaram
  // o nome (as novas já trazem `nome`).
  final Map<String, Usuario> _cacheUsuarios = {};

  Future<Usuario> _buscarUsuarioComCache(String uid) async {
    if (_cacheUsuarios.containsKey(uid)) return _cacheUsuarios[uid]!;
    final usuario = await _authService.buscarUsuarioPorUid(uid);
    _cacheUsuarios[uid] = usuario;
    return usuario;
  }

  DateTime get _hoje {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  String _nomeRefeicao(TipoRefeicao t) =>
      t == TipoRefeicao.janta ? 'Janta' : 'Almoço';

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // ---------- ações ----------

  Future<void> _executar(Future<void> Function() acao) async {
    try {
      await acao();
    } catch (e) {
      debugPrint('ERRO ADMIN RESERVA: $e');
      _aviso('Não foi possível concluir a ação.');
    }
  }

  Future<void> _encerrarRefeicao(TipoRefeicao tipo) async {
    final horarios = await _configService.buscarHorarios();
    final horario = horarios[tipoRefeicaoToString(tipo)]!;
    final antesDoFim = !horario.encerradoEm(DateTime.now());
    final avisoHorario = antesDoFim
        ? 'Ainda não passou do horário de fechamento (${horario.fimHora}h). '
        : '';

    if (!mounted) return;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Encerrar ${_nomeRefeicao(tipo).toLowerCase()}?'),
        content: Text(
          '$avisoHorario'
          'Todas as reservas de hoje desta refeição que ainda estão '
          '"confirmadas" ou "liberadas" serão marcadas como NÃO RETIRADAS. '
          'Não há estorno.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;

    try {
      final n = await _adminService.encerrarRefeicao(_hoje, tipo);
      _aviso(n == 0
          ? 'Nenhuma reserva pendente.'
          : '$n reserva(s) marcada(s) como não retirada.');
    } catch (e) {
      debugPrint('ERRO ENCERRAR: $e');
      _aviso('Não foi possível encerrar a refeição.');
    }
  }

  /// Monta a lista do dia (texto copiável) e abre a janela para copiar.
  /// Reservas antigas sem nome têm o nome buscado no cadastro (só as que
  /// faltarem).
  Future<void> _abrirLista(List<Reserva> reservas) async {
    try {
      final nomes = <String, String>{};
      for (final r in reservas.where((r) => r.nome.isEmpty)) {
        try {
          nomes[r.id] = (await _buscarUsuarioComCache(r.usuarioId)).nome;
        } catch (_) {}
      }
      final textos = {
        for (final t in TipoRefeicao.values)
          t: textoListaDoDia(
            dia: _hoje,
            tipo: t,
            linhas: montarListaDoDia(reservas: reservas, tipo: t, nomes: nomes),
          ),
      };
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _ListaDoDiaDialog(textos: textos),
      );
    } catch (e) {
      debugPrint('ERRO LISTA DO DIA: $e');
      _aviso('Não foi possível gerar a lista.');
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reserva>>(
      stream: _adminService.reservasPorDia(_hoje),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('ERRO RESERVAS ADMIN: ${snapshot.error}');
          return const Center(child: Text('Não foi possível carregar.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reservas = [...snapshot.data!];
        reservas.sort((a, b) {
          final porRefeicao = a.tipoRefeicao.index.compareTo(b.tipoRefeicao.index);
          if (porRefeicao != 0) return porRefeicao;
          return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _resumo(reservas),
            const SizedBox(height: 12),
            if (reservas.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: Text('Nenhuma reserva para hoje.')),
              )
            else
              ...reservas.map(_itemReserva),
          ],
        );
      },
    );
  }

  Widget _resumo(List<Reserva> reservas) {
    int conta(TipoRefeicao t, {bool veg = false}) => reservas
        .where((r) =>
            r.tipoRefeicao == t &&
            r.status != StatusReserva.cancelada &&
            (!veg || r.vegetariana))
        .length;

    Widget linha(TipoRefeicao t) => Text(
          '${_nomeRefeicao(t)}: ${conta(t)} marmitas '
          '(${conta(t, veg: true)} vegetarianas)',
          style: const TextStyle(fontSize: 13),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hoje',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            linha(TipoRefeicao.almoco),
            linha(TipoRefeicao.janta),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      reservas.isEmpty ? null : () => _abrirLista(reservas),
                  icon: const Icon(Icons.copy_all, size: 18),
                  label: const Text('Lista do dia'),
                ),
                PopupMenuButton<TipoRefeicao>(
                  tooltip: 'Encerrar refeição',
                  onSelected: _encerrarRefeicao,
                  itemBuilder: (context) => [
                    for (final t in TipoRefeicao.values)
                      PopupMenuItem(
                        value: t,
                        child: Text('Encerrar ${_nomeRefeicao(t).toLowerCase()}'),
                      ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_outlined, size: 18),
                        SizedBox(width: 6),
                        Text('Encerrar refeição'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _corStatus(StatusReserva s) {
    switch (s) {
      case StatusReserva.confirmada:
        return Colors.orange;
      case StatusReserva.liberada:
        return Cores.azulBorda;
      case StatusReserva.utilizada:
        return Cores.verdeVivo;
      case StatusReserva.naoRetirada:
        return Cores.vermelho;
      case StatusReserva.cancelada:
        return Colors.grey;
    }
  }

  Widget _itemReserva(Reserva r) {
    final pendente = r.status == StatusReserva.confirmada ||
        r.status == StatusReserva.liberada;
    final revertivel = r.status == StatusReserva.utilizada ||
        r.status == StatusReserva.naoRetirada;

    return Card(
      child: ListTile(
        title: r.nome.isNotEmpty
            ? Text(r.nome)
            : FutureBuilder<Usuario>(
                future: _buscarUsuarioComCache(r.usuarioId),
                builder: (context, usuarioSnap) =>
                    Text(usuarioSnap.data?.nome ?? 'Carregando...'),
              ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_nomeRefeicao(r.tipoRefeicao)),
              if (r.codigo.isNotEmpty)
                Text(codigoComEspaco(r.codigo),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              if (r.vegetariana)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Cores.verdeVivo,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('VEGETARIANA',
                      style: TextStyle(color: Colors.white, fontSize: 10)),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _corStatus(r.status),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(statusReservaRotulo(r.status),
                    style:
                        const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ],
          ),
        ),
        trailing: (pendente || revertivel)
            ? PopupMenuButton<String>(
                onSelected: (valor) {
                  switch (valor) {
                    case 'utilizada':
                      _executar(() => _adminService.marcarUtilizada(r.id));
                    case 'naoRetirada':
                      _executar(() => _adminService.marcarNaoRetirada(r.id));
                    case 'liberada':
                      _executar(() => _adminService.reverterStatus(
                          r.id, StatusReserva.liberada));
                    case 'confirmada':
                      _executar(() => _adminService.reverterStatus(
                          r.id, StatusReserva.confirmada));
                  }
                },
                itemBuilder: (context) => pendente
                    ? const [
                        PopupMenuItem(
                            value: 'utilizada',
                            child: Text('Marcar retirada')),
                        PopupMenuItem(
                            value: 'naoRetirada',
                            child: Text('Marcar não retirada')),
                      ]
                    : const [
                        PopupMenuItem(
                            value: 'liberada',
                            child: Text('Reverter para "liberada"')),
                        PopupMenuItem(
                            value: 'confirmada',
                            child: Text('Reverter para "confirmada"')),
                      ],
              )
            : null,
      ),
    );
  }
}

/// Janela com o texto da lista (uma aba por refeição) e botão "Copiar".
class _ListaDoDiaDialog extends StatefulWidget {
  final Map<TipoRefeicao, String> textos;
  const _ListaDoDiaDialog({required this.textos});

  @override
  State<_ListaDoDiaDialog> createState() => _ListaDoDiaDialogState();
}

class _ListaDoDiaDialogState extends State<_ListaDoDiaDialog> {
  TipoRefeicao _tipo = TipoRefeicao.almoco;

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.textos[_tipo]!));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Lista copiada.')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lista do dia'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<TipoRefeicao>(
              segments: const [
                ButtonSegment(
                    value: TipoRefeicao.almoco, label: Text('Almoço')),
                ButtonSegment(
                    value: TipoRefeicao.janta, label: Text('Janta')),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.textos[_tipo]!,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        FilledButton.icon(
          onPressed: _copiar,
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copiar'),
        ),
      ],
    );
  }
}
