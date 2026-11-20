import json
import os
import tempfile
import threading
import unittest
import urllib.request
from datetime import datetime, timedelta, timezone

import ponte as P

BRASILIA = timezone(timedelta(hours=-3))


def agora_fixo(hora_local=12, minuto=0):
    """Instante UTC equivalente a 19/11/2026 [hora_local]:[minuto] em Brasília."""
    local = datetime(2026, 11, 19, hora_local, minuto, tzinfo=BRASILIA)
    return lambda: local.astimezone(timezone.utc)


class LojaFalsa:
    """Substitui o Firestore: registra o que a ponte pediu."""

    def __init__(self, usuario=None, reserva=None, passagem=False, configs=None):
        self.usuario, self.reserva, self.passagem = usuario, reserva, passagem
        self.configs = configs or {}
        self.chamadas = []
        self.erro_cobranca = None
        self.erro_liberar = None

    def config(self, nome):
        return self.configs.get(nome)

    def usuario_por_campo(self, campo, valor):
        self.chamadas.append(("usuario", campo, valor))
        return self.usuario

    def reserva_do_dia(self, uid, dia, refeicao):
        self.chamadas.append(("reserva", uid, dia, refeicao))
        return self.reserva

    def passagem_existe(self, chave):
        return self.passagem

    def liberar_reserva(self, rid):
        if self.erro_liberar:
            raise self.erro_liberar
        self.chamadas.append(("liberar", rid))

    def cobrar_e_registrar(self, uid, valor, evento, refeicao, chave):
        if self.erro_cobranca:
            raise self.erro_cobranca
        self.chamadas.append(("cobrar", uid, valor, evento, refeicao, chave))

    def registrar_entrada_sem_cobranca(self, evento, uid, chave):
        self.chamadas.append(("so_entrada", evento, uid, chave))

    def nomes(self):
        return [c[0] for c in self.chamadas]


def ponte(loja, hora=12, **kw):
    return P.Ponte(loja, fuso=BRASILIA, agora_fn=agora_fixo(hora), **kw)


ESTUDANTE = {"uid": "u1", "tipo": "estudante", "saldoAtual": 10.0}
COMUM = {"uid": "u2", "tipo": "comum", "saldoAtual": 50.0}


class RegrasPuras(unittest.TestCase):
    def test_refeicao_nos_limites(self):
        h = P.horarios_de(None)
        f = lambda hh, mm: P.refeicao_em(datetime(2026, 1, 1, hh, mm), h)
        self.assertIsNone(f(10, 59))
        self.assertEqual(f(11, 0), "almoco")
        self.assertEqual(f(13, 59), "almoco")
        self.assertIsNone(f(14, 0))
        self.assertEqual(f(17, 0), "janta")
        self.assertIsNone(f(20, 0))

    def test_horarios_e_precos_do_firestore(self):
        h = P.horarios_de({"almocoInicio": 10, "almocoFim": 15,
                           "jantaInicio": 18, "jantaFim": 21})
        self.assertEqual(h["almoco"], (10, 15))
        self.assertEqual(P.preco_de(None, "comum"), 17.0)
        self.assertEqual(P.preco_de(None, "estudante"), 4.0)
        self.assertEqual(P.preco_de({"precoComum": 20, "precoEstudante": 5}, "comum"), 20.0)
        self.assertEqual(P.preco_de({"precoComum": 20, "precoEstudante": 5}, "admin"), 5.0)

    def test_id_seguro(self):
        self.assertEqual(P.id_seguro("a/b c"), "a_b_c")
        self.assertEqual(P.id_seguro(""), "_")


