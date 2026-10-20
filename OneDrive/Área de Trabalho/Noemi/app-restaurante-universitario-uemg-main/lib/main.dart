import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'models/usuario.dart';
import 'theme/cores.dart';
import 'screens/auth/login_screen.dart';
import 'screens/estudante/home_estudante_screen.dart';
import 'screens/admin/home_admin_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const RUApp());
}

class RUApp extends StatelessWidget {
  const RUApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RU UEMG Passos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(seedColor: Cores.sementeTema),
        scaffoldBackgroundColor: Cores.fundo,
        appBarTheme: const AppBarTheme(
          backgroundColor: Cores.verde,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Cores.barraNavegacao,
          indicatorColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const PortaoDeEntrada(),
    );
  }
}

/// Decide para onde mandar o usuário: tela de login (deslogado),
/// área do estudante ou área do administrador — dependendo do
/// `tipo` salvo no documento `usuarios/{uid}`.
class PortaoDeEntrada extends StatelessWidget {
  const PortaoDeEntrada({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        return FutureBuilder<Usuario>(
          future: authService.buscarUsuarioPorUid(snapshot.data!.uid),
          builder: (context, usuarioSnap) {
            if (usuarioSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (usuarioSnap.hasError || !usuarioSnap.hasData) {
              return const LoginScreen();
            }
            final usuario = usuarioSnap.data!;
            return usuario.isAdmin
                ? HomeAdminScreen(usuario: usuario)
                : HomeEstudanteScreen(usuario: usuario);
          },
        );
      },
    );
  }
}
