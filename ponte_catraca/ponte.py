#!/usr/bin/env python3
"""Ponte da catraca do RU (referência; só biblioteca padrão do Python).

Roda num computador ligado à catraca (ou ao sistema dela). Para CADA
passagem reconhecida, decide o que fazer — regra "opção B" do grupo:

  * TEM reserva confirmada na refeição de agora  -> a reserva vira
    "liberada" (a marmita já foi paga na reserva; NÃO cobra de novo).
    NÃO entra no log de lotação (quem retira marmita não fica no salão).
  * NÃO tem reserva (refeição no local)           -> debita o preço do
    tipo do usuário (config/precos), grava a movimentação de consumo,
    registra a entrada em lotacao_eventos e marca a passagem da refeição
    (passagens/{uid}_{dia}_{refeição}) para uma 2ª passagem não cobrar de
    novo. Tudo num ÚNICO commit atômico.

Idempotência: o ID do evento da catraca vira o ID dos documentos criados;
reenviar o mesmo evento não cobra nem conta duas vezes.

O reconhecimento facial continua no sistema atual da catraca: esta ponte
recebe só um IDENTIFICADOR (matrícula ou CPF) — nunca imagem/biometria.

Uso:
    python3 ponte.py servir   --config config.json      # webhook HTTP
    python3 ponte.py simular  --config config.json --id evt1 --identificador 123456
    python3 ponte.py reenviar --config config.json      # reprocessa a fila local
"""
import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HORARIOS_PADRAO = {"almoco": (11, 14), "janta": (17, 20)}
PRECOS_PADRAO = {"estudante": 4.0, "comum": 17.0}
DIAS_TTL = 30


# --------------------------------------------------------------------
# Erros
# --------------------------------------------------------------------
class ErroRede(Exception):
    """Sem internet / servidor indisponível: o evento vai para a fila."""


class JaExiste(Exception):
    """Documento com precondição 'não existe' já existe (evento repetido)."""


class SemPermissao(Exception):
    """Regras do Firestore recusaram (ex.: status da reserva já mudou)."""


# --------------------------------------------------------------------
# Regras de negócio (puras: não conhecem Firestore nem HTTP)
# --------------------------------------------------------------------
def fuso_padrao():
    try:
        from zoneinfo import ZoneInfo
        return ZoneInfo("America/Sao_Paulo")
    except Exception:  # sem tzdata (ex.: Windows): Brasília = UTC-3
        return timezone(timedelta(hours=-3))


def refeicao_em(agora_local, horarios):
    """'almoco' / 'janta' se [início, fim) contém a hora, senão None."""
    minutos = agora_local.hour * 60 + agora_local.minute
    for nome in ("almoco", "janta"):
        ini, fim = horarios[nome]
        if ini * 60 <= minutos < fim * 60:
            return nome
    return None


def horarios_de(doc):
    """Lê config/horarios (campos almocoInicio...) com os padrões do app."""
    d = doc or {}
    return {
        "almoco": (int(d.get("almocoInicio", 11)), int(d.get("almocoFim", 14))),
        "janta": (int(d.get("jantaInicio", 17)), int(d.get("jantaFim", 20))),
    }


def preco_de(doc, tipo):
    """Preço do tipo ('comum' paga o preço comum; o resto, o de estudante)."""
    d = doc or {}
    if tipo == "comum":
        return float(d.get("precoComum", PRECOS_PADRAO["comum"]))
    return float(d.get("precoEstudante", PRECOS_PADRAO["estudante"]))


def id_seguro(texto):
    """ID de documento válido (sem '/', sem '.' sozinho, tamanho razoável)."""
    s = re.sub(r"[^A-Za-z0-9_\-]", "_", str(texto))[:120]
    return s or "_"


