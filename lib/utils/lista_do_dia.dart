import '../models/reserva.dart';
import 'codigo_reserva.dart';
import 'datas.dart';

/// Uma linha da lista impressa do dia (o que o funcionário confere).
/// Só nome, opção vegetariana e código: sem CPF e sem dados financeiros.
class LinhaListaDia {
  final String nome;
  final bool vegetariana;
  final String codigo;

  const LinhaListaDia({
    required this.nome,
    required this.vegetariana,
    required this.codigo,
  });
}

/// Monta as linhas da lista de UMA refeição, em ordem alfabética.
///
/// - Entram reservas confirmadas, liberadas, utilizadas e não retiradas
///   (a lista é impressa na abertura, mas o admin pode reimprimir
///   depois); as canceladas ficam de fora.
/// - [nomes] completa o nome de reservas antigas que não guardaram o
///   nome (chave = id da reserva).
/// Função pura, fácil de testar.
List<LinhaListaDia> montarListaDoDia({
  required List<Reserva> reservas,
  required TipoRefeicao tipo,
  Map<String, String> nomes = const {},
}) {
  final linhas = <LinhaListaDia>[];
  for (final r in reservas) {
    if (r.tipoRefeicao != tipo) continue;
    if (r.status == StatusReserva.cancelada) continue;
    final nome = r.nome.isNotEmpty ? r.nome : (nomes[r.id] ?? '');
    linhas.add(LinhaListaDia(
      nome: nome.isEmpty ? '(sem nome)' : nome,
      vegetariana: r.vegetariana,
      codigo: r.codigo,
    ));
  }
  linhas.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  return linhas;
}

/// Monta o TEXTO da lista de uma refeição, para copiar e colar (WhatsApp,
/// documento, impressão por outro programa). Cada linha tem um "[ ]" para
/// o funcionário marcar quem retirou e o código, para conferir com a tela
/// de protocolo do aluno. Sem CPF. Função pura, fácil de testar.
String textoListaDoDia({
  required DateTime dia,
  required TipoRefeicao tipo,
  required List<LinhaListaDia> linhas,
}) {
  final nomeRefeicao = tipo == TipoRefeicao.janta ? 'Janta' : 'Almoço';
  final vegetarianas = linhas.where((l) => l.vegetariana).length;
  final largura = linhas.length.toString().length;
  final buffer = StringBuffer()
    ..writeln('RU UEMG Passos - $nomeRefeicao - '
        '${doisDigitos(dia.day)}/${doisDigitos(dia.month)}/${dia.year}')
    ..writeln('Total: ${linhas.length} marmitas | Vegetarianas: $vegetarianas')
    ..writeln();

  if (linhas.isEmpty) {
    buffer.writeln('Nenhuma reserva para esta refeição.');
  }
  for (var i = 0; i < linhas.length; i++) {
    final l = linhas[i];
    final numero = (i + 1).toString().padLeft(largura);
    final codigo = l.codigo.isEmpty ? '------' : codigoComEspaco(l.codigo);
    buffer.writeln('$numero. [ ] ${l.nome} | $codigo'
        '${l.vegetariana ? ' | VEGETARIANA' : ''}');
  }

  buffer
    ..writeln()
    ..write('Lista com nomes: descartar depois do uso.');
  return buffer.toString();
}
