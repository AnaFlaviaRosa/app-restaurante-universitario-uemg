import 'package:cloud_firestore/cloud_firestore.dart';

/// Guarda o horário de abertura/fechamento de cada refeição.
/// Documento único: config/horarios
///
/// Por que isso é uma configuração e não um valor fixo no código:
/// o horário pode mudar (feriado, evento, etc.), então quem decide
/// é o administrador, não o desenvolvedor.
class HorarioRefeicao {
  final int inicioHora; // ex: 11 (11:00)
  final int fimHora; // ex: 14 (14:00)

  HorarioRefeicao({required this.inicioHora, required this.fimHora});
}

class ConfigService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, HorarioRefeicao>> buscarHorarios() async {
    final doc = await _db.collection('config').doc('horarios').get();
    final data = doc.data() ??
        {
          'almocoInicio': 11,
          'almocoFim': 14,
          'jantaInicio': 17,
          'jantaFim': 20,
        };
    return {
      'almoco': HorarioRefeicao(
        inicioHora: data['almocoInicio'] ?? 11,
        fimHora: data['almocoFim'] ?? 14,
      ),
      'janta': HorarioRefeicao(
        inicioHora: data['jantaInicio'] ?? 17,
        fimHora: data['jantaFim'] ?? 20,
      ),
    };
  }

  Future<void> salvarHorarios({
    required int almocoInicio,
    required int almocoFim,
    required int jantaInicio,
    required int jantaFim,
  }) {
    return _db.collection('config').doc('horarios').set({
      'almocoInicio': almocoInicio,
      'almocoFim': almocoFim,
      'jantaInicio': jantaInicio,
      'jantaFim': jantaFim,
    });
  }
}
