import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import 'lotacao_admin_tab.dart';
import 'disponibilidade_admin_tab.dart';
import 'reservas_admin_tab.dart';
import 'configuracoes_admin_tab.dart';

/// Fluxo D definido pelo grupo: administração do RU.
/// Só é exibida para usuários com tipo == admin (ver PortaoDeEntrada
/// em main.dart e as regras de segurança em firestore.rules).
class HomeAdminScreen extends StatefulWidget {
  final Usuario usuario;
  const HomeAdminScreen({super.key, required this.usuario});

  @override
  State<HomeAdminScreen> createState() => _HomeAdminScreenState();
}

class _HomeAdminScreenState extends State<HomeAdminScreen> {
  int _abaAtual = 0;
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final abas = [
      const LotacaoAdminTab(),
      const DisponibilidadeAdminTab(),
      const ReservasAdminTab(),
      const ConfiguracoesAdminTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administração do RU'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => _authService.logout(),
          ),
        ],
      ),
      body: abas[_abaAtual],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _abaAtual,
        onDestinationSelected: (i) => setState(() => _abaAtual = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.groups), label: 'Lotação'),
          NavigationDestination(
              icon: Icon(Icons.set_meal), label: 'Marmitas'),
          NavigationDestination(
              icon: Icon(Icons.list_alt), label: 'Reservas'),
          NavigationDestination(
              icon: Icon(Icons.settings), label: 'Config.'),
        ],
      ),
    );
  }
}
