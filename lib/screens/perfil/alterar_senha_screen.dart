import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/erros_auth.dart';
import '../../widgets/auth_layout.dart';

/// Alterar senha: pede a senha atual (confirmação de identidade exigida
/// pelo Firebase), a nova senha e a confirmação da nova senha.
class AlterarSenhaScreen extends StatefulWidget {
  const AlterarSenhaScreen({super.key});

  @override
  State<AlterarSenhaScreen> createState() => _AlterarSenhaScreenState();
}

class _AlterarSenhaScreenState extends State<AlterarSenhaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _atualController = TextEditingController();
  final _novaController = TextEditingController();
  final _confirmarController = TextEditingController();
  final _authService = AuthService();

  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _atualController.dispose();
    _novaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await _authService.alterarSenha(
        senhaAtual: _atualController.text,
        novaSenha: _novaController.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Senha alterada com sucesso!')),
      );
    } catch (e) {
      debugPrint('ERRO AO ALTERAR SENHA: $e');
      if (mounted) setState(() => _erro = mensagemErroAuth(e));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      titulo: 'Alterar senha',
      mostrarVoltar: true,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Rotulo('Senha atual'),
              AuthCampo(
                controller: _atualController,
                rotulo: 'Senha atual',
                obscureText: true,
                validator: (v) =>
                (v == null || v.isEmpty) ? 'Informe a senha atual' : null,
              ),
              const SizedBox(height: 14),
              const _Rotulo('Nova senha'),
              AuthCampo(
                controller: _novaController,
                rotulo: 'Nova senha (mín. 6 caracteres)',
                obscureText: true,
                validator: (v) {
                  if (v == null || v.length < 6) {
                    return 'A senha precisa ter pelo menos 6 caracteres';
                  }
                  if (v == _atualController.text) {
                    return 'A nova senha deve ser diferente da atual';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const _Rotulo('Confirmar nova senha'),
              AuthCampo(
                controller: _confirmarController,
                rotulo: 'Confirmar nova senha',
                obscureText: true,
                validator: (v) =>
                v != _novaController.text ? 'As senhas não conferem' : null,
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
                texto: 'Salvar nova senha',
                carregando: _carregando,
                onPressed: _salvar,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Rotulo extends StatelessWidget {
  final String texto;
  const _Rotulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6),
      child: Text(
        texto,
        style: const TextStyle(color: Colors.black54, fontSize: 12),
      ),
    );
  }
}