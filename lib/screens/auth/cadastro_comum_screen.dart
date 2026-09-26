import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

/// Cadastro de usuário COMUM: só pede CPF (chave primária), sem
/// matrícula. Paga o valor cheio da refeição (R$ 17,00).
class CadastroComumScreen extends StatefulWidget {
  const CadastroComumScreen({super.key});

  @override
  State<CadastroComumScreen> createState() => _CadastroComumScreenState();
}

class _CadastroComumScreenState extends State<CadastroComumScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _authService = AuthService();

  bool _carregando = false;
  String? _erro;

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await _authService.cadastrarComum(
        nome: _nomeController.text.trim(),
        cpf: _cpfController.text.trim(),
        email: _emailController.text.trim(),
        senha: _senhaController.text,
      );
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      final mensagem = e.toString().contains('CpfJaCadastradoException')
          ? 'Já existe uma conta cadastrada com este CPF.'
          : 'Não foi possível cadastrar. Verifique os dados (o e-mail pode '
              'já estar em uso).';
      setState(() => _erro = mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro — Usuário comum')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cpfController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'CPF (só números)',
                    border: OutlineInputBorder(),
                    helperText: 'É o identificador da sua conta no sistema.',
                  ),
                  validator: (v) => (v == null || v.trim().length < 11)
                      ? 'CPF inválido'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _senhaController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha (mín. 6 caracteres)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'A senha precisa ter pelo menos 6 caracteres'
                      : null,
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(_erro!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _carregando ? null : _cadastrar,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: _carregando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Cadastrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