class Ponte:
    def __init__(self, store, campo_identificador="matricula",
                 permitir_saldo_negativo=True, fuso=None, agora_fn=None):
        self.store = store
        self.campo = campo_identificador
        self.saldo_negativo = permitir_saldo_negativo
        self.fuso = fuso or fuso_padrao()
        self.agora_fn = agora_fn or (lambda: datetime.now(timezone.utc))

    def processar(self, evento_id, identificador):
        """Trata UMA passagem. Devolve {'resultado': ..., ...}."""
        evento_id = id_seguro(evento_id)
        local = self.agora_fn().astimezone(self.fuso)
        horarios = horarios_de(self.store.config("horarios"))
        refeicao = refeicao_em(local, horarios)
        if refeicao is None:
            return {"resultado": "fora_do_horario"}

        usuario = self.store.usuario_por_campo(self.campo, str(identificador).strip())
        if usuario is None:
            return {"resultado": "usuario_nao_encontrado"}
        uid = usuario["uid"]
        dia = local.strftime("%Y-%m-%d")

        # 1) Tem reserva paga? -> só libera (opção B).
        reserva = self.store.reserva_do_dia(uid, dia, refeicao)
        if reserva is not None:
            if reserva["status"] == "confirmada":
                try:
                    self.store.liberar_reserva(reserva["id"])
                except SemPermissao:  # o status mudou no meio (ex.: cancelada)
                    return {"resultado": "reserva_ja_processada"}
                return {"resultado": "reserva_liberada", "refeicao": refeicao}
            if reserva["status"] in ("liberada", "utilizada", "naoRetirada"):
                return {"resultado": "reserva_ja_processada", "refeicao": refeicao}
            # 'cancelada' (ou desconhecido): trata como quem não tem reserva.

        # 2) Refeição no local. Segunda passagem na mesma refeição: não cobra.
        chave_passagem = "%s_%s_%s" % (uid, dia, refeicao)
        if self.store.passagem_existe(chave_passagem):
            return {"resultado": "segunda_passagem", "refeicao": refeicao}

        valor = preco_de(self.store.config("precos"), usuario["tipo"])
        saldo = float(usuario.get("saldoAtual", 0))
        if saldo < valor and not self.saldo_negativo:
            # Não debita, mas a pessoa entrou: conta na lotação.
            try:
                self.store.registrar_entrada_sem_cobranca(evento_id, uid, chave_passagem)
            except JaExiste:
                return {"resultado": "ja_processado"}
            return {"resultado": "saldo_insuficiente_sem_cobranca",
                    "refeicao": refeicao, "valor": valor}

        try:
            self.store.cobrar_e_registrar(uid, valor, evento_id, refeicao, chave_passagem)
        except JaExiste:
            return {"resultado": "ja_processado"}
        return {"resultado": "refeicao_no_local_cobrada",
                "refeicao": refeicao, "valor": valor}


# --------------------------------------------------------------------
# Acesso ao Firestore pela API REST
# --------------------------------------------------------------------
def para_valor(v):
    """Python -> valor do Firestore REST."""
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    if isinstance(v, datetime):
        return {"timestampValue": v.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")}
    if v is None:
        return {"nullValue": None}
    return {"stringValue": str(v)}


def de_valor(v):
    """Valor do Firestore REST -> Python (só os tipos que usamos)."""
    if "stringValue" in v:
        return v["stringValue"]
    if "integerValue" in v:
        return int(v["integerValue"])
    if "doubleValue" in v:
        return float(v["doubleValue"])
    if "booleanValue" in v:
        return v["booleanValue"]
    if "timestampValue" in v:
        return v["timestampValue"]
    return None


def de_documento(doc):
    campos = doc.get("fields", {})
    return {k: de_valor(v) for k, v in campos.items()}


def http_urllib(metodo, url, cabecalhos, corpo):
    """Cliente HTTP padrão. Devolve (status, json). Rede fora -> ErroRede."""
    req = urllib.request.Request(url, data=corpo, method=metodo, headers=cabecalhos)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.status, json.loads(r.read().decode("utf-8") or "null")
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode("utf-8") or "null")
        except Exception:
            return e.code, None
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise ErroRede(str(e))


