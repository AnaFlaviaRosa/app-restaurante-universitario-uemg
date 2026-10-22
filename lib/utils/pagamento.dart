import 'dart:math';

/// Lógica "pura" da simulação de pagamento (Pix e cartão): formatação,
/// validação e geração de códigos. Nada aqui acessa a internet nem o
/// Firebase — por isso dá para testar fácil (test/pagamento_test.dart).
///
/// IMPORTANTE: é uma SIMULAÇÃO. Nenhuma cobrança real é feita e o app
/// nunca guarda o número completo do cartão nem o CVV.

// ---------- limites da recarga ----------

const double valorMinimoRecarga = 5.0;
const double valorMaximoRecarga = 500.0;
const List<double> valoresRapidosRecarga = [10, 20, 30, 50];

/// Devolve a mensagem de erro do valor, ou null se estiver ok.
String? erroValorRecarga(double? valor) {
  if (valor == null) return 'Informe o valor da recarga';
  if (valor < valorMinimoRecarga) {
    return 'O valor mínimo é ${formatarDinheiro(valorMinimoRecarga)}';
  }
  if (valor > valorMaximoRecarga) {
    return 'O valor máximo é ${formatarDinheiro(valorMaximoRecarga)}';
  }
  return null;
}

// ---------- formatação ----------

String apenasDigitos(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

/// 1234.5 -> "R$ 1.234,50"
String formatarDinheiro(double valor) {
  final negativo = valor < 0;
  final centavosTotais = (valor.abs() * 100).round();
  final inteiro = centavosTotais ~/ 100;
  final centavos = (centavosTotais % 100).toString().padLeft(2, '0');
  final comMilhar = inteiro.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => '.',
      );
  return '${negativo ? '-' : ''}R\$ $comMilhar,$centavos';
}

/// "22/07/2026 às 17:43"
String formatarDataHora(DateTime d) {
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(d.day)}/${dois(d.month)}/${d.year} às '
      '${dois(d.hour)}:${dois(d.minute)}';
}

// ---------- cartão ----------

enum BandeiraCartao { visa, mastercard, elo, amex, hipercard, desconhecida }

String nomeBandeira(BandeiraCartao b) {
  switch (b) {
    case BandeiraCartao.visa:
      return 'Visa';
    case BandeiraCartao.mastercard:
      return 'Mastercard';
    case BandeiraCartao.elo:
      return 'Elo';
    case BandeiraCartao.amex:
      return 'Amex';
    case BandeiraCartao.hipercard:
      return 'Hipercard';
    case BandeiraCartao.desconhecida:
      return 'Cartão';
  }
}

/// Descobre a bandeira pelos primeiros dígitos (Elo e Hipercard são
/// checadas antes, porque seus prefixos se misturam com Visa/Master).
BandeiraCartao detectarBandeira(String numero) {
  final d = apenasDigitos(numero);
  bool comeca(List<String> prefixos) => prefixos.any((p) => d.startsWith(p));

  if (comeca(const [
    '4011', '4312', '4389', '4514', '4576', '5041', '5066', '5067', '509',
    '6277', '6362', '6363', '650', '6516', '6550',
  ])) {
    return BandeiraCartao.elo;
  }
  if (comeca(const [
    '606282', '637095', '637568', '637599', '637609', '637612',
  ])) {
    return BandeiraCartao.hipercard;
  }
  if (comeca(const ['34', '37'])) return BandeiraCartao.amex;
  if (d.startsWith('4')) return BandeiraCartao.visa;
  if (d.length >= 2) {
    final dois = int.parse(d.substring(0, 2));
    if (dois >= 51 && dois <= 55) return BandeiraCartao.mastercard;
  }
  if (d.length >= 4) {
    final quatro = int.parse(d.substring(0, 4));
    if (quatro >= 2221 && quatro <= 2720) return BandeiraCartao.mastercard;
  }
  return BandeiraCartao.desconhecida;
}

/// Quantidade de dígitos do número do cartão (Amex tem 15, as demais 16).
int tamanhoNumeroCartao(BandeiraCartao b) => b == BandeiraCartao.amex ? 15 : 16;

/// Quantidade de dígitos do CVV (Amex tem 4, as demais 3).
int tamanhoCvv(BandeiraCartao b) => b == BandeiraCartao.amex ? 4 : 3;

/// "4242424242424242" -> "4242 4242 4242 4242" (Amex: 4-6-5).
String formatarNumeroCartao(String entrada) {
  final d = apenasDigitos(entrada);
  final amex = detectarBandeira(d) == BandeiraCartao.amex;
  final maximo = amex ? 15 : 16;
  final corte = d.length > maximo ? d.substring(0, maximo) : d;
  final grupos = amex ? const [4, 6, 5] : const [4, 4, 4, 4];

  final partes = <String>[];
  var inicio = 0;
  for (final g in grupos) {
    if (inicio >= corte.length) break;
    final fim = min(inicio + g, corte.length);
    partes.add(corte.substring(inicio, fim));
    inicio = fim;
  }
  return partes.join(' ');
}

