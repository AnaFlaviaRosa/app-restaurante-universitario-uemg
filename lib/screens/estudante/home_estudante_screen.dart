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
///
/// Todas as abas têm cabeçalho verde próprio (com o botão de sair),
/// por isso não há AppBar padrão aqui.
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
      InicioTab(
        usuario: widget.usuario,
        onSair: () => _authService.logout(),
      ),
      ReservaTab(
        usuario: widget.usuario,
        onVoltar: () => setState(() => _abaAtual = 0),
        onSair: () => _authService.logout(),
      ),
      SaldoTab(
        usuario: widget.usuario,
        onVoltar: () => setState(() => _abaAtual = 0),
        onSair: () => _authService.logout(),
      ),
    ];

    return Scaffold(
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