class DecisaoDaPassagem(unittest.TestCase):
    def test_fora_do_horario_nao_faz_nada(self):
        loja = LojaFalsa(usuario=ESTUDANTE)
        r = ponte(loja, hora=15).processar("e1", "123")
        self.assertEqual(r["resultado"], "fora_do_horario")
        self.assertEqual(loja.chamadas, [])

    def test_usuario_desconhecido(self):
        r = ponte(LojaFalsa()).processar("e1", "999")
        self.assertEqual(r["resultado"], "usuario_nao_encontrado")

    def test_com_reserva_confirmada_so_libera_sem_cobrar(self):
        loja = LojaFalsa(usuario=ESTUDANTE, reserva={"id": "r1", "status": "confirmada"})
        r = ponte(loja).processar("e1", "123")
        self.assertEqual(r["resultado"], "reserva_liberada")
        self.assertIn(("liberar", "r1"), loja.chamadas)
        self.assertNotIn("cobrar", loja.nomes())
        self.assertNotIn("so_entrada", loja.nomes())

    def test_reserva_ja_liberada_ou_usada_nao_cobra(self):
        for st in ("liberada", "utilizada", "naoRetirada"):
            loja = LojaFalsa(usuario=ESTUDANTE, reserva={"id": "r1", "status": st})
            r = ponte(loja).processar("e1", "123")
            self.assertEqual(r["resultado"], "reserva_ja_processada")
            self.assertNotIn("cobrar", loja.nomes())

    def test_status_mudou_no_meio_da_liberacao(self):
        loja = LojaFalsa(usuario=ESTUDANTE, reserva={"id": "r1", "status": "confirmada"})
        loja.erro_liberar = P.SemPermissao("status mudou")
        self.assertEqual(ponte(loja).processar("e1", "123")["resultado"],
                         "reserva_ja_processada")

    def test_sem_reserva_cobra_preco_do_tipo(self):
        loja = LojaFalsa(usuario=ESTUDANTE)
        r = ponte(loja).processar("e1", "123")
        self.assertEqual(r["resultado"], "refeicao_no_local_cobrada")
        self.assertEqual(r["valor"], 4.0)
        cobranca = [c for c in loja.chamadas if c[0] == "cobrar"][0]
        self.assertEqual(cobranca[1:], ("u1", 4.0, "e1", "almoco", "u1_2026-11-19_almoco"))

        loja2 = LojaFalsa(usuario=COMUM)
        self.assertEqual(ponte(loja2).processar("e2", "999")["valor"], 17.0)

    def test_reserva_cancelada_cai_no_caso_sem_reserva(self):
        loja = LojaFalsa(usuario=ESTUDANTE, reserva={"id": "r1", "status": "cancelada"})
        self.assertEqual(ponte(loja).processar("e1", "123")["resultado"],
                         "refeicao_no_local_cobrada")

    def test_segunda_passagem_na_mesma_refeicao_nao_cobra(self):
        loja = LojaFalsa(usuario=ESTUDANTE, passagem=True)
        self.assertEqual(ponte(loja).processar("e2", "123")["resultado"], "segunda_passagem")
        self.assertNotIn("cobrar", loja.nomes())

    def test_evento_repetido_e_idempotente(self):
        loja = LojaFalsa(usuario=ESTUDANTE)
        loja.erro_cobranca = P.JaExiste("ALREADY_EXISTS")
        self.assertEqual(ponte(loja).processar("e1", "123")["resultado"], "ja_processado")

    def test_saldo_insuficiente_conforme_politica(self):
        pobre = {"uid": "u3", "tipo": "comum", "saldoAtual": 2.0}
        negativo = LojaFalsa(usuario=pobre)
        self.assertEqual(ponte(negativo).processar("e1", "1")["resultado"],
                         "refeicao_no_local_cobrada")
        sem = LojaFalsa(usuario=pobre)
        r = ponte(sem, permitir_saldo_negativo=False).processar("e1", "1")
        self.assertEqual(r["resultado"], "saldo_insuficiente_sem_cobranca")
        self.assertIn("so_entrada", sem.nomes())
        self.assertNotIn("cobrar", sem.nomes())

    def test_campo_identificador_configuravel(self):
        loja = LojaFalsa(usuario=COMUM)
        ponte(loja, campo_identificador="cpf").processar("e1", " 11144477735 ")
        self.assertIn(("usuario", "cpf", "11144477735"), loja.chamadas)


