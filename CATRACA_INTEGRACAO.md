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


---

# Baixa de saldo e liberação de reserva (ponte da catraca)

A catraca atende dois grupos pelo MESMO bip: quem **come no local** e quem
**retira marmita** (já reservada e paga). A ponte (`ponte_catraca/ponte.py`)
decide pela reserva:

| Situação do bip | O que a ponte faz | Lotação |
|---|---|---|
| Tem reserva `confirmada` desta refeição | reserva vira `liberada` (não cobra) | **não conta** |
| Reserva já `liberada`/`utilizada`/`naoRetirada` | nada (não cobra) | não conta |
| Sem reserva (ou reserva cancelada) | debita o preço do tipo + `movimentacoes` (consumo) + entrada em `lotacao_eventos` + `passagens` — **um commit atômico** | conta |
| 2ª passagem na mesma refeição | nada (não cobra de novo) | não conta |
| Fora do horário das refeições / usuário não encontrado | nada | não conta |

> Por isso o log `lotacao_eventos` só recebe quem fica no restaurante: quem
> retira marmita nunca entra nele (não precisa campo "modalidade").

## Como o aluno é identificado
O sistema facial atual reconhece a pessoa; a ponte recebe só um
**identificador** (matrícula ou CPF — `campo_identificador` no
`config.json`) e procura `usuarios` por esse campo. Nenhuma imagem passa
pelo app. Confirme com o fornecedor **qual identificador o evento traz**.

## Instalação da ponte
1. No Console do Firebase, crie um usuário (Authentication → e-mail/senha)
   para a catraca e anote o UID.
2. No Firestore, crie o documento `catracas/{UID}` (pode ter qualquer campo).
3. No computador da catraca: copie `ponte_catraca/`, renomeie
   `config.exemplo.json` para `config.json` e preencha (**não versionar**).
4. `python3 ponte.py servir --config config.json` abre um webhook em
   `http://127.0.0.1:8099/passagem`. O sistema da catraca faz:
   ```
   POST /passagem   (cabeçalho X-Token: <token_webhook>)
   {"id": "ID-UNICO-DO-EVENTO", "identificador": "123456"}
   ```
   Resposta: `{"resultado": "refeicao_no_local_cobrada" | "reserva_liberada" | ...}`.
   Se a catraca só gera log/MQTT/arquivo, escreva um adaptador que chame
   `Ponte.processar(id, identificador)` (a lógica não depende do webhook).
5. Teste sem hardware: `python3 ponte.py simular --config config.json --id t1 --identificador 123456`.
6. Testes automáticos da ponte: `cd ponte_catraca && python3 -m unittest -v test_ponte`.

## Segurança e cuidados
- A conta da catraca **lê `usuarios`** (precisa localizar por matrícula/CPF) e
  só consegue: marcar reserva `confirmada → liberada`; **diminuir** saldo em
  até o preço do tipo; criar `movimentacoes` de consumo, `passagens` e
  `lotacao_eventos`. Guarde `config.json` com cuidado e troque a senha se
  vazar. Mantenha o webhook em `127.0.0.1` (ou atrás de rede interna/HTTPS).
- **Idempotência:** o ID do evento vira ID de `movimentacoes/catraca_<id>` e
  `lotacao_eventos/<id>`; reenviar o mesmo evento é recusado (`ja_processado`).
- **Sem internet:** a ponte guarda o evento em `fila_pendente.jsonl` e
  `python3 ponte.py reenviar` reprocessa em ordem. Eventos atrasados são
  registrados com a hora do servidor (hora do reenvio).
- **Limite das regras:** um commit por passagem usa ~12 das 20 chamadas
  `get/exists` permitidas por lote; não acrescente outras escritas no mesmo
  commit sem recontar.
- **Saldo insuficiente:** `permitir_saldo_negativo: true` (padrão) debita
  mesmo assim (saldo pode ficar negativo; o app só bloqueia novas reservas).
  Com `false`, não debita, mas conta a entrada. A ponte **não abre nem fecha**
  a catraca: se o sistema atual decide a liberação, ele continua decidindo.
- **Duas fontes de saldo:** o sistema atual do RU precisa **deixar de debitar**
  a mesma passagem (ou o aluno paga duas vezes).
- **Ligar a integração** (aba Configurações do admin) só quando a ponte
  estiver funcionando; se ela cair, **desligue** para os alunos poderem abrir
  o protocolo direto da reserva.
- Ativar TTL em `passagens.expireAt` (junto com `lotacao_eventos.expireAt`).
