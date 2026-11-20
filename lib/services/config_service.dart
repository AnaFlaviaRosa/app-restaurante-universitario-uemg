import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/datas.dart';

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

  /// Está dentro do horário de funcionamento da refeição em [agora]?
  /// (da abertura, inclusive, até o fechamento, exclusive.)
  bool estaAbertoEm(DateTime agora) {
    final abre = DateTime(agora.year, agora.month, agora.day, inicioHora);
    final fecha = DateTime(agora.year, agora.month, agora.day, fimHora);
    return !agora.isBefore(abre) && agora.isBefore(fecha);
  }

  /// Já passou do fechamento da refeição em [agora]?
  bool encerradoEm(DateTime agora) {
    final fecha = DateTime(agora.year, agora.month, agora.day, fimHora);
    return !agora.isBefore(fecha);
  }
}

/// Situação do RU no dia: aberto ou fechado (botão "RU fechado hoje").
/// Documento único: config/status = { fechadoEm: 'AAAA-MM-DD', motivo }
class StatusRu {
  final String? fechadoEm; // dia (AAAA-MM-DD) em que o RU está fechado
  final String motivo;

  StatusRu({this.fechadoEm, this.motivo = ''});

  bool fechadoEmDia(DateTime dia) => fechadoEm == chaveDia(dia);

  factory StatusRu.fromMap(Map<String, dynamic>? map) {
    if (map == null) return StatusRu();
    return StatusRu(
      fechadoEm: map['fechadoEm'] as String?,
      motivo: (map['motivo'] ?? '') as String,
    );
  }
}

class ConfigService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const horariosPadrao = {
    'almocoInicio': 11,
    'almocoFim': 14,
    'jantaInicio': 17,
    'jantaFim': 20,
  };

  Map<String, HorarioRefeicao> _horariosDe(Map<String, dynamic> data) {
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

  Future<Map<String, HorarioRefeicao>> buscarHorarios() async {
    final doc = await _db.collection('config').doc('horarios').get();
    return _horariosDe(doc.data() ?? horariosPadrao);
  }

  Stream<Map<String, HorarioRefeicao>> horariosStream() {
    return _db
        .collection('config')
        .doc('horarios')
        .snapshots()
        .map((doc) => _horariosDe(doc.data() ?? horariosPadrao));
  }

  /// Valida os horários (horas cheias, 0–23, fim depois do início e
  /// janta depois do almoço). Devolve a mensagem de erro, ou null se OK.
  static String? validarHorarios({
    required int almocoInicio,
    required int almocoFim,
    required int jantaInicio,
    required int jantaFim,
  }) {
    bool hora(int h) => h >= 0 && h <= 23;
    if (![almocoInicio, almocoFim, jantaInicio, jantaFim].every(hora)) {
      return 'Use horas entre 0 e 23.';
    }
    if (almocoFim <= almocoInicio) {
      return 'O fim do almoço precisa ser depois do início.';
    }
    if (jantaFim <= jantaInicio) {
      return 'O fim da janta precisa ser depois do início.';
    }
    if (jantaInicio < almocoFim) {
      return 'A janta não pode começar antes do fim do almoço.';
    }
    return null;
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

  // ---------- integração com a catraca ----------

  /// `config/catraca.integracaoAtiva`: quando true, a ponte da catraca
  /// está em funcionamento e o protocolo só abre depois que a catraca
  /// liberar a reserva (status `liberada`). Quando false (padrão, ou se
  /// a ponte cair), o protocolo pode ser aberto direto da reserva
  /// confirmada, dentro do horário da refeição.
  Stream<bool> integracaoCatracaStream() {
    return _db.collection('config').doc('catraca').snapshots().map(
        (doc) => (doc.data()?['integracaoAtiva'] ?? false) == true);
  }

  Future<bool> integracaoCatracaAtiva() async {
    final doc = await _db.collection('config').doc('catraca').get();
    return (doc.data()?['integracaoAtiva'] ?? false) == true;
  }

  Future<void> definirIntegracaoCatraca(bool ativa) {
    return _db
        .collection('config')
        .doc('catraca')
        .set({'integracaoAtiva': ativa}, SetOptions(merge: true));
  }

  // ---------- RU fechado ----------

  Stream<StatusRu> statusRuStream() {
    return _db
        .collection('config')
        .doc('status')
        .snapshots()
        .map((doc) => StatusRu.fromMap(doc.data()));
  }

  Future<StatusRu> buscarStatusRu() async {
    final doc = await _db.collection('config').doc('status').get();
    return StatusRu.fromMap(doc.data());
  }
}