class HttpFalso:
    def __init__(self, respostas):
        self.respostas = respostas  # lista de (status, corpo), na ordem
        self.pedidos = []

    def __call__(self, metodo, url, cab, corpo):
        self.pedidos.append((metodo, url, cab, json.loads(corpo) if corpo and cab.get("Content-Type") == "application/json" else corpo))
        return self.respostas.pop(0)


LOGIN_OK = (200, {"idToken": "T", "refreshToken": "R", "expiresIn": "3600"})


class AcessoRest(unittest.TestCase):
    def loja(self, *respostas):
        http = HttpFalso([LOGIN_OK, *respostas])
        return P.FirestoreRest("proj", "KEY", "c@x", "s", http=http, agora_fn=lambda: 1000.0), http

    def test_cobranca_e_um_commit_atomico_com_precondicoes(self):
        loja, http = self.loja((200, {}))
        loja.cobrar_e_registrar("u1", 4.0, "e1", "almoco", "u1_2026-11-19_almoco")
        corpo = http.pedidos[-1][3]
        w = corpo["writes"]
        self.assertEqual(len(w), 4)
        self.assertEqual(w[0]["updateTransforms"][0]["increment"], {"doubleValue": -4.0})
        self.assertEqual(w[0]["currentDocument"], {"exists": True})
        self.assertTrue(w[1]["update"]["name"].endswith("movimentacoes/catraca_e1"))
        self.assertEqual(w[1]["currentDocument"], {"exists": False})
        self.assertEqual(w[2]["update"]["fields"]["origem"], {"stringValue": "catraca"})
        self.assertEqual(w[2]["updateTransforms"][0]["setToServerValue"], "REQUEST_TIME")
        self.assertTrue(w[3]["update"]["name"].endswith("passagens/u1_2026-11-19_almoco"))
        self.assertEqual(http.pedidos[-1][2]["Authorization"], "Bearer T")

    def test_liberar_so_mexe_em_status_e_liberadaem(self):
        loja, http = self.loja((200, {}))
        loja.liberar_reserva("r1")
        w = http.pedidos[-1][3]["writes"][0]
        self.assertEqual(w["updateMask"], {"fieldPaths": ["status"]})
        self.assertEqual(w["update"]["fields"], {"status": {"stringValue": "liberada"}})
        self.assertEqual(w["updateTransforms"][0]["fieldPath"], "liberadaEm")

    def test_erros_viram_excecoes_certas(self):
        loja, _ = self.loja((409, {"error": {"status": "ALREADY_EXISTS"}}))
        with self.assertRaises(P.JaExiste):
            loja.cobrar_e_registrar("u1", 4.0, "e1", "almoco", "k")
        loja, _ = self.loja((403, {"error": {"status": "PERMISSION_DENIED"}}))
        with self.assertRaises(P.SemPermissao):
            loja.liberar_reserva("r1")
        loja, _ = self.loja((503, None))
        with self.assertRaises(P.ErroRede):
            loja.liberar_reserva("r1")

    def test_usuario_por_campo_le_o_resultado(self):
        doc = {"document": {"name": "projects/p/databases/(default)/documents/usuarios/UID9",
                            "fields": {"tipo": {"stringValue": "comum"},
                                       "saldoAtual": {"doubleValue": 12.5}}}}
        loja, http = self.loja((200, [{"readTime": "x"}, doc]))
        u = loja.usuario_por_campo("matricula", "123")
        self.assertEqual(u, {"tipo": "comum", "saldoAtual": 12.5, "uid": "UID9"})
        consulta = http.pedidos[-1][3]["structuredQuery"]
        self.assertEqual(consulta["limit"], 1)
        self.assertEqual(consulta["where"]["fieldFilter"]["value"], {"stringValue": "123"})

    def test_usuario_inexistente(self):
        loja, _ = self.loja((200, [{"readTime": "x"}]))
        self.assertIsNone(loja.usuario_por_campo("matricula", "0"))

    def test_reserva_do_dia_usa_o_marcador(self):
        marcador = (200, {"fields": {"reservaId": {"stringValue": "R7"}}})
        reserva = (200, {"fields": {"status": {"stringValue": "confirmada"}}})
        loja, http = self.loja(marcador, reserva)
        self.assertEqual(loja.reserva_do_dia("u1", "2026-11-19", "almoco"),
                         {"id": "R7", "status": "confirmada"})
        self.assertTrue(http.pedidos[1][1].endswith("reservas_ativas/u1_2026-11-19_almoco"))

    def test_sem_marcador_sem_reserva(self):
        loja, _ = self.loja((404, None))
        self.assertIsNone(loja.reserva_do_dia("u1", "2026-11-19", "almoco"))

    def test_token_e_reaproveitado(self):
        loja, http = self.loja((200, {}), (200, {}))
        loja.liberar_reserva("a")
        loja.liberar_reserva("b")
        logins = [p for p in http.pedidos if "signInWithPassword" in p[1]]
        self.assertEqual(len(logins), 1)


