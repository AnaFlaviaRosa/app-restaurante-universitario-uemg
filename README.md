# RU App — UEMG Passos

Base de código Flutter + Firebase (Auth + Firestore) para o app de
gerenciamento do Restaurante Universitário, seguindo a modelagem e as
regras de negócio definidas pelo grupo (Ana, Luan, Noemi, Bruna).

## O que já está implementado

**Estudante / usuário comum**
- Cadastro e login (Firebase Auth, e-mail/senha)
- Consultar lotação atual do RU (`InicioTab`)
- Reservar marmita de almoço ou janta, com todas as regras:
  - 1 reserva por refeição/dia
  - precisa ter saldo suficiente (marmita já é paga na reserva)
  - respeita a quantidade disponível
  - só reserva até o horário de abertura da refeição
- Cancelar reserva (até 1h antes da abertura, com estorno)
- **Protocolo de retirada** (ver "Fluxo da marmita" abaixo): código curto +
  tela com relógio, hora de abertura e contagem regressiva, de uso único
- **Quadro de avisos** na tela inicial (avisos importantes em destaque)
- Ver saldo e histórico de movimentações
- Recarregar saldo (**simulado** — sem PIX/cartão real, conforme decidido)

**Administrador** (`usuarios/{uid}.tipo == 'admin'`)
- Atualizar a lotação manualmente (sem câmera/catraca no MVP)
- Definir a quantidade de marmitas disponíveis por refeição/dia
- Ver as reservas do dia (nome, código, vegetariana, status), marcar
  "retirada"/"não retirada", **reverter** um status errado e **encerrar a
  refeição** (marca as que sobraram como não retiradas)
- **Lista do dia** (texto copiável com nome, vegetariana, código e um
  "[ ]" para marcar; cole no WhatsApp/documento e imprima por lá)
- **Quadro de avisos** com validade e o botão **"RU fechado hoje"**
  (bloqueia reservas, zera marmitas, estorna as confirmadas e avisa todos)
- Editar **horários** das refeições e ligar/desligar a **integração da
  catraca** (aba Configurações)

**Fora do MVP (documentado, não implementado — decisão do grupo):**
reconhecimento facial, pagamento real (PIX/cartão), notificações push,
upload de imagem do cardápio pelo app (por enquanto é um link).

## Fluxo da marmita (decisões do grupo)

Pagamento: a marmita é **paga na reserva** (opção B). A catraca só cobra
quem passa **sem reserva** (refeição no local).

```
confirmada --(passa na catraca)--> liberada --(abre o protocolo)--> utilizada
     |                                                  
     +--(cancelar até 1 h antes)--> cancelada (com estorno)
     +--(refeição acabou)--> naoRetirada (sem estorno)
```

- **Protocolo:** o aluno toca em "Retirar" (aviso de que ele é consumido),
  o app grava `protocoloAbertoEm` com a **hora do servidor** e a reserva
  vira `utilizada`. A tela mostra nome, refeição, vegetariana, código de
  6 caracteres, relógio com segundos, hora de abertura e contagem de 3 min
  (`duracaoProtocoloSegundos`). O funcionário confere a tela do aluno e o
  código na **lista do dia**. Depois dos 3 min mostra "expirado".
- **Integração da catraca ligada** (`config/catraca.integracaoAtiva`): o
  protocolo só abre depois da catraca marcar `liberada`. **Desligada**
  (padrão, ou se a ponte cair): abre direto da reserva confirmada, só
  dentro do horário da refeição.
- **RU fechado hoje:** `config/status = { fechadoEm: 'AAAA-MM-DD' }`
  bloqueia novas reservas; o botão também estorna as reservas confirmadas.
- A ponte da catraca (pasta `ponte_catraca/`) e as regras estão
  detalhadas em `CATRACA_INTEGRACAO.md`.

## Novas coleções / documentos

| Caminho | Para quê |
|---|---|
| `avisos/{id}` | quadro de avisos (`expiraEm` esconde sozinho) |
| `config/status` | RU fechado hoje |
| `config/catraca` | `integracaoAtiva` (bool) |
| `passagens/{uid}_{dia}_{refeição}` | marca de refeição no local já cobrada (só a catraca cria) |
| `catracas/{uid}` | conta de serviço da catraca (só pelo Console) |

