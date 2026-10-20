// ATENÇÃO: este arquivo é um placeholder.
//
// Ele deve ser gerado automaticamente pela ferramenta oficial do
// FlutterFire, depois que vocês criarem o projeto no Firebase Console.
//
// Passo a passo (fazer isso ANTES de rodar o app):
//   1. dart pub global activate flutterfire_cli
//   2. Criar o projeto em https://console.firebase.google.com
//   3. Na raiz do projeto Flutter, rodar:  flutterfire configure
//   4. Selecionar o projeto Firebase criado e as plataformas (Android/iOS)
//   5. O comando vai SOBRESCREVER este arquivo com as chaves reais.
//
// Não subam o firebase_options.dart real (com as chaves) em repositório
// público sem necessidade — para um projeto acadêmico privado no
// GitHub não tem problema, mas é uma boa prática registrar isso.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions não foi configurado para Web. '
        'Rode "flutterfire configure" para gerar as opções corretas.',
      );
    }
    switch (Platform.operatingSystem) {
      case 'android':
        return android;
      case 'ios':
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions não é suportado nesta plataforma. '
          'Rode "flutterfire configure" para gerar as opções corretas.',
        );
    }
  }

  // Valores de EXEMPLO — serão substituídos pelo flutterfire configure.

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA733KsMpx5fO2nqprdLOQ9gyq67hpnFRc',
    appId: '1:303832689754:android:869dbd927ff7860154fc63',
    messagingSenderId: '303832689754',
    projectId: 'ru-uemg',
    storageBucket: 'ru-uemg.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBjlryzabTM7uVDJA7RiQTELUfNfNpy1HE',
    appId: '1:303832689754:ios:c551c87c10646e7554fc63',
    messagingSenderId: '303832689754',
    projectId: 'ru-uemg',
    storageBucket: 'ru-uemg.firebasestorage.app',
    iosBundleId: 'com.uemg.ruapp',
  );
}