class FilaESevidor(unittest.TestCase):
    def test_sem_internet_vai_para_a_fila_e_reenvia_em_ordem(self):
        class Quebrada(LojaFalsa):
            def usuario_por_campo(self, *a):
                raise P.ErroRede("sem internet")

        with tempfile.TemporaryDirectory() as d:
            fila = P.FilaLocal(os.path.join(d, "fila.jsonl"))
            r = P.processar_com_fila(ponte(Quebrada()), fila, "e1", "123")
            self.assertEqual(r["resultado"], "na_fila_sem_internet")
            P.processar_com_fila(ponte(Quebrada()), fila, "e2", "456")

            ok = LojaFalsa(usuario=ESTUDANTE)
            self.assertEqual(fila.reenviar(ponte(ok)), 2)
            self.assertEqual([c[3] for c in ok.chamadas if c[0] == "cobrar"], ["e1", "e2"])
            self.assertEqual(fila.reenviar(ponte(ok)), 0)

    def test_reenvio_para_no_primeiro_erro_de_rede(self):
        class Quebrada(LojaFalsa):
            def usuario_por_campo(self, *a):
                raise P.ErroRede("x")

        with tempfile.TemporaryDirectory() as d:
            fila = P.FilaLocal(os.path.join(d, "fila.jsonl"))
            fila.adicionar("e1", "1")
            fila.adicionar("e2", "2")
            self.assertEqual(fila.reenviar(ponte(Quebrada())), 0)
            with open(fila.caminho) as f:
                self.assertEqual(len(f.readlines()), 2)

    def test_webhook_exige_token_e_responde_json(self):
        loja = LojaFalsa(usuario=ESTUDANTE)
        with tempfile.TemporaryDirectory() as d:
            srv = P.criar_servidor(ponte(loja), P.FilaLocal(os.path.join(d, "f")),
                                   "segredo", porta=0)
            porta = srv.server_address[1]
            t = threading.Thread(target=srv.serve_forever, daemon=True)
            t.start()
            try:
                def post(token, corpo):
                    req = urllib.request.Request(
                        "http://127.0.0.1:%d/passagem" % porta,
                        data=json.dumps(corpo).encode(), method="POST",
                        headers={"X-Token": token, "Content-Type": "application/json"})
                    try:
                        with urllib.request.urlopen(req) as r:
                            return r.status, json.loads(r.read())
                    except urllib.error.HTTPError as e:
                        return e.code, None

                self.assertEqual(post("errado", {"id": "e", "identificador": "1"})[0], 401)
                self.assertEqual(post("segredo", {"x": 1})[0], 400)
                status, corpo = post("segredo", {"id": "e1", "identificador": "1"})
                self.assertEqual(status, 200)
                self.assertEqual(corpo["resultado"], "refeicao_no_local_cobrada")
            finally:
                srv.shutdown()
                srv.server_close()


if __name__ == "__main__":
    unittest.main()
