import 'package:flutter/material.dart';
import '../theme/cores.dart';

/// Cores usadas só nas telas de autenticação (login / cadastro).
class CoresAuth {
  static const campo = Color(0xFF7FBF92); // verde claro dos campos
  static const textoCampo = Color(0xFF0F3D26);
  static const azulLogo = Color(0xFF0A63B8);
  static const azulUemg = Color(0xFF3D6B8E);
}

/// Estrutura visual das telas de login e cadastro: faixa verde no topo
/// e painel branco de cantos arredondados com logo, avatar, título,
/// o conteúdo da tela e o logo da UEMG no rodapé.
class AuthLayout extends StatelessWidget {
  final String titulo;

  /// Texto pequeno abaixo do título (ex.: "Estudante").
  final String? subtitulo;

  /// Mostra a seta de voltar sobre a faixa verde.
  final bool mostrarVoltar;

  final List<Widget> children;

  const AuthLayout({
    super.key,
    required this.titulo,
    required this.children,
    this.subtitulo,
    this.mostrarVoltar = false,
  });

  @override
  Widget build(BuildContext context) {
    final alturaTela = MediaQuery.of(context).size.height;
    final alturaFaixa = (alturaTela * 0.15).clamp(80.0, 140.0);

    return Scaffold(
      backgroundColor: Cores.verde,
      body: Column(
        children: [
          // Faixa verde (com a seta de voltar, quando houver).
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: alturaFaixa,
              width: double.infinity,
              child: Align(
                alignment: Alignment.topLeft,
                child: mostrarVoltar
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 0, 0),
                        child: IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          tooltip: 'Voltar',
                          icon: const Icon(Icons.chevron_left,
                              color: Colors.white, size: 30),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          // Painel branco arredondado.
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(56),
                  topRight: Radius.circular(56),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(56),
                  topRight: Radius.circular(56),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      32,
                      36,
                      32,
                      MediaQuery.of(context).padding.bottom + 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 60,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  const Center(child: AuthLogo()),
                                  const SizedBox(height: 22),
                                  const Center(child: _AvatarAuth()),
                                  const SizedBox(height: 10),
                                  Text(
                                    titulo,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (subtitulo != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        subtitulo!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 22),
                                  ...children,
                                ],
                              ),
                              const SizedBox(height: 32),
                              const AuthRodape(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarAuth extends StatelessWidget {
  const _AvatarAuth();

  @override
  Widget build(BuildContext context) {
    return const CircleAvatar(
      radius: 30,
      backgroundColor: Color(0xFFD0D0D0),
      child: Icon(Icons.person, color: Color(0xFF9E9E9E), size: 46),
    );
  }
}

/// Logo da Amazônia. Usa assets/images/logo_amazonia.png se existir;
/// senão mostra o nome em texto (para o app não quebrar sem o arquivo).
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_amazonia.png',
      height: 28,
      errorBuilder: (context, erro, stack) => const Text(
        'AMAZÔNIA',
        style: TextStyle(
          color: CoresAuth.azulLogo,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Rodapé com o logo da UEMG. Usa assets/images/logo_uemg.png se
/// existir; senão mostra a versão em texto.
class AuthRodape extends StatelessWidget {
  const AuthRodape({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_uemg.png',
      height: 34,
      errorBuilder: (context, erro, stack) => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'UNIVERSIDADE',
                style: TextStyle(
                  color: CoresAuth.azulUemg,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'DO ESTADO DE MINAS GERAIS',
                style: TextStyle(color: CoresAuth.azulUemg, fontSize: 8),
              ),
            ],
          ),
          SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: VerticalDivider(color: Cores.vermelho, thickness: 1.5),
          ),
          SizedBox(width: 4),
          Text(
            'UEMG',
            style: TextStyle(
              color: CoresAuth.azulUemg,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de texto em formato de pílula verde, com o rótulo como
/// placeholder (como no mockup). Mantém validator, teclado etc.
class AuthCampo extends StatelessWidget {
  final TextEditingController controller;
  final String rotulo;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;

  /// Texto de ajuda pequeno abaixo do campo.
  final String? ajuda;

  const AuthCampo({
    super.key,
    required this.controller,
    required this.rotulo,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.ajuda,
  });

  OutlineInputBorder _borda(Color cor, [double largura = 0]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: largura == 0
            ? BorderSide.none
            : BorderSide(color: cor, width: largura),
      );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      cursorColor: Colors.white,
      style: const TextStyle(color: CoresAuth.textoCampo, fontSize: 14),
      decoration: InputDecoration(
        hintText: rotulo,
        hintStyle: const TextStyle(color: Colors.white, fontSize: 13),
        filled: true,
        fillColor: CoresAuth.campo,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        helperText: ajuda,
        helperMaxLines: 2,
        helperStyle: const TextStyle(color: Colors.black45, fontSize: 11),
        errorMaxLines: 2,
        border: _borda(Colors.transparent),
        enabledBorder: _borda(Colors.transparent),
        focusedBorder: _borda(Cores.azulEscuro, 1.5),
        errorBorder: _borda(Cores.vermelho, 1.5),
        focusedErrorBorder: _borda(Cores.vermelho, 1.5),
      ),
    );
  }
}

/// Botão azul arredondado das telas de autenticação.
class AuthBotao extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool carregando;

  /// Versão com contorno (ação secundária).
  final bool secundario;

  const AuthBotao({
    super.key,
    required this.texto,
    required this.onPressed,
    this.carregando = false,
    this.secundario = false,
  });

  @override
  Widget build(BuildContext context) {
    final forma =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    final conteudo = carregando
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: secundario ? Cores.azulEscuro : Colors.white,
            ),
          )
        : Text(texto, style: const TextStyle(fontSize: 14));

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: secundario
          ? OutlinedButton(
              onPressed: carregando ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: Cores.azulEscuro,
                side: const BorderSide(color: Cores.azulEscuro, width: 1.5),
                shape: forma,
              ),
              child: conteudo,
            )
          : FilledButton(
              onPressed: carregando ? null : onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: Cores.azulEscuro,
                foregroundColor: Colors.white,
                shape: forma,
              ),
              child: conteudo,
            ),
    );
  }
}
