import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../services/auth_service.dart';
import '../../theme/cores.dart';
import '../../utils/formatadores.dart';
import '../../widgets/auth_layout.dart';
import '../perfil/alterar_senha_screen.dart';
import '../perfil/editar_perfil_screen.dart';
import '../perfil/termos_politicas_screen.dart';

/// Aba "Perfil" do estudante / usuário comum: avatar com as iniciais,
/// nome e e-mail, botão de editar perfil, seção "Minha conta" (alterar
/// senha, notificações), "Privacidade" (termos e políticas) e o botão
/// de sair da conta.
///
/// Visual: cabeçalho verde + painel branco arredondado (mesmo padrão
/// das abas Início e Saldo).
class PerfilTab extends StatefulWidget {
  final Usuario usuario;

  /// Chamado ao tocar na seta do cabeçalho (ex.: voltar para a aba Início).
  final VoidCallback? onVoltar;

  /// Chamado depois que a pessoa confirma que quer sair da conta.
  final VoidCallback? onSair;

  /// Chamado quando nome/e-mail mudam, para a tela principal repassar o
  /// usuário atualizado às outras abas.
  final ValueChanged<Usuario>? onUsuarioAtualizado;

  const PerfilTab({
    super.key,
    required this.usuario,
    this.onVoltar,
    this.onSair,
    this.onUsuarioAtualizado,
  });

  @override
  State<PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<PerfilTab> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _sincronizar();
  }

  /// Se a pessoa confirmou o link de troca de e-mail enquanto o app
  /// estava aberto, o e-mail novo aparece aqui ao abrir a aba.
  Future<void> _sincronizar() async {
    try {
      final atual = await _authService.recarregarUsuario(widget.usuario.id);
      if (!mounted) return;
      if (atual.nome != widget.usuario.nome ||
          atual.email != widget.usuario.email) {
        widget.onUsuarioAtualizado?.call(atual);
      }
    } catch (e) {
      debugPrint('ERRO AO ATUALIZAR PERFIL: $e');
    }
  }

  Future<void> _editarPerfil() async {
    final atualizado = await Navigator.push<Usuario>(
      context,
      MaterialPageRoute(
        builder: (_) => EditarPerfilScreen(usuario: widget.usuario),
      ),
    );
    if (atualizado != null) widget.onUsuarioAtualizado?.call(atualizado);
  }

  void _alterarSenha() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AlterarSenhaScreen()),
    );
  }

  void _notificacoes() {
    // As notificações push ainda não existem no app (exigem Firebase
    // Cloud Messaging). O item já fica na tela para a próxima etapa.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('As notificações serão ativadas em uma próxima versão.'),
      ),
    );
  }

  void _termosEPoliticas() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermosPoliticasScreen()),
    );
  }

  Future<void> _confirmarSair() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Tem certeza de que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Cores.vermelho),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (sair == true) widget.onSair?.call();
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return Container(
      // Verde atrás dos cantos arredondados do painel branco.
      color: Cores.verde,
      child: Column(
        children: [
          _cabecalho(),
          Expanded(child: _painelBranco()),
        ],
      ),
    );
  }

  Widget _cabecalho() {
    return Container(
      color: Cores.verde,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onVoltar,
                  tooltip: 'Voltar',
                  icon: const Icon(Icons.chevron_left,
                      color: Colors.white, size: 27),
                ),
                const Expanded(
                  child: Text(
                    'Meu perfil',
                    style: TextStyle(color: Colors.white, fontSize: 14.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _painelBranco() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(42),
          topRight: Radius.circular(42),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(42),
          topRight: Radius.circular(42),
        ),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          children: [
            _blocoIdentificacao(),
            const SizedBox(height: 22),
            AuthBotao(
              texto: 'Editar perfil',
              secundario: true,
              onPressed: _editarPerfil,
            ),
            const SizedBox(height: 30),
            _tituloSecao('Minha conta'),
            _item(
              icone: Icons.lock_outline,
              rotulo: 'Alterar senha',
              onTap: _alterarSenha,
            ),
            _item(
              icone: Icons.notifications_none_outlined,
              rotulo: 'Ativar notificações',
              onTap: _notificacoes,
            ),
            const SizedBox(height: 26),
            _tituloSecao('Privacidade'),
            _item(
              icone: Icons.description_outlined,
              rotulo: 'Termos e políticas',
              onTap: _termosEPoliticas,
            ),
            const SizedBox(height: 30),
            _botaoSair(),
          ],
        ),
      ),
    );
  }

  Widget _blocoIdentificacao() {
    return Row(
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: const Color(0xFFD9D9D9),
          child: Text(
            iniciaisDoNome(widget.usuario.nome),
            style: const TextStyle(
              color: Color(0xFF3F3F3F),
              fontSize: 28,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.usuario.nome.trim().isEmpty
                    ? 'Usuário'
                    : widget.usuario.nome.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.usuario.email,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tituloSecao(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _item({
    required IconData icone,
    required String rotulo,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Icon(icone, color: Colors.black54, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    rotulo,
                    style:
                    const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black38),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
      ],
    );
  }

  Widget _botaoSair() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: _confirmarSair,
        style: OutlinedButton.styleFrom(
          foregroundColor: Cores.vermelho,
          side: const BorderSide(color: Cores.vermelho, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text('Sair da conta', style: TextStyle(fontSize: 14)),
      ),
    );
  }
}