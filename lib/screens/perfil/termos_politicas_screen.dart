import 'package:flutter/material.dart';
import '../../widgets/auth_layout.dart';

/// Tela provisória: os termos de uso e a política de privacidade ainda
/// serão elaborados pelo grupo. Quando existirem, basta trocar o texto
/// abaixo (ou carregar de um documento no Firestore).
class TermosPoliticasScreen extends StatelessWidget {
  const TermosPoliticasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthLayout(
      titulo: 'Termos e políticas',
      mostrarVoltar: true,
      children: [
        Text(
          'Os termos de uso e a política de privacidade do RU UEMG '
              'serão publicados aqui em breve.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
      ],
    );
  }
}