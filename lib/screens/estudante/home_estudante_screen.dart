import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import 'inicio_tab.dart';
import 'reserva_tab.dart';
import 'saldo_tab.dart';

/// Tela principal do estudante/usuário comum, com navegação por abas
/// (ver Fluxo A, B e C definidos na Sprint 0.3):
///   Início  -> "vale a pena ir ao RU agora?" (lotação + cardápio)
///   Reservar -> reservar/cancelar marmita
///   Saldo   -> ver saldo, recarregar, histórico
class HomeEstudanteScreen extends StatefulWidget {
  final Usuario usuario;
  const HomeEstudanteScreen({super.key, required this.usuario});

  @override
  State<HomeEstudanteScreen> createState() => _HomeEstudanteScreenState();
}

class _HomeEstudanteScreenState extends State<HomeEstudanteScreen> {
  int _abaAtual = 0;
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final abas = [
      InicioTab(usuario: widget.usuario),
      ReservaTab(usuario: widget.usuario),
      SaldoTab(usuario: widget.usuario),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Olá, ${widget.usuario.nome.split(' ').first}'),
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
          NavigationDestination(icon: Icon(Icons.home), label: 'Início'),
          NavigationDestination(
              icon: Icon(Icons.fastfood), label: 'Reservar'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet), label: 'Saldo'),
        ],
      ),
    );
  }
}
