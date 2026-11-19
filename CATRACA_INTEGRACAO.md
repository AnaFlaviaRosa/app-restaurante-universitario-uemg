# Integração da catraca com o app (lotação por janela de tempo)

## Como funciona
1. A pessoa passa pela catraca.
2. A catraca (ou um computador/mini-PC ligado a ela, o "gateway") envia
   um "bip": cria um documento em `lotacao_eventos` no Firestore.
3. O app conta os documentos por janela (5 min, 10 min, 30 min, 1 h)
   e estima quem está dentro: entradas dos últimos N minutos, onde N é a
   "permanência média" configurada pelo admin (padrão 30 min).

## O que depende do fabricante da catraca (a confirmar com o RU/TI)
O app não fala com a catraca diretamente. Perguntar ao fornecedor se ela:
- envia evento por HTTP/webhook, MQTT ou TCP (precisamos de algo que um
  gateway consiga ouvir); ou
- tem banco/arquivo de log que um script possa ler a cada poucos segundos.
Sem nenhuma dessas saídas, só dá para usar o botão de teste do admin.

## Enviar o bip (plano Spark, sem Cloud Functions)
O gateway entra com uma conta própria do Firebase Auth e grava o evento
pela API REST. Passos únicos:
1. Firebase Console > Authentication: criar o usuário `catraca@...` com senha.
2. Firestore: criar o documento `catracas/<UID desse usuário>` (pode ser vazio).
   Só o Console escreve nessa coleção.
3. Publicar o `firestore.rules` deste projeto.

Fluxo do gateway (a cada passagem):
```bash
# 1) login (guardar o idToken; vale 1 h, renovar com o refreshToken)
curl -s "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"email":"catraca@...","password":"SENHA","returnSecureToken":true}'

# 2) bip
# ID_DO_EVENTO = identificador único da passagem (ex.: número do evento
# da catraca). Reenviar o mesmo ID NÃO conta duas vezes: a regra só
# permite criar, então o reenvio é recusado (trate como "já registrado").
curl -s -X POST \
 "https://firestore.googleapis.com/v1/projects/PROJECT_ID/databases/(default)/documents/lotacao_eventos?documentId=ID_DO_EVENTO" \
 -H "Authorization: Bearer ID_TOKEN" -H 'Content-Type: application/json' \
 -d '{"fields":{"ts":{"timestampValue":"2026-11-17T12:03:10Z"},
      "tipo":{"stringValue":"entrada"},"origem":{"stringValue":"catraca"},
      "expireAt":{"timestampValue":"2026-12-17T12:03:10Z"}}}'
```
O horário `ts` deve estar dentro de 2 min do relógio do servidor (regra de
segurança); mantenha o relógio do gateway sincronizado (NTP).
Se a internet cair, não reenvie bips muito antigos: seriam recusados.

## Limites e cuidados
- A estimativa é aproximada: a catraca registra só entradas. Se pessoas
  ficam bem mais ou menos que a média, o número erra para mais ou menos.
  Calibrar a permanência média com observação no local.
- Custo (cota gratuita): a estimativa atualiza a cada 5 min (1 leitura) e
  pausa com o app em segundo plano; a contagem da janela custa 1 leitura
  só quando o aluno toca. Exemplo: 300 alunos, 3 h de tela aberta, sem
  tocar em nada = 300 x 36 = 10.800 leituras/dia (antes: 108.000).
  Cada bip é 1 gravação (cota: 20 mil/dia).
- Melhoria futura: o gateway gravar um documento-resumo (`lotacao/atual`)
  com a estimativa e as 4 contagens a cada 1-2 min; o app leria só ele
  (1 leitura por aluno, trocar de janela sem custo).
- `lotacao_eventos` cresce: configure uma política de TTL no Firestore
  (Console > Firestore > Time-to-live) para a coleção `lotacao_eventos`,
  campo `expireAt` (o app e o exemplo acima já o preenchem com +30 dias).
  Confira na documentação do Firebase se a exclusão por TTL entra na
  cota de exclusões do seu plano. O admin também pode apagar à mão.
- Configure um alerta de uso/orçamento no Console desde o piloto. No
  plano Spark, estourar a cota faz o Firestore recusar operações até o
  dia seguinte (reservas também param).
- Não há dado pessoal nos eventos (apenas horário). Se a catraca ler
  carteirinha/matrícula, NÃO enviar essa informação (LGPD).

## Simulador da catraca (para testar sem a catraca real)
Na aba Lotação do admin há o cartão "Simulador da catraca" (sempre visível):
- +1 agora / +10 agora: registram entradas com o horário atual.
- Movimento: 60 em 30 min / 150 em 1 h: criam entradas com horários
  espalhados no passado (origem `simulacao`), para os botões de 5, 10, 30
  min e 1 h mostrarem números diferentes.
- Limpar simulações: apaga só as entradas de origem `simulacao`.
- A linha "Entradas registradas" mostra a contagem de cada janela.
Qualquer erro aparece na tela. "Sem permissão" = publique o
`firestore.rules` atualizado e confirme que o usuário é admin.
O horário no passado só é aceito para admin e origem `simulacao`
(até 3 h); a catraca real continua limitada a 2 min do relógio do servidor.
