import 'package:flutter/material.dart';
import '../../models/reserva.dart';
import '../../models/usuario.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';

/// Lista as reservas do dia para o administrador acompanhar quem
/// retirou (`utilizada`) ou não retirou (`naoRetirada`) a marmita.
class ReservasAdminTab extends StatefulWidget {
  const ReservasAdminTab({super.key});

  @override
  State<ReservasAdminTab> createState() => _ReservasAdminTabState();
}

class _ReservasAdminTabState extends State<ReservasAdminTab> {
  final _adminService = AdminService();
  final _authService = AuthService();

  // Cache simples em memória: evita buscar o mesmo usuário de novo a
  // cada rebuild da lista (ela já atualiza sozinha via StreamBuilder).
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reserva>>(
      stream: _adminService.reservasPorDia(_hoje),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reservas = snapshot.data!;
        if (reservas.isEmpty) {
          return const Center(child: Text('Nenhuma reserva para hoje.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reservas.length,
          itemBuilder: (context, i) {
            final r = reservas[i];
            return Card(
              child: ListTile(
                title: FutureBuilder<Usuario>(
                  future: _buscarUsuarioComCache(r.usuarioId),
                  builder: (context, usuarioSnap) {
                    final nome = usuarioSnap.data?.nome ?? 'Carregando...';
                    return Text(
                        '${tipoRefeicaoToString(r.tipoRefeicao) == 'almoco' ? 'Almoço' : 'Janta'} '
                            '— $nome');
                  },
                ),
                subtitle: Text('Status: ${statusReservaToString(r.status)}'),
                trailing: r.status == StatusReserva.confirmada
                    ? PopupMenuButton<String>(
                  onSelected: (valor) {
                    if (valor == 'utilizada') {
                      _adminService.marcarUtilizada(r.id);
                    } else if (valor == 'naoRetirada') {
                      _adminService.marcarNaoRetirada(r.id);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                        value: 'utilizada', child: Text('Marcar retirada')),
                    PopupMenuItem(
                        value: 'naoRetirada',
                        child: Text('Marcar não retirada')),
                  ],
                )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}