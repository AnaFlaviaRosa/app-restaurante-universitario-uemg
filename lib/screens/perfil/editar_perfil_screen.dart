import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../utils/erros_auth.dart';
import '../../utils/validadores.dart';
import '../../widgets/auth_layout.dart';

/// Editar perfil: nome e e-mail.
///
/// - Trocar o NOME salva direto no documento do usuário.
/// - Trocar o E-MAIL pede a senha atual (exigência de segurança do
///   Firebase) e envia um link de confirmação para o novo endereço. O
///   e-mail de login só muda depois que a pessoa clica no link.
///
/// Ao salvar, devolve o [Usuario] atualizado para a tela anterior.
class EditarPerfilScreen extends StatefulWidget {
  final Usuario usuario;
  const EditarPerfilScreen({super.key, required this.usuario});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _emailController;
  final _authService = AuthService();

  bool _carregando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.usuario.nome);
    _emailController = TextEditingController(text: widget.usuario.email);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<String?> _pedirSenhaAtual() {
    return showDialog<String>(
      context: context,
      builder: (_) => const _DialogoSenhaAtual(),
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final novoNome = _nomeController.text.trim();
    final novoEmail = _emailController.text.trim();
    final mudouNome = novoNome != widget.usuario.nome;
    final mudouEmail =
        novoEmail.toLowerCase() != widget.usuario.email.toLowerCase();

    if (!mudouNome && !mudouEmail) {
      setState(() => _erro = 'Você não alterou nenhum dado.');
      return;
    }

    String? senhaAtual;
    if (mudouEmail) {
      senhaAtual = await _pedirSenhaAtual();
      if (senhaAtual == null || senhaAtual.isEmpty) return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      var usuario = widget.usuario;

      // E-mail primeiro: se a senha estiver errada, nada é salvo.
      if (mudouEmail) {
        await _authService.solicitarAlteracaoEmail(
          senhaAtual: senhaAtual!,
          novoEmail: novoEmail,
        );
      }
      if (mudouNome) {
        usuario = await _authService.atualizarNome(usuario, novoNome);
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, usuario);
      messenger.showSnackBar(SnackBar(
        content: Text(
          mudouEmail
              ? 'Enviamos um link de confirmação para $novoEmail. O e-mail '
              'de login só muda depois que você clicar nele.'
              : 'Perfil atualizado!',
        ),
        duration: Duration(seconds: mudouEmail ? 7 : 3),
      ));
    } catch (e) {
      debugPrint('ERRO AO EDITAR PERFIL: $e');
      if (mounted) setState(() => _erro = mensagemErroAuth(e));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      titulo: 'Editar perfil',
      mostrarVoltar: true,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Rotulo('Nome completo'),
              AuthCampo(
                controller: _nomeController,
                rotulo: 'Nome completo',
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 14),
              const _Rotulo('E-mail'),
              AuthCampo(
                controller: _emailController,
                rotulo: 'E-mail',
                keyboardType: TextInputType.emailAddress,
                ajuda: 'Ao trocar o e-mail, enviaremos um link de '
                    'confirmação para o novo endereço.',
                validator: (v) =>
                (v == null || !emailValido(v)) ? 'E-mail inválido' : null,
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
                texto: 'Salvar',
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

/// Pequeno rótulo acima do campo (o texto do campo some quando a pessoa
/// já preencheu, então o rótulo mantém claro qual campo é qual).
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

/// Pede a senha atual para confirmar a identidade antes de trocar o
/// e-mail. Tem o próprio controller (descartado junto com o diálogo).
class _DialogoSenhaAtual extends StatefulWidget {
  const _DialogoSenhaAtual();

  @override
  State<_DialogoSenhaAtual> createState() => _DialogoSenhaAtualState();
}

class _DialogoSenhaAtualState extends State<_DialogoSenhaAtual> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirme sua senha'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Por segurança, informe sua senha atual para alterar o e-mail.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Senha atual',
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
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}