class FirestoreRest:
    def __init__(self, project_id, api_key, email, senha, http=http_urllib, agora_fn=time.time):
        self.projeto = project_id
        self.api_key = api_key
        self.email = email
        self.senha = senha
        self.http = http
        self.agora = agora_fn
        self._token = None
        self._refresh = None
        self._expira = 0.0
        self.raiz = "projects/%s/databases/(default)/documents" % project_id
        self.base = "https://firestore.googleapis.com/v1/" + self.raiz

    # ---- autenticação (conta própria da catraca, e-mail/senha) ----
    def _autenticar(self):
        if self._token and self.agora() < self._expira - 60:
            return self._token
        if self._refresh:
            corpo = urllib.parse.urlencode({
                "grant_type": "refresh_token", "refresh_token": self._refresh}).encode()
            status, dados = self.http(
                "POST", "https://securetoken.googleapis.com/v1/token?key=" + self.api_key,
                {"Content-Type": "application/x-www-form-urlencoded"}, corpo)
            if status == 200 and dados:
                self._token = dados["id_token"]
                self._refresh = dados["refresh_token"]
                self._expira = self.agora() + int(dados["expires_in"])
                return self._token
        corpo = json.dumps({"email": self.email, "password": self.senha,
                            "returnSecureToken": True}).encode()
        status, dados = self.http(
            "POST",
            "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key="
            + self.api_key, {"Content-Type": "application/json"}, corpo)
        if status != 200 or not dados:
            raise SemPermissao("login da catraca recusado (status %s)" % status)
        self._token = dados["idToken"]
        self._refresh = dados["refreshToken"]
        self._expira = self.agora() + int(dados["expiresIn"])
        return self._token

    def _chamar(self, metodo, url, corpo=None):
        cab = {"Authorization": "Bearer " + self._autenticar(),
               "Content-Type": "application/json"}
        dados = json.dumps(corpo).encode() if corpo is not None else None
        status, resp = self.http(metodo, url, cab, dados)
        if status in (500, 502, 503, 504):
            raise ErroRede("servidor indisponível (%s)" % status)
        return status, resp

    @staticmethod
    def _erro(status, resp):
        msg = ((resp or {}).get("error") or {}).get("status", "")
        if status == 409 or msg == "ALREADY_EXISTS":
            return JaExiste(msg)
        if status in (401, 403) or msg == "PERMISSION_DENIED":
            return SemPermissao(msg)
        if status == 404 or msg == "NOT_FOUND":
            return SemPermissao("documento não existe (%s)" % msg)
        return ErroRede("erro %s %s" % (status, msg))

    # ---- leituras ----
    def documento(self, caminho):
        status, resp = self._chamar("GET", "%s/%s" % (self.base, caminho))
        if status == 404:
            return None
        if status != 200:
            raise self._erro(status, resp)
        return de_documento(resp)

    def config(self, nome):
        return self.documento("config/" + nome)

    def usuario_por_campo(self, campo, valor):
        consulta = {"structuredQuery": {
            "from": [{"collectionId": "usuarios"}],
            "where": {"fieldFilter": {"field": {"fieldPath": campo},
                                      "op": "EQUAL", "value": para_valor(valor)}},
            "limit": 1}}
        status, resp = self._chamar("POST", self.base + ":runQuery", consulta)
        if status != 200:
            raise self._erro(status, resp)
        for item in resp or []:
            if "document" in item:
                d = de_documento(item["document"])
                d["uid"] = item["document"]["name"].rsplit("/", 1)[-1]
                return d
        return None

    def reserva_do_dia(self, uid, dia, refeicao):
        marcador = self.documento("reservas_ativas/%s_%s_%s" % (uid, dia, refeicao))
        if not marcador or not marcador.get("reservaId"):
            return None
        reserva = self.documento("reservas/" + marcador["reservaId"])
        if reserva is None:
            return None
        return {"id": marcador["reservaId"], "status": reserva.get("status", "")}

    def passagem_existe(self, chave):
        return self.documento("passagens/" + chave) is not None

    # ---- escritas ----
    def _nome(self, caminho):
        return "%s/%s" % (self.raiz, caminho)

    def _commit(self, escritas):
        status, resp = self._chamar("POST", self.base + ":commit", {"writes": escritas})
        if status != 200:
            raise self._erro(status, resp)

    def liberar_reserva(self, reserva_id):
        self._commit([{
            "update": {"name": self._nome("reservas/" + reserva_id),
                       "fields": {"status": para_valor("liberada")}},
            "updateMask": {"fieldPaths": ["status"]},
            "updateTransforms": [{"fieldPath": "liberadaEm",
                                  "setToServerValue": "REQUEST_TIME"}],
            "currentDocument": {"exists": True},
        }])

    def _escrita_passagem(self, uid, evento_id, chave):
        expira = datetime.now(timezone.utc) + timedelta(days=DIAS_TTL)
        return {"update": {"name": self._nome("passagens/" + chave),
                           "fields": {"uid": para_valor(uid),
                                      "eventoId": para_valor(evento_id),
                                      "expireAt": para_valor(expira)}},
                "currentDocument": {"exists": False}}

    def _escrita_entrada(self, evento_id):
        expira = datetime.now(timezone.utc) + timedelta(days=DIAS_TTL)
        return {"update": {"name": self._nome("lotacao_eventos/" + evento_id),
                           "fields": {"tipo": para_valor("entrada"),
                                      "origem": para_valor("catraca"),
                                      "expireAt": para_valor(expira)}},
                "updateTransforms": [{"fieldPath": "ts",
                                      "setToServerValue": "REQUEST_TIME"}],
                "currentDocument": {"exists": False}}

    def cobrar_e_registrar(self, uid, valor, evento_id, refeicao, chave):
        self._commit([
            {"update": {"name": self._nome("usuarios/" + uid)},
             "updateMask": {"fieldPaths": []},
             "updateTransforms": [{"fieldPath": "saldoAtual",
                                   "increment": {"doubleValue": -float(valor)}}],
             "currentDocument": {"exists": True}},
            {"update": {"name": self._nome("movimentacoes/catraca_" + evento_id),
                        "fields": {"usuarioId": para_valor(uid),
                                   "tipo": para_valor("consumo"),
                                   "valor": para_valor(float(valor)),
                                   "status": para_valor("aprovada"),
                                   "origem": para_valor("catraca"),
                                   "refeicao": para_valor(refeicao)}},
             "updateTransforms": [{"fieldPath": "data",
                                   "setToServerValue": "REQUEST_TIME"}],
             "currentDocument": {"exists": False}},
            self._escrita_entrada(evento_id),
            self._escrita_passagem(uid, evento_id, chave),
        ])

    def registrar_entrada_sem_cobranca(self, evento_id, uid, chave):
        self._commit([self._escrita_entrada(evento_id),
                      self._escrita_passagem(uid, evento_id, chave)])


# --------------------------------------------------------------------
# Fila local (internet fora): guarda e reenvia na ordem
# --------------------------------------------------------------------
class FilaLocal:
    def __init__(self, caminho):
        self.caminho = caminho

    def adicionar(self, evento_id, identificador):
        with open(self.caminho, "a", encoding="utf-8") as f:
            f.write(json.dumps({"id": evento_id, "identificador": identificador}) + "\n")

    def reenviar(self, ponte):
        """Reprocessa a fila. Para no primeiro erro de rede (mantém a ordem)."""
        if not os.path.exists(self.caminho):
            return 0
        with open(self.caminho, encoding="utf-8") as f:
            itens = [json.loads(l) for l in f if l.strip()]
        feitos = 0
        for item in itens:
            try:
                ponte.processar(item["id"], item["identificador"])
            except ErroRede:
                break
            feitos += 1
        restantes = itens[feitos:]
        with open(self.caminho, "w", encoding="utf-8") as f:
            for item in restantes:
                f.write(json.dumps(item) + "\n")
        return feitos


def processar_com_fila(ponte, fila, evento_id, identificador):
    """Processa; se a rede cair, guarda na fila e avisa quem chamou."""
    try:
        return ponte.processar(evento_id, identificador)
    except ErroRede:
        fila.adicionar(evento_id, identificador)
        return {"resultado": "na_fila_sem_internet"}


# --------------------------------------------------------------------
# Entrada: webhook HTTP simples (POST /passagem)
# --------------------------------------------------------------------
def criar_servidor(ponte, fila, token, host="127.0.0.1", porta=8099):
    class Handler(BaseHTTPRequestHandler):
        def _responder(self, codigo, corpo):
            dados = json.dumps(corpo).encode()
            self.send_response(codigo)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(dados)))
            self.end_headers()
            self.wfile.write(dados)

        def do_POST(self):
            if self.path != "/passagem":
                return self._responder(404, {"erro": "rota"})
            if self.headers.get("X-Token") != token:
                return self._responder(401, {"erro": "token"})
            try:
                tam = int(self.headers.get("Content-Length", "0"))
                evento = json.loads(self.rfile.read(tam) or b"{}")
                eid, ident = evento["id"], evento["identificador"]
            except Exception:
                return self._responder(400, {"erro": "corpo: use {id, identificador}"})
            try:
                resultado = processar_com_fila(ponte, fila, eid, ident)
            except SemPermissao as e:
                return self._responder(500, {"erro": "sem_permissao", "detalhe": str(e)})
            self._responder(200, resultado)

        def log_message(self, fmt, *args):  # sem identificadores nos logs
            sys.stderr.write("[ponte] %s\n" % (fmt % args))

    return ThreadingHTTPServer((host, porta), Handler)


def carregar(config_path):
    with open(config_path, encoding="utf-8") as f:
        c = json.load(f)
    store = FirestoreRest(c["project_id"], c["api_key"], c["email"], c["senha"])
    ponte = Ponte(store,
                  campo_identificador=c.get("campo_identificador", "matricula"),
                  permitir_saldo_negativo=c.get("permitir_saldo_negativo", True))
    fila = FilaLocal(c.get("arquivo_fila", "fila_pendente.jsonl"))
    return c, ponte, fila


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("comando", choices=["servir", "simular", "reenviar"])
    ap.add_argument("--config", default="config.json")
    ap.add_argument("--id")
    ap.add_argument("--identificador")
    a = ap.parse_args(argv)
    c, ponte, fila = carregar(a.config)
    if a.comando == "simular":
        print(processar_com_fila(ponte, fila, a.id or "teste_%d" % time.time(),
                                 a.identificador))
    elif a.comando == "reenviar":
        print("reenviados:", fila.reenviar(ponte))
    else:
        srv = criar_servidor(ponte, fila, c["token_webhook"],
                             c.get("host", "127.0.0.1"), int(c.get("porta", 8099)))
        print("Ponte da catraca ouvindo em http://%s:%s/passagem" % srv.server_address)
        srv.serve_forever()


if __name__ == "__main__":
    main()