Campos novos em `reservas`: `nome`, `codigo`, `liberadaEm`,
`protocoloAbertoEm`. Em `matriculas_validas`: `usadaPor`.

## Estrutura de pastas

```
lib/
  models/        -> Usuario, Reserva, Movimentacao, Disponibilidade, Cardapio, Lotacao
  services/       -> regras de negócio + acesso ao Firestore/Auth
  screens/
    auth/         -> login, cadastro
    estudante/     -> telas do usuário comum
    admin/         -> telas do administrador
  main.dart       -> inicializa o Firebase e decide a rota inicial
firestore.rules   -> regras de segurança (quem pode ler/escrever o quê)
ponte_catraca/    -> ponte Python da catraca (webhook -> Firestore) + testes
CATRACA_INTEGRACAO.md -> como ligar a catraca, regras, custos
```

## Como rodar (passo a passo)

1. Instalar o Flutter SDK: https://docs.flutter.dev/get-started/install
2. Rodar `flutter pub get` na raiz do projeto.
3. Criar um projeto em https://console.firebase.google.com
   - Ativar **Authentication** (método E-mail/Senha)
   - Ativar **Cloud Firestore** (modo produção)
4. Instalar a CLI do FlutterFire e conectar o projeto:
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Isso substitui automaticamente `lib/firebase_options.dart` (hoje é
   só um placeholder com instruções).
5. Publicar as regras de segurança: copiar o conteúdo de
   `firestore.rules` para a aba **Regras** do Firestore no console
   (ou usar `firebase deploy --only firestore:rules` se instalarem o
   Firebase CLI).
6. Rodar `flutter run` com um emulador ou celular conectado.

## Primeiro acesso como administrador

Não existe tela de "virar admin" pelo app (de propósito — é uma
permissão sensível). Depois de cadastrar o primeiro usuário pelo
app, vá até o Firestore Console, abra o documento em
`usuarios/{uid}` desse usuário e troque manualmente o campo:

```
tipo: "estudante"  →  tipo: "admin"
```

Esse usuário passará a ver a área de administração no próximo login.

## Antes de usar esta versão (ordem sugerida)

1. `flutter pub get` e `flutter test`.
   Este código foi escrito **sem acesso a Flutter/Dart**: pode haver erros
   de compilação a ajustar. Rode `flutter analyze` também.
2. Testar o `firestore.rules` no **Emulador do Firebase** (não foi testado):
   - criar usuário comum/estudante OK; tentar criar com `tipo: 'admin'`,
     com saldo ≠ 0 ou estudante sem matrícula → deve ser **negado**;
   - 1ª reserva de cada refeição funciona (leitura do marcador inexistente);
   - cancelar funciona e apagar o marcador por fora é **negado**;
   - abrir protocolo grava hora do servidor; abrir de novo é negado;
   - cadastro que falha no meio devolve a matrícula.
3. Publicar as regras no Console (aba Regras do Firestore).
4. Criar `config/horarios`, `config/precos` (ou usar a aba Configurações).
5. Ativar a política de **TTL** em `lotacao_eventos.expireAt` e
   `passagens.expireAt` (Console → Firestore → TTL).
6. Só depois de a ponte da catraca funcionar: ligar a integração na aba
   Configurações do admin.

**Ainda em aberto (decisão do grupo):** o que fazer com saldo insuficiente na
catraca (`permitir_saldo_negativo` na ponte); se haverá reserva com
antecedência e re-reserva após cancelar; "cor do dia" no protocolo; perfil
de funcionário (só se houver um aparelho no balcão).

## Próximos passos sugeridos para a equipe

- Cadastrar `config/horarios` no Firestore com os horários reais do
  RU (o código já assume 11h–14h para almoço e 17h–20h para janta se
  o documento não existir).
- Testar os casos de erro (saldo insuficiente, marmita esgotada,
  segunda reserva no mesmo dia, cancelamento fora do prazo) — ver
  Semanas 10–11 do planejamento.
- Revisar `firestore.rules` juntos antes da entrega: elas cobrem os
  casos principais, mas há um comentário no arquivo sobre uma
  melhoria futura (mover a escrita de disponibilidade para uma Cloud
  Function em vez de deixar o cliente decrementar direto).
