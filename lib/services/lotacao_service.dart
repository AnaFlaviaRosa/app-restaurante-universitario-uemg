import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lotacao.dart';

/// Lotação atual do RU.
///
/// - `lotacao/atual`: documento único (capacidade, modo, permanência
///   média, e o número manual do modo `manual`). Sempre sobrescrito.
/// - `lotacao_eventos/{id}`: um documento por passagem na catraca
///   (`{ts, tipo: 'entrada', origem}`). O app conta esses eventos por
///   janela de tempo com `count()`, que é feito no servidor e não baixa
///   os documentos.
class LotacaoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<Lotacao?> lotacaoStream() {
    return _db.collection('lotacao').doc('atual').snapshots().map(
        (doc) => doc.exists ? Lotacao.fromMap(doc.data()!) : null);
  }

  Future<void> atualizarLotacao({
    required int quantidadeAtual,
    required int capacidadeMaxima,
    required String adminId,
    String modo = Lotacao.modoManual,
    int permanenciaMediaMin = Lotacao.permanenciaPadraoMin,
  }) {
    return _db.collection('lotacao').doc('atual').set(Lotacao(
      quantidadeAtual: quantidadeAtual,
      capacidadeMaxima: capacidadeMaxima,
      atualizadoEm: DateTime.now(),
      atualizadoPor: adminId,
      modo: modo,
      permanenciaMediaMin: permanenciaMediaMin,
    ).toMap());
  }

  /// Quantas entradas aconteceram nos últimos [minutos] minutos.
  /// Usa agregação count(): cobra 1 leitura a cada 1.000 eventos
  /// (mínimo 1), em vez de 1 leitura por evento.
  Future<int> entradasNosUltimos(int minutos) async {
    final desde = Timestamp.fromDate(
        DateTime.now().subtract(Duration(minutes: minutos)));
    final resultado = await _db
        .collection('lotacao_eventos')
        .where('ts', isGreaterThanOrEqualTo: desde)
        .count()
        .get();
    return resultado.count ?? 0;
  }

  /// Registra uma entrada. Usado pelo botão de TESTE do administrador;
  /// a catraca real grava o mesmo documento pela API REST (ver
  /// CATRACA_INTEGRACAO.md).
  ///
  /// Com [id] (o ID do evento da catraca), o documento tem ID
  /// determinístico: reenviar o mesmo bip por falha de rede não conta a
  /// pessoa duas vezes (a regra só permite criar, então o reenvio é
  /// recusado). `expireAt` serve à política de TTL do Firestore, que
  /// apaga eventos antigos (ver CATRACA_INTEGRACAO.md).
  Future<void> registrarEntrada({String origem = 'manual', String? id}) {
    final dados = {
      'ts': FieldValue.serverTimestamp(),
      'tipo': 'entrada',
      'origem': origem,
      'expireAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30))),
    };
    final col = _db.collection('lotacao_eventos');
    return id == null ? col.add(dados) : col.doc(id).set(dados);
  }

  /// SIMULAÇÃO (admin): cria [total] entradas com horários espalhados
  /// nos últimos [ultimosMin] minutos, marcadas com origem 'simulacao'.
  /// Serve para testar os botões de período sem a catraca de verdade.
  /// Máximo de 400 por vez (limite de 500 gravações por lote).
  Future<void> simularMovimento({
    required int total,
    required int ultimosMin,
  }) async {
    final n = total.clamp(1, 400);
    final agora = DateTime.now();
    final aleatorio = math.Random();
    final batch = _db.batch();
    final expira =
        Timestamp.fromDate(agora.add(const Duration(days: 30)));
    for (var i = 0; i < n; i++) {
      // Horário aleatório entre "agora" e "agora - ultimosMin".
      final segundos = aleatorio.nextInt(ultimosMin * 60);
      batch.set(_db.collection('lotacao_eventos').doc(), {
        'ts': Timestamp.fromDate(agora.subtract(Duration(seconds: segundos))),
        'tipo': 'entrada',
        'origem': 'simulacao',
        'expireAt': expira,
      });
    }
    await batch.commit();
  }

  /// Registra várias entradas AGORA de uma vez (ex.: botão "+10").
  Future<void> registrarEntradas(int quantidade,
      {String origem = 'manual'}) async {
    final batch = _db.batch();
    final expira = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)));
    for (var i = 0; i < quantidade.clamp(1, 400); i++) {
      batch.set(_db.collection('lotacao_eventos').doc(), {
        'ts': FieldValue.serverTimestamp(),
        'tipo': 'entrada',
        'origem': origem,
        'expireAt': expira,
      });
    }
    await batch.commit();
  }

  /// Apaga os eventos de simulação (origem == 'simulacao'). Devolve
  /// quantos foram apagados.
  Future<int> limparSimulacao() async {
    var apagados = 0;
    while (true) {
      final lote = await _db
          .collection('lotacao_eventos')
          .where('origem', isEqualTo: 'simulacao')
          .limit(400)
          .get();
      if (lote.docs.isEmpty) break;
      final batch = _db.batch();
      for (final d in lote.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      apagados += lote.docs.length;
    }
    return apagados;
  }
}
