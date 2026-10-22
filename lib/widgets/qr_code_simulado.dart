import 'package:flutter/material.dart';

/// Desenha algo com cara de QR Code (os três quadrados de canto + módulos
/// pretos e brancos) a partir do texto recebido.
///
/// ATENÇÃO: é só visual. Não é um QR Code de verdade e nenhum leitor vai
/// conseguir ler. Para um QR real, o caminho é o pacote `qr_flutter`.
class QrCodeSimulado extends StatelessWidget {
  final String dados;
  final double tamanho;
  const QrCodeSimulado({super.key, required this.dados, this.tamanho = 220});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: CustomPaint(painter: _QrPainter(dados)),
    );
  }
}

class _QrPainter extends CustomPainter {
  static const int _n = 33; // módulos por lado
  final String dados;
  _QrPainter(this.dados);

  // Gerador pseudoaleatório determinístico (Park-Miller): o mesmo texto
  // sempre desenha o mesmo "QR Code".
  static int _semente(String s) {
    var h = 2166136261;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    return h % 2147483646 + 1;
  }

  bool _areaReservada(int x, int y) =>
      (x <= 7 && y <= 7) || (x >= _n - 8 && y <= 7) || (x <= 7 && y >= _n - 8);

  bool _pixelDeCanto(int x, int y) {
    const origens = [
      [0, 0],
      [_n - 7, 0],
      [0, _n - 7],
    ];
    for (final o in origens) {
      final lx = x - o[0];
      final ly = y - o[1];
      if (lx >= 0 && lx < 7 && ly >= 0 && ly < 7) {
        final borda = lx == 0 || lx == 6 || ly == 0 || ly == 6;
        final centro = lx >= 2 && lx <= 4 && ly >= 2 && ly <= 4;
        return borda || centro;
      }
    }
    return false; // separador branco em volta do quadrado de canto
  }

  @override
  void paint(Canvas canvas, Size size) {
    final modulo = size.width / _n;
    final tinta = Paint()..color = const Color(0xFF111111);
    var estado = _semente(dados);

    for (var y = 0; y < _n; y++) {
      for (var x = 0; x < _n; x++) {
        bool preto;
        if (_areaReservada(x, y)) {
          preto = _pixelDeCanto(x, y);
        } else {
          estado = (estado * 48271) % 2147483647;
          preto = (estado >> 8) % 2 == 1;
        }
        if (preto) {
          canvas.drawRect(
            Rect.fromLTWH(x * modulo, y * modulo, modulo + 0.5, modulo + 0.5),
            tinta,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter antigo) => antigo.dados != dados;
}
