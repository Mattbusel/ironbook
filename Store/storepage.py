"""Product page tools beyond the listing text: In-App Events, promoted purchases with their images, custom product pages.

    python Store/storepage.py events            the two events (Plus premiere, monthly challenge), localized, with card art
    python Store/storepage.py images            1024x1024 promotional images on the subscriptions and IAPs
    python Store/storepage.py promote           promoted purchases on the product page, in order
    python Store/storepage.py cpp               custom product pages (screenshots from Store/art/cpp/<set>)
    python Store/storepage.py state             what exists

Art comes from Store/art/promo.mjs and Store/art/frame.mjs. Nothing here mentions a price.
"""
import hashlib
import json
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP = "6814264434"
ART = Path(__file__).resolve().parent / "art"
LOCALES = ["en-US", "en-GB", "en-AU", "en-CA", "ja", "ko", "zh-Hans", "es-ES", "es-MX", "de-DE", "fr-FR", "pt-BR", "it"]


def upload(post_path, rel_type, rel_id, rel_name, png: Path, extra=None, commit_type=None):
    data = png.read_bytes()
    attrs = {"fileName": png.name, "fileSize": len(data)}
    attrs.update(extra or {})
    made = asc.call("POST", post_path, {"data": {"type": post_path.split("/")[-1], "attributes": attrs,
                    "relationships": {rel_name: {"data": {"type": rel_type, "id": rel_id}}}}})
    if not made:
        return None
    m = made["data"]
    for op in m["attributes"]["uploadOperations"]:
        h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
        requests.request(op["method"], op["url"], headers=h, data=data[op["offset"]: op["offset"] + op["length"]], timeout=180).raise_for_status()
    t = commit_type or post_path.split("/")[-1]
    return asc.call("PATCH", f"{post_path}/{m['id']}", {"data": {"type": t, "id": m["id"],
                    "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})


# ---------------------------------------------------------------- events

EVENTS = [
    {
        "ref": "ironbook 1.2 major update",  # the old draft, reused
        "badge": "MAJOR_UPDATE", "purpose": "APPROPRIATE_FOR_ALL_USERS", "purchase": "IN_APP_PURCHASE_OR_SUBSCRIPTION",
        "deepLink": "ironbook://plus",
        "schedule": {"publishStart": "2026-10-23T16:00:00Z", "eventStart": "2026-10-23T16:00:00Z", "eventEnd": "2026-11-20T16:00:00Z"},
        "card": "event-plus-card.png", "details": "event-plus-details.png",
        "copy": {
            "en-US": ("Meet Ironbook Plus", "Insights, monthly refills and iCloud backup",
                      "See every muscle's week, get Next Blocks and posters each month, every tape colour and a backup of your log."),
            "en-GB": ("Meet Ironbook Plus", "Insights, monthly refills and iCloud backup",
                      "See every muscle's week, get Next Blocks and posters each month, every tape colour and a backup of your log."),
            "ja": ("Ironbook Plus 登場", "部位別の分析、毎月の補充、iCloudバックアップ",
                   "部位ごとの1週間、毎月のNext Blockとポスター、すべてのテープカラー、記録のバックアップ。"),
            "ko": ("Ironbook Plus 출시", "부위별 분석, 매달 충전, iCloud 백업",
                   "부위별 한 주 기록, 매달 Next Block과 포스터, 모든 테이프 색상, 운동 기록 백업."),
            "zh-Hans": ("Ironbook Plus 上线", "部位分析、每月补充与 iCloud 备份",
                        "查看每块肌肉的一周训练量,每月获得 Next Block 和海报,全部胶带颜色,以及训练记录备份。"),
            "es-ES": ("Llega Ironbook Plus", "Análisis, recargas mensuales y copia en iCloud",
                      "Mira la semana de cada músculo, recibe Next Blocks y pósteres cada mes, todos los colores y una copia de tu registro."),
            "es-MX": ("Llega Ironbook Plus", "Análisis, recargas mensuales y respaldo en iCloud",
                      "Ve la semana de cada músculo, recibe Next Blocks y pósters cada mes, todos los colores y un respaldo de tu registro."),
            "de-DE": ("Ironbook Plus ist da", "Analysen, monatliche Credits, iCloud-Backup",
                      "Sieh die Woche jedes Muskels, jeden Monat Next Blocks und Poster, alle Tape-Farben und ein Backup deines Logs."),
            "fr-FR": ("Voici Ironbook Plus", "Analyses, recharges mensuelles, sauvegarde iCloud",
                      "Chaque muscle sur la semaine, des Next Blocks et posters chaque mois, toutes les couleurs et une sauvegarde."),
            "pt-BR": ("Chegou o Ironbook Plus", "Análises, recargas mensais e backup no iCloud",
                      "Veja a semana de cada músculo, ganhe Next Blocks e pôsteres todo mês, todas as cores e um backup do seu registro."),
            "it": ("Arriva Ironbook Plus", "Analisi, ricariche mensili e backup iCloud",
                   "La settimana di ogni muscolo, Next Block e poster ogni mese, tutti i colori e un backup del tuo registro."),
        },
    },
    {
        "ref": "ironbook november challenge 2026",
        "badge": "CHALLENGE", "purpose": "APPROPRIATE_FOR_ALL_USERS", "purchase": "NO_COST_ASSOCIATED",
        "deepLink": "ironbook://challenge",
        "schedule": {"publishStart": "2026-10-25T16:00:00Z", "eventStart": "2026-11-01T07:00:00Z", "eventEnd": "2026-11-30T23:00:00Z"},
        "card": "event-challenge-card.png", "details": "event-challenge-details.png",
        "copy": {
            "en-US": ("Iron Month", "Train 12 times in November, win the medal",
                      "A new Ironbook challenge: 12 sessions in November. Track it on the Train tab and add a gold medal to your wall."),
            "en-GB": ("Iron Month", "Train 12 times in November, win the medal",
                      "A new Ironbook challenge: 12 sessions in November. Track it on the Train tab and add a gold medal to your wall."),
            "ja": ("アイアン・マンス", "11月に12回トレーニングしてメダル獲得",
                   "Ironbookの新チャレンジ:11月に12回のトレーニング。Trainタブで進み具合を確認して、金メダルを手に入れよう。"),
            "ko": ("아이언 먼스", "11월에 12번 운동하고 메달 획득",
                   "Ironbook의 새 챌린지: 11월에 12회 운동. Train 탭에서 진행 상황을 보고 금메달을 받으세요."),
            "zh-Hans": ("钢铁之月", "11 月训练 12 次,赢取奖牌",
                        "Ironbook 新挑战:11 月完成 12 次训练。在 Train 页查看进度,把金牌挂上你的奖牌墙。"),
            "es-ES": ("Mes de Hierro", "Entrena 12 veces en noviembre y gana la medalla",
                      "Nuevo reto de Ironbook: 12 sesiones en noviembre. Síguelo en la pestaña Train y suma una medalla de oro."),
            "es-MX": ("Mes de Hierro", "Entrena 12 veces en noviembre y gana la medalla",
                      "Nuevo reto de Ironbook: 12 sesiones en noviembre. Síguelo en la pestaña Train y suma una medalla de oro."),
            "de-DE": ("Eisenmonat", "12 Trainings im November, hol dir die Medaille",
                      "Neue Ironbook-Challenge: 12 Einheiten im November. Verfolge sie im Train-Tab und hol dir eine Goldmedaille."),
            "fr-FR": ("Le Mois de Fer", "12 séances en novembre pour gagner la médaille",
                      "Nouveau défi Ironbook : 12 séances en novembre. Suivez-le dans l'onglet Train et gagnez une médaille d'or."),
            "pt-BR": ("Mês de Ferro", "Treine 12 vezes em novembro e ganhe a medalha",
                      "Novo desafio do Ironbook: 12 treinos em novembro. Acompanhe na aba Train e ganhe uma medalha de ouro."),
            "it": ("Mese di Ferro", "Allenati 12 volte a novembre, vinci la medaglia",
                   "Nuova sfida Ironbook: 12 sessioni a novembre. Seguila nella scheda Train e conquista una medaglia d'oro."),
        },
    },
]


def events():
    terr = [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]
    have = {e["attributes"]["referenceName"]: e for e in asc.call("GET", f"/v1/apps/{APP}/appEvents", params={"limit": 50})["data"]}
    for ev in EVENTS:
        for loc, (n, s, l) in ev["copy"].items():
            assert len(n) <= 30 and len(s) <= 50 and len(l) <= 120 and "—" not in n + s + l, (ev["ref"], loc, len(n), len(s), len(l))
        attrs = {"badge": ev["badge"], "deepLink": ev["deepLink"], "purchaseRequirement": ev["purchase"], "primaryLocale": "en-US",
                 "priority": "HIGH", "purpose": ev["purpose"], "territorySchedules": [dict(territories=terr, **ev["schedule"])]}
        if ev["ref"] in have:
            e = have[ev["ref"]]
            r = asc.call("PATCH", f"/v1/appEvents/{e['id']}", {"data": {"type": "appEvents", "id": e["id"], "attributes": attrs}})
            print(ev["ref"], e["id"], "updated" if r else "update FAILED")
        else:
            r = asc.call("POST", "/v1/appEvents", {"data": {"type": "appEvents", "attributes": dict(referenceName=ev["ref"], **attrs),
                         "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
            if not r:
                print(ev["ref"], "create FAILED"); continue
            e = r["data"]
            print(ev["ref"], e["id"], "created")
        locs = {l["attributes"]["locale"]: l for l in asc.call("GET", f"/v1/appEvents/{e['id']}/localizations", params={"limit": 50})["data"]}
        for loc, (n, s, l) in ev["copy"].items():
            a = {"name": n, "shortDescription": s, "longDescription": l}
            if loc in locs:
                asc.call("PATCH", f"/v1/appEventLocalizations/{locs[loc]['id']}", {"data": {"type": "appEventLocalizations", "id": locs[loc]["id"], "attributes": a}})
            else:
                m = asc.call("POST", "/v1/appEventLocalizations", {"data": {"type": "appEventLocalizations", "attributes": dict(locale=loc, **a),
                             "relationships": {"appEvent": {"data": {"type": "appEvents", "id": e["id"]}}}}})
                if not m:
                    print("  loc", loc, "FAILED"); continue
                locs[loc] = m["data"]
            lid = locs[loc]["id"]
            shots = asc.call("GET", f"/v1/appEventLocalizations/{lid}/appEventScreenshots")["data"]
            for sh in shots:  # replace the art every run, so a new card always lands
                asc.call("DELETE", f"/v1/appEventScreenshots/{sh['id']}")
            for kind, f in (("EVENT_CARD", ev["card"]), ("EVENT_DETAILS_PAGE", ev["details"])):
                r = upload("/v1/appEventScreenshots", "appEventLocalizations", lid, "appEventLocalization", ART / "promo" / f, {"appEventAssetType": kind})
                if not r:
                    print("  art", loc, kind, "FAILED")
            print("  ", loc, "ok")


# ---------------------------------------------------------------- promoted purchases

SUBS = {"plus.yearly": "6824726275", "plus.monthly": "6824728654"}
IAPS = {"block": "6820700972", "fireworks": "6820706402", "shield3": "6824730209"}
IMAGES = {"plus.yearly": "plus.png", "plus.monthly": "plus-monthly.png", "block": "block.png", "fireworks": "fireworks.png", "shield3": "shield.png"}
ORDER = ["plus.yearly", "plus.monthly", "block", "fireworks", "shield3"]


def images():
    for key, f in IMAGES.items():
        png = ART / "promo" / f
        if key in SUBS:
            sid = SUBS[key]
            cur = asc.call("GET", f"/v1/subscriptions/{sid}/images", quiet=True) or {"data": []}
            for c in cur["data"]:
                asc.call("DELETE", f"/v1/subscriptionImages/{c['id']}")
            r = upload("/v1/subscriptionImages", "subscriptions", sid, "subscription", png)
        else:
            iid = IAPS[key]
            cur = asc.call("GET", f"/v2/inAppPurchases/{iid}/images", quiet=True) or {"data": []}
            for c in cur["data"]:
                asc.call("DELETE", f"/v1/inAppPurchaseImages/{c['id']}")
            r = upload("/v1/inAppPurchaseImages", "inAppPurchases", iid, "inAppPurchase", png)
        print(key, "image", "uploaded" if r else "FAILED")


def promote():
    have = asc.call("GET", f"/v1/apps/{APP}/promotedPurchases", params={"limit": 50, "include": "subscription,inAppPurchaseV2"})
    print("existing promoted:", len(have["data"]))
    known = {}
    for p in have["data"]:
        rel = p.get("relationships", {})
        for k in ("subscription", "inAppPurchaseV2"):
            d = (rel.get(k) or {}).get("data")
            if d:
                known[d["id"]] = p["id"]
    ids = []
    for key in ORDER:
        target = SUBS.get(key) or IAPS[key]
        if target in known:
            ids.append(known[target]); continue
        rel = {"app": {"data": {"type": "apps", "id": APP}}}
        if key in SUBS:
            rel["subscription"] = {"data": {"type": "subscriptions", "id": target}}
        else:
            rel["inAppPurchaseV2"] = {"data": {"type": "inAppPurchases", "id": target}}
        r = asc.call("POST", "/v1/promotedPurchases", {"data": {"type": "promotedPurchases",
                     "attributes": {"visibleForAllUsers": True, "enabled": True}, "relationships": rel}})
        print(key, "promoted" if r else "promote FAILED")
        if r:
            ids.append(r["data"]["id"])
    if ids:
        r = asc.call("PATCH", f"/v1/apps/{APP}/relationships/promotedPurchases", {"data": [{"type": "promotedPurchases", "id": i} for i in ids]})
        print("order", "set" if r is not None else "FAILED")


# ---------------------------------------------------------------- custom product pages

CPPS = [
    ("Lifters: 1RM and blocks", "lifter",
     "A 1RM calculator with every percentage, four-week blocks with targets from your own numbers, and a records wall for every lift.",
     ["powerlifting", "1rm", "calculator", "deadlift", "squat", "bench"]),
    ("New lifters: gym log", "starter",
     "Log a workout in seconds. Last time's numbers beside every set, a rest timer on your Lock Screen and a new challenge every month.",
     ["lifting", "strength", "program"]),
    ("Builders: muscle balance", "builder",
     "See every muscle's week against the 10 to 20 set guide, the lifts climbing fastest, and every PR in gold.",
     ["bodybuilding", "weightlifting"]),
]


def cpp(version_template: str = None):
    have = {c["attributes"]["name"]: c for c in (asc.call("GET", f"/v1/apps/{APP}/appCustomProductPages", params={"limit": 50}) or {"data": []})["data"]}
    for name, setname, promo, kws in CPPS:
        assert len(promo) <= 170 and "—" not in promo
        if name in have:
            c = have[name]
            print(name, c["id"], "exists")
        else:
            r = asc.call("POST", "/v1/appCustomProductPages", {
                "data": {"type": "appCustomProductPages", "attributes": {"name": name},
                         "relationships": {"app": {"data": {"type": "apps", "id": APP}},
                                           "appCustomProductPageVersions": {"data": [{"type": "appCustomProductPageVersions", "id": "${v1}"}]}}},
                "included": [
                    {"type": "appCustomProductPageVersions", "id": "${v1}",
                     "relationships": {"appCustomProductPageLocalizations": {"data": [{"type": "appCustomProductPageLocalizations", "id": "${l1}"}]}}},
                    {"type": "appCustomProductPageLocalizations", "id": "${l1}", "attributes": {"locale": "en-US", "promotionalText": promo}},
                ]})
            if not r:
                print(name, "create FAILED"); continue
            c = r["data"]
            print(name, c["id"], "created")
        vers = asc.call("GET", f"/v1/appCustomProductPages/{c['id']}/appCustomProductPageVersions", params={"limit": 10})["data"]
        v = vers[0]
        print("  version", v["id"], v["attributes"].get("state"))
        locs = asc.call("GET", f"/v1/appCustomProductPageVersions/{v['id']}/appCustomProductPageLocalizations", params={"limit": 50})["data"]
        loc = next(l for l in locs if l["attributes"]["locale"] == "en-US")
        asc.call("PATCH", f"/v1/appCustomProductPageLocalizations/{loc['id']}", {"data": {"type": "appCustomProductPageLocalizations", "id": loc["id"], "attributes": {"promotionalText": promo}}})
        sets = asc.call("GET", f"/v1/appCustomProductPageLocalizations/{loc['id']}/appScreenshotSets", params={"limit": 50})["data"]
        sset = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == "APP_IPHONE_67"), None)
        files = sorted((ART / "cpp" / setname).glob("*.png"))
        local = [hashlib.md5(f.read_bytes()).hexdigest() for f in files]
        remote = []
        if sset:
            remote = [x["attributes"].get("sourceFileChecksum") for x in asc.call("GET", f"/v1/appScreenshotSets/{sset['id']}/appScreenshots", params={"limit": 20})["data"]]
        if remote != local:
            if not sset:
                sset = asc.call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
                                "relationships": {"appCustomProductPageLocalization": {"data": {"type": "appCustomProductPageLocalizations", "id": loc["id"]}}}}})["data"]
            for x in asc.call("GET", f"/v1/appScreenshotSets/{sset['id']}/appScreenshots", params={"limit": 20})["data"]:
                asc.call("DELETE", f"/v1/appScreenshots/{x['id']}")
            for f in files:
                upload("/v1/appScreenshots", "appScreenshotSets", sset["id"], "appScreenshotSet", f)
            print("  screenshots", len(files), "uploaded")
        else:
            print("  screenshots MATCH")
        # Search keywords for the page (Apple: drawn from the app's own keyword field).
        r = asc.call("POST", f"/v1/appCustomProductPageLocalizations/{loc['id']}/relationships/searchKeywords",
                     {"data": [{"type": "appKeywords", "id": k} for k in kws]}, quiet=True)
        print("  keywords", "set" if r is not None else "not available via API")


def state():
    for e in asc.call("GET", f"/v1/apps/{APP}/appEvents", params={"limit": 50})["data"]:
        print("event", e["id"], e["attributes"]["referenceName"], e["attributes"]["eventState"])
    for p in asc.call("GET", f"/v1/apps/{APP}/promotedPurchases", params={"limit": 50})["data"]:
        print("promoted", p["id"], p["attributes"].get("state"), p["attributes"].get("enabled"))
    for c in (asc.call("GET", f"/v1/apps/{APP}/appCustomProductPages", params={"limit": 50}) or {"data": []})["data"]:
        vs = asc.call("GET", f"/v1/appCustomProductPages/{c['id']}/appCustomProductPageVersions", params={"limit": 10})["data"]
        print("cpp", c["id"], c["attributes"]["name"], c["attributes"].get("url"), [v["attributes"].get("state") for v in vs], [v["id"] for v in vs])


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "state"
    {"events": events, "images": images, "promote": promote, "cpp": cpp, "state": state}.get(cmd, lambda: sys.exit(__doc__))()