/// "1228" -> "12/28"
String formatarValidade(String entrada) {
  var d = apenasDigitos(entrada);
  if (d.length > 4) d = d.substring(0, 4);
  if (d.length <= 2) return d;
  return '${d.substring(0, 2)}/${d.substring(2)}';
}

/// Algoritmo de Luhn: o "dígito verificador" que todo cartão real tem.
bool luhnValido(String numero) {
  final d = apenasDigitos(numero);
  if (d.length < 13) return false;
  var soma = 0;
  var dobrar = false;
  for (var i = d.length - 1; i >= 0; i--) {
    var n = int.parse(d[i]);
    if (dobrar) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    soma += n;
    dobrar = !dobrar;
  }
  return soma % 10 == 0;
}

/// Validade "MM/AA": mês de 1 a 12 e ainda não vencida (o cartão vale
/// até o último dia do mês indicado).
bool validadeValida(String mmaa, DateTime agora) {
  final d = apenasDigitos(mmaa);
  if (d.length != 4) return false;
  final mes = int.parse(d.substring(0, 2));
  final ano = 2000 + int.parse(d.substring(2));
  if (mes < 1 || mes > 12) return false;
  if (ano > agora.year + 20) return false;
  return agora.isBefore(DateTime(ano, mes + 1, 1));
}

/// Cartões de teste (como nos ambientes de homologação de gateways):
/// qualquer número válido é aprovado, exceto os que terminam em
///   0002 -> recusado pelo banco emissor
///   9995 -> saldo/limite insuficiente
/// Devolve a mensagem de recusa, ou null se o pagamento for aprovado.
String? motivoRecusaSimulada(String numero) {
  final d = apenasDigitos(numero);
  if (d.endsWith('0002')) {
    return 'Pagamento recusado pelo banco emissor. Tente outro cartão.';
  }
  if (d.endsWith('9995')) {
    return 'Saldo ou limite insuficiente. Tente outro cartão.';
  }
  return null;
}

// ---------- Pix ----------

/// Chave Pix FICTÍCIA do "recebedor" (RU UEMG) usada na simulação.
const String chavePixRuSimulada = '5d1f3a7e-9c42-4b86-a0e1-7f2b6c8d4e19';

final Random _aleatorio = Random();
const String _alfanumericos =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

String _sorteio(int tamanho) => List.generate(
      tamanho,
      (_) => _alfanumericos[_aleatorio.nextInt(_alfanumericos.length)],
    ).join();

/// Identificador da cobrança dentro do código Pix (até 25 caracteres
/// alfanuméricos, como no padrão do Banco Central).
String gerarTxid() => _sorteio(25);

/// ID de transação Pix no formato "E2E" (32 caracteres):
/// "E" + 8 dígitos (ISPB) + AAAAMMDDhhmm + 11 caracteres aleatórios.
String gerarIdTransacaoPix(DateTime agora) {
  String dois(int n) => n.toString().padLeft(2, '0');
  final carimbo = '${agora.year}${dois(agora.month)}${dois(agora.day)}'
      '${dois(agora.hour)}${dois(agora.minute)}';
  return 'E00000000$carimbo${_sorteio(11)}';
}

/// Código de autorização de 6 dígitos de uma compra no cartão.
String gerarCodigoAutorizacao() =>
    _aleatorio.nextInt(1000000).toString().padLeft(6, '0');

/// CRC16/CCITT-FALSE — a "soma de verificação" do Pix copia e cola.
int crc16Ccitt(String texto) {
  var crc = 0xFFFF;
  for (final b in texto.codeUnits) {
    crc ^= (b << 8);
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xFFFF;
    }
  }
  return crc;
}

String _campoEmv(String id, String valor) =>
    '$id${valor.length.toString().padLeft(2, '0')}$valor';

/// Monta um código "Pix copia e cola" no formato real (BR Code / EMV),
/// com CRC16 no final. Um app de banco reconheceria a estrutura, mas a
/// chave é fictícia — então nenhum pagamento de verdade é possível.
String gerarPixCopiaECola({
  required double valor,
  required String chave,
  required String txid,
  String nomeRecebedor = 'RU UEMG',
  String cidade = 'PASSOS',
}) {
  final conta = _campoEmv('00', 'br.gov.bcb.pix') + _campoEmv('01', chave);
  final corpo = StringBuffer()
    ..write(_campoEmv('00', '01')) // versão do payload
    ..write(_campoEmv('01', '12')) // 12 = cobrança de uso único
    ..write(_campoEmv('26', conta)) // dados do recebedor (Pix)
    ..write(_campoEmv('52', '0000')) // categoria do comerciante
    ..write(_campoEmv('53', '986')) // moeda: BRL
    ..write(_campoEmv('54', valor.toStringAsFixed(2)))
    ..write(_campoEmv('58', 'BR'))
    ..write(_campoEmv('59', nomeRecebedor))
    ..write(_campoEmv('60', cidade))
    ..write(_campoEmv('62', _campoEmv('05', txid)));
  final semCrc = '${corpo}6304';
  final crc = crc16Ccitt(semCrc).toRadixString(16).toUpperCase().padLeft(4, '0');
  return '$semCrc$crc';
}
