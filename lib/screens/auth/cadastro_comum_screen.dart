import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/validadores.dart';
import '../../widgets/auth_layout.dart';

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
        cpf: limparCpf(_cpfController.text),
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
    return AuthLayout(
      titulo: 'Cadastro',
      subtitulo: 'Usuário comum',
      mostrarVoltar: true,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthCampo(
                controller: _nomeController,
                rotulo: 'Nome Completo',
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 14),
              AuthCampo(
                controller: _cpfController,
                rotulo: 'CPF (só números)',
                keyboardType: TextInputType.number,
                ajuda: 'É o identificador da sua conta no sistema.',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o CPF';
                  if (!validarCpf(v)) return 'CPF inválido';
                  return null;
                },
              ),
              const SizedBox(height: 14),
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
                rotulo: 'Senha (mín. 6 caracteres)',
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
                texto: 'Cadastrar',
                carregando: _carregando,
                onPressed: _cadastrar,
              ),
            ],
          ),
        ),
      ],
    );
  }
}