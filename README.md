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
- Ver saldo e histórico de movimentações
- Recarregar saldo (**simulado** — sem PIX/cartão real, conforme decidido)

**Administrador** (`usuarios/{uid}.tipo == 'admin'`)
- Atualizar a lotação manualmente (sem câmera/catraca no MVP)
- Definir a quantidade de marmitas disponíveis por refeição/dia
- Ver as reservas do dia e marcar como "retirada" / "não retirada"

**Fora do MVP (documentado, não implementado — decisão do grupo):**
reconhecimento facial, pagamento real (PIX/cartão), notificações push,
upload de imagem do cardápio pelo app (por enquanto é um link).

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
