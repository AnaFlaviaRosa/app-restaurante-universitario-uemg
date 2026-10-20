import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/matricula_service.dart';
import '../../utils/validadores.dart';
import '../../widgets/auth_layout.dart';

/// Cadastro de ESTUDANTE.
///
/// Pede CPF (guardado como campo do usuário — ver Usuario.cpf; a
/// chave primária do documento é o uid do Firebase Auth)q
/// e também a matrícula, que serve só para confirmar o vínculo com a
/// UEMG e, por causa disso, o valor da refeição sai mais barato
/// (R$ 4,00, contra R$ 17,00 do usuário comum).
class CadastroEstudanteScreen extends StatefulWidget {
  const CadastroEstudanteScreen({super.key});

  @override
  State<CadastroEstudanteScreen> createState() =>
      _CadastroEstudanteScreenState();
}

class _CadastroEstudanteScreenState extends State<CadastroEstudanteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _matriculaController = TextEditingController();
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
      await _authService.cadastrarEstudante(
        nome: _nomeController.text.trim(),
        cpf: limparCpf(_cpfController.text),
        matricula: _matriculaController.text.trim(),
        email: _emailController.text.trim(),
        senha: _senhaController.text,
      );
      if (mounted) {
        // Volta para o login (fecha as duas telas de cadastro).
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on MatriculaInvalidaException catch (e) {
      setState(() => _erro = e.message);
    } on MatriculaJaUsadaException catch (e) {
      setState(() => _erro = e.message);
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
      subtitulo: 'Estudante',
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
                controller: _matriculaController,
                rotulo: 'Matrícula',
                ajuda: 'Precisa estar liberada pela administração do RU.',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Informe a matrícula'
                    : null,
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