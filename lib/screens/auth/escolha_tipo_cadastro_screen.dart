import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Você é estudante da UEMG ou usuário comum do RU?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Estudantes pagam R\$ 4,00 pela refeição; usuários comuns '
                'pagam R\$ 17,00.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.school),
                label: const Text('Sou estudante (tenho matrícula)'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CadastroEstudanteScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.person),
                label: const Text('Sou usuário comum (só CPF)'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CadastroComumScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
