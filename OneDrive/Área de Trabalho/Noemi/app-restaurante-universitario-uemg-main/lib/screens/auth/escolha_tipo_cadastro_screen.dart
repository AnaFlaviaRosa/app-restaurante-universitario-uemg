import 'package:flutter/material.dart';
import '../../widgets/auth_layout.dart';
import 'cadastro_estudante_screen.dart';
import 'cadastro_comum_screen.dart';

/// Primeira tela do fluxo de cadastro (pedido do grupo): antes de
/// pedir qualquer dado, pergunta se a pessoa é estudante ou usuário
/// comum, porque isso decide:
/// - qual documento será pedido (matrícula ou CPF de fato usado só
///   como confirmação de vínculo — o CPF é pedido dos dois jeitos,
///   pois é a chave primária do usuário no banco);
/// - qual será o valor cobrado na refeição (estudante R$ 4 / comum R$ 17).
class EscolhaTipoCadastroScreen extends StatelessWidget {
  const EscolhaTipoCadastroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      titulo: 'Cadastro',
      mostrarVoltar: true,
      children: [
        const Text(
          'Você é estudante da UEMG ou usuário comum do RU?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Estudantes pagam R\$ 4,00 pela refeição; usuários comuns '
              'pagam R\$ 17,00.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 28),
        AuthBotao(
          texto: 'Sou estudante (tenho matrícula)',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CadastroEstudanteScreen()),
            );
          },
        ),
        const SizedBox(height: 14),
        AuthBotao(
          texto: 'Sou usuário comum (só CPF)',
          secundario: true,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CadastroComumScreen()),
            );
          },
        ),
      ],
    );
  }
}