import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/cardapio.dart';
import '../../services/cardapio_service.dart';

/// Card de administração do cardápio do dia. Fica na MESMA aba da lotação
/// (LotacaoAdminTab), logo abaixo — as duas informações são atualizadas
/// manualmente pelo mesmo administrador, todo dia.
///
/// Só o admin enxerga este card (a aba só é exibida para usuários com
/// tipo == admin). Os demais usuários só VEEM o cardápio, na tela inicial
/// (InicioTab). Além da tela, o próprio Firestore bloqueia a escrita de
/// quem não é admin (ver firestore.rules).
///
/// Fluxo:
/// 1. `image_picker` abre a galeria e já devolve a imagem reduzida
///    (maxWidth) e recomprimida (imageQuality) — sem pacote extra.
/// 2. Se já existe um cardápio, o app pede confirmação: a troca apaga o
///    anterior (não há histórico).
/// 3. Os bytes viram Base64 e substituem o documento cardapios/atual.
class CardapioAdminCard extends StatefulWidget {
  const CardapioAdminCard({super.key});

  @override
  State<CardapioAdminCard> createState() => _CardapioAdminCardState();
}

class _CardapioAdminCardState extends State<CardapioAdminCard> {
  final _cardapioService = CardapioService();
  final _picker = ImagePicker();
  late final Stream<Cardapio?> _cardapioStream;

  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cardapioStream = _cardapioService.cardapioStream();
  }

  String _dois(int n) => n.toString().padLeft(2, '0');

  /// Ex.: "17/10 às 11h15"
  String _dataHora(DateTime d) =>
      '${_dois(d.day)}/${_dois(d.month)} às ${_dois(d.hour)}h${_dois(d.minute)}';

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<bool> _confirmarSubstituicao() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Substituir o cardápio?'),
        content: const Text(
          'O cardápio atual será apagado e não poderá ser recuperado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Substituir'),
          ),
        ],
      ),
    );
    return confirmou ?? false;
  }

  Future<void> _trocarImagem({required bool jaTemCardapio}) async {
    XFile? arquivo;
    try {
      arquivo = await _picker.pickImage(
        source: ImageSource.gallery,
        // Reduz e recomprime NA HORA DA ESCOLHA: é isso que mantém o
        // arquivo pequeno o bastante para caber em um documento do
        // Firestore (ver kTamanhoMaximoBase64).
        maxWidth: 1200,
        imageQuality: 70,
      );
    } catch (e) {
      debugPrint('ERRO AO ABRIR GALERIA: $e');
      _aviso('Não foi possível abrir a galeria.');
      return;
    }
    if (arquivo == null) return; // cancelou a escolha

    if (jaTemCardapio && !await _confirmarSubstituicao()) return;
    if (!mounted) return;

    setState(() => _enviando = true);
    try {
      final bytes = await arquivo.readAsBytes();
      await _cardapioService.publicarCardapio(
        imagemBase64: base64Encode(bytes),
        adminId: FirebaseAuth.instance.currentUser!.uid,
      );
      _aviso('Cardápio atualizado.');
    } on ImagemMuitoGrandeException catch (e) {
      _aviso(e.message);
    } catch (e) {
      debugPrint('ERRO AO SALVAR CARDÁPIO: $e');
      _aviso('Não foi possível salvar o cardápio.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cardápio do dia',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Uma imagem para almoço e janta. Ao enviar uma nova, a anterior '
              'é apagada — só o cardápio mais recente fica salvo.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            StreamBuilder<Cardapio?>(
              stream: _cardapioStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('ERRO CARDÁPIO (ADMIN): ${snapshot.error}');
                  return const Text('Não foi possível carregar o cardápio.');
                }
                final dados = snapshot.data;
                // `cardapio` só existe quando há uma imagem válida salva.
                final cardapio =
                    (dados != null && dados.temImagem) ? dados : null;
                final temCardapio = cardapio != null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cardapio != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          cardapio.imagemBytes,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Publicado em ${_dataHora(cardapio.atualizadoEm)}',
                        style: const TextStyle(
                            color: Colors.black45, fontSize: 12),
                      ),
                      if (!cardapio.ehDeHoje)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Este cardápio é de outro dia — envie o de hoje.',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('Nenhum cardápio publicado ainda.'),
                      ),
                    ElevatedButton.icon(
                      onPressed: _enviando
                          ? null
                          : () => _trocarImagem(jaTemCardapio: temCardapio),
                      icon: const Icon(Icons.image),
                      label: Text(
                        _enviando
                            ? 'Enviando...'
                            : temCardapio
                                ? 'Trocar imagem'
                                : 'Adicionar imagem',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
