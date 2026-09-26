import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/matricula_service.dart';

/// Cadastro de ESTUDANTE.
///
/// Pede CPF (é a chave primária do usuário no banco — ver Usuario.id)
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
        cpf: _cpfController.text.trim(),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro — Estudante')),
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
                  controller: _matriculaController,
                  decoration: const InputDecoration(
                    labelText: 'Matrícula',
                    border: OutlineInputBorder(),
                    helperText:
                        'Precisa estar liberada pela administração do RU.',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe a matrícula'
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
