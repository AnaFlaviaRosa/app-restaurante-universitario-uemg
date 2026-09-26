import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../models/reserva.dart';
import '../../models/disponibilidade.dart';
import '../../services/reserva_service.dart';

/// Fluxo B definido pelo grupo: reservar marmita.
/// Mostra a disponibilidade da refeição selecionada (almoço/janta de
/// hoje) e permite reservar (se houver saldo e marmita disponível) ou
/// cancelar uma reserva já feita (se ainda estiver dentro do prazo).
class ReservaTab extends StatefulWidget {
  final Usuario usuario;
  const ReservaTab({super.key, required this.usuario});

  @override
  State<ReservaTab> createState() => _ReservaTabState();
}

class _ReservaTabState extends State<ReservaTab> {
  final _reservaService = ReservaService();
  TipoRefeicao _refeicaoSelecionada = TipoRefeicao.almoco;
  bool _reservando = false;

  DateTime get _hoje {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  Future<void> _reservar() async {
    setState(() => _reservando = true);
    try {
      await _reservaService.criarReserva(
        usuarioId: widget.usuario.id,
        data: _hoje,
        tipoRefeicao: _refeicaoSelecionada,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marmita reservada com sucesso!')),
        );
      }
    } catch (e) {
      final mensagem = _mensagemDeErro(e);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensagem)));
      }
    } finally {
      if (mounted) setState(() => _reservando = false);
    }
  }

  Future<void> _cancelar(Reserva reserva) async {
    try {
      await _reservaService.cancelarReserva(reserva);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reserva cancelada.')),
        );
      }
    } catch (e) {
      final mensagem = _mensagemDeErro(e);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensagem)));
      }
    }
  }

  String _mensagemDeErro(Object e) {
    if (e is SaldoInsuficienteException) return e.message;
    if (e is MarmitaEsgotadaException) return e.message;
    if (e is ReservaJaExisteException) return e.message;
    if (e is ForaDoPrazoException) return e.message;
    return 'Não foi possível concluir a operação.';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<TipoRefeicao>(
          segments: const [
            ButtonSegment(value: TipoRefeicao.almoco, label: Text('Almoço')),
            ButtonSegment(value: TipoRefeicao.janta, label: Text('Janta')),
          ],
          selected: {_refeicaoSelecionada},
          onSelectionChanged: (novo) =>
              setState(() => _refeicaoSelecionada = novo.first),
        ),
        const SizedBox(height: 16),
        StreamBuilder<Disponibilidade?>(
          stream: _reservaService.disponibilidadeStream(
              _hoje, _refeicaoSelecionada),
          builder: (context, snapshot) {
            final disp = snapshot.data;
            final esgotado = disp == null || disp.esgotado;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      disp == null
                          ? 'Ainda não há marmitas cadastradas para hoje.'
                          : '${disp.quantidadeDisponivel} de '
                              '${disp.quantidadeTotal} marmitas disponíveis',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<double>(
                      future: _reservaService
                          .valorParaTipo(tipoUsuarioToString(widget.usuario.tipo)),
                      builder: (context, valorSnap) {
                        if (!valorSnap.hasData) {
                          return const Text('Valor: carregando...');
                        }
                        return Text(
                            'Valor (${widget.usuario.isEstudante ? 'estudante' : 'comum'}): '
                            'R\$ ${valorSnap.data!.toStringAsFixed(2)}');
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed:
                          (esgotado || _reservando) ? null : _reservar,
                      child: _reservando
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(esgotado ? 'Esgotado' : 'Reservar marmita'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const Text('Minhas reservas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<List<Reserva>>(
          stream: _reservaService.reservasDoUsuario(widget.usuario.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final reservas = snapshot.data!;
            if (reservas.isEmpty) {
              return const Text('Você ainda não fez nenhuma reserva.');
            }
            return Column(
              children: reservas.map((r) {
                final podeCancel = r.status == StatusReserva.confirmada;
                return Card(
                  child: ListTile(
                    title: Text(
                      '${tipoRefeicaoToString(r.tipoRefeicao) == 'almoco' ? 'Almoço' : 'Janta'} - '
                      '${r.data.day.toString().padLeft(2, '0')}/'
                      '${r.data.month.toString().padLeft(2, '0')}',
                    ),
                    subtitle: Text('Status: ${statusReservaToString(r.status)}'),
                    trailing: podeCancel
                        ? TextButton(
                            onPressed: () => _cancelar(r),
                            child: const Text('Cancelar'),
                          )
                        : null,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
