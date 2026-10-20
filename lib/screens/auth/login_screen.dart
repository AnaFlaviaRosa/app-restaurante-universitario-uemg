import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_layout.dart';
import 'escolha_tipo_cadastro_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _authService = AuthService();

  bool _carregando = false;
  String? _erro;

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await _authService.login(
        email: _emailController.text.trim(),
        senha: _senhaController.text,
      );
      // Navegação automática: o PortaoDeEntrada (main.dart) escuta o
      // authStateChanges e troca de tela sozinho quando o login funciona.
    } catch (e) {
      setState(() => _erro = 'E-mail ou senha inválidos.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrirDialogoRedefinirSenha() async {
    final controller = TextEditingController(text: _emailController.text);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redefinir senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informe o e-mail da sua conta. Se ele estiver '
                  'cadastrado, enviaremos um link para você criar uma '
                  'nova senha.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty || !mounted) return;

    await _authService.enviarRedefinicaoSenha(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
        'Se esse e-mail estiver cadastrado, você vai receber um '
            'link para redefinir a senha em instantes.',
      ),
      duration: Duration(seconds: 5),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      titulo: 'Login',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthCampo(
                controller: _emailController,
                rotulo: 'Email',
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
              ),
              const SizedBox(height: 14),
              AuthCampo(
                controller: _senhaController,
                rotulo: 'Senha',
                obscureText: true,
                validator: (v) => (v == null || v.length < 6)
                    ? 'A senha precisa ter pelo menos 6 caracteres'
                    : null,
              ),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(
                  _erro!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 26),
              AuthBotao(
                texto: 'Entrar',
                carregando: _carregando,
                onPressed: _entrar,
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EscolhaTipoCadastroScreen()),
                  );
                },
                icon: const Icon(Icons.person_outline,
                    size: 18, color: Colors.black87),
                label: const Text(
                  'Cadastrar',
                  style: TextStyle(color: Colors.black87, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: _abrirDialogoRedefinirSenha,
                child: const Text(
                  'Esqueci minha senha',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}