"""Ironbook Plus: the auto-renewable subscription group (monthly + yearly, yearly with a one-week free trial).

    python Store/subs.py create              group, both subscriptions, localizations, prices in every territory,
                                             availability, the yearly free trial (idempotent)
    python Store/subs.py shot <png>          review screenshot for both subscriptions
    python Store/subs.py status              state of each subscription
    python Store/subs.py offer-code          a custom offer code for Pro owners (first month free on monthly)

The one-time Pro unlock (com.mattbusel.ironbook.pro) is untouched; Plus sits beside it.
"""
import hashlib
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP = "6814264434"
GROUP = "Ironbook Plus"
GROUP_LOC = {
    # locale: (group display name, custom app name or None)
    "en-US": ("Ironbook Plus", None),
    "en-GB": ("Ironbook Plus", None),
    "en-AU": ("Ironbook Plus", None),
    "en-CA": ("Ironbook Plus", None),
    "ja": ("Ironbook Plus", None),
    "ko": ("Ironbook Plus", None),
    "zh-Hans": ("Ironbook Plus", None),
    "es-ES": ("Ironbook Plus", None),
    "es-MX": ("Ironbook Plus", None),
    "de-DE": ("Ironbook Plus", None),
    "fr-FR": ("Ironbook Plus", None),
    "pt-BR": ("Ironbook Plus", None),
    "it": ("Ironbook Plus", None),
}
NOTE = ("Auto-renewable subscription in the group Ironbook Plus. Open the app: Train tab > the Plus card at the bottom (or "
        "Progress tab > See Ironbook Plus, or Settings > Ironbook Plus). The paywall shows both plans with price, period, "
        "the yearly plan's one-week free trial, auto-renew terms, Terms of Use and Privacy links, Restore Purchases and "
        "Manage Subscription. Plus includes everything in the one-time Pro unlock (charts, full records wall, lift history, "
        "programs, Apple Health, CSV export, bigger widgets) plus: every tape colour and PR Fireworks while subscribed, a monthly "
        "refill of credits (1 Next Block, 3 PR posters, 2 Week Shields on the 1st of each month), Muscle Balance insights "
        "(weekly sets per muscle group), the monthly challenge medal poster, and iCloud backup and restore of the training log. "
        "No account is needed.")
SUBS = [
    # suffix, period, name (30 max for the reference name), level, USD price, display name, description (45 max)
    ("plus.yearly", "ONE_YEAR", "Ironbook Plus Yearly", 1, "14.99", "Ironbook Plus (Yearly)",
     "Everything in Pro, monthly refills, insights"),
    ("plus.monthly", "ONE_MONTH", "Ironbook Plus Monthly", 2, "2.99", "Ironbook Plus (Monthly)",
     "Everything in Pro, monthly refills, insights"),
]
SUB_LOC = {
    "en-US": {"plus.yearly": ("Ironbook Plus Yearly", "Everything in Pro, monthly refills, insights"),
              "plus.monthly": ("Ironbook Plus Monthly", "Everything in Pro, monthly refills, insights")},
    "en-GB": {"plus.yearly": ("Ironbook Plus Yearly", "Everything in Pro, monthly refills, insights"),
              "plus.monthly": ("Ironbook Plus Monthly", "Everything in Pro, monthly refills, insights")},
    "en-AU": {"plus.yearly": ("Ironbook Plus Yearly", "Everything in Pro, monthly refills, insights"),
              "plus.monthly": ("Ironbook Plus Monthly", "Everything in Pro, monthly refills, insights")},
    "en-CA": {"plus.yearly": ("Ironbook Plus Yearly", "Everything in Pro, monthly refills, insights"),
              "plus.monthly": ("Ironbook Plus Monthly", "Everything in Pro, monthly refills, insights")},
    "ja": {"plus.yearly": ("Ironbook Plus 年額", "Proの全機能、毎月のクレジット補充、分析"),
           "plus.monthly": ("Ironbook Plus 月額", "Proの全機能、毎月のクレジット補充、分析")},
    "ko": {"plus.yearly": ("Ironbook Plus 연간", "Pro 전체 기능, 매달 크레딧 충전, 분석"),
           "plus.monthly": ("Ironbook Plus 월간", "Pro 전체 기능, 매달 크레딧 충전, 분석")},
    "zh-Hans": {"plus.yearly": ("Ironbook Plus 年度", "包含 Pro 全部功能、每月补充点数和分析"),
                "plus.monthly": ("Ironbook Plus 月度", "包含 Pro 全部功能、每月补充点数和分析")},
    "es-ES": {"plus.yearly": ("Ironbook Plus anual", "Todo Pro, recargas mensuales y análisis"),
              "plus.monthly": ("Ironbook Plus mensual", "Todo Pro, recargas mensuales y análisis")},
    "es-MX": {"plus.yearly": ("Ironbook Plus anual", "Todo Pro, recargas mensuales y análisis"),
              "plus.monthly": ("Ironbook Plus mensual", "Todo Pro, recargas mensuales y análisis")},
    "de-DE": {"plus.yearly": ("Ironbook Plus jährlich", "Alles aus Pro, monatliche Credits, Analysen"),
              "plus.monthly": ("Ironbook Plus monatlich", "Alles aus Pro, monatliche Credits, Analysen")},
    "fr-FR": {"plus.yearly": ("Ironbook Plus annuel", "Tout Pro, crédits mensuels et analyses"),
              "plus.monthly": ("Ironbook Plus mensuel", "Tout Pro, crédits mensuels et analyses")},
    "pt-BR": {"plus.yearly": ("Ironbook Plus anual", "Tudo do Pro, recargas mensais e análises"),
              "plus.monthly": ("Ironbook Plus mensal", "Tudo do Pro, recargas mensais e análises")},
    "it": {"plus.yearly": ("Ironbook Plus annuale", "Tutto Pro, ricariche mensili e analisi"),
           "plus.monthly": ("Ironbook Plus mensile", "Tutto Pro, ricariche mensili e analisi")},
}
BASE = "com.mattbusel.ironbook."


def call(method, path, body=None, params=None, quiet=False):
    """asc.call with patience: the API key is shared by several apps' scripts, so a 429 waits and retries."""
    import time
    url = path if path.startswith("http") else asc.BASE + path
    for attempt in range(8):
        r = requests.request(method, url, headers={"Authorization": f"Bearer {asc.token()}", "Content-Type": "application/json"},
                             json=body, params=params, timeout=120)
        if r.status_code in (429, 401) or r.status_code >= 500:
            time.sleep(min(120, 10 * (attempt + 1)))
            continue
        break
    if r.status_code >= 400:
        if not quiet:
            print(f"  ! {method} {path} -> {r.status_code}")
            try:
                for e in r.json().get("errors", []):
                    print(f"    {e.get('title')}: {e.get('detail')}")
            except Exception:
                print("    " + r.text[:400])
        return None
    return r.json() if r.content else {}


asc.call = call


def group():
    got = asc.call("GET", f"/v1/apps/{APP}/subscriptionGroups", params={"limit": 50})
    for g in got["data"]:
        if g["attributes"]["referenceName"] == GROUP:
            return g
    return asc.call("POST", "/v1/subscriptionGroups", {"data": {"type": "subscriptionGroups", "attributes": {"referenceName": GROUP},
                    "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})["data"]


def find(gid: str, pid: str):
    got = asc.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptions", params={"limit": 50})
    return next((s for s in got["data"] if s["attributes"]["productId"] == pid), None)


def territories():
    return [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]


def create():
    g = group()
    gid = g["id"]
    print("group", gid)
    have = {l["attributes"]["locale"]: l for l in asc.call("GET", f"/v1/subscriptionGroups/{gid}/subscriptionGroupLocalizations", params={"limit": 50})["data"]}
    for loc, (name, custom) in GROUP_LOC.items():
        if loc in have:
            continue
        attrs = {"locale": loc, "name": name}
        if custom:
            attrs["customAppName"] = custom
        r = asc.call("POST", "/v1/subscriptionGroupLocalizations", {"data": {"type": "subscriptionGroupLocalizations", "attributes": attrs,
                     "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
        print("  group loc", loc, "ok" if r else "FAILED")
    terr = None
    for suffix, period, ref, level, usd, _, _ in SUBS:
        pid = BASE + suffix
        s = find(gid, pid)
        if not s:
            r = asc.call("POST", "/v1/subscriptions", {"data": {"type": "subscriptions", "attributes": {
                "name": ref, "productId": pid, "subscriptionPeriod": period, "familySharable": False, "reviewNote": NOTE, "groupLevel": level},
                "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
            if not r:
                print(pid, "create FAILED"); continue
            s = r["data"]
        sid = s["id"]
        print(pid, sid, s["attributes"].get("state"))
        asc.call("PATCH", f"/v1/subscriptions/{sid}", {"data": {"type": "subscriptions", "id": sid, "attributes": {"reviewNote": NOTE}}}, quiet=True)
        locs = {l["attributes"]["locale"]: l for l in asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionLocalizations", params={"limit": 50})["data"]}
        for loc, table in SUB_LOC.items():
            name, desc = table[suffix]
            assert len(name) <= 30 and len(desc) <= 45, (loc, name, desc, len(desc))
            if loc in locs:
                continue
            r = asc.call("POST", "/v1/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations",
                         "attributes": {"locale": loc, "name": name, "description": desc},
                         "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
            print("  loc", loc, "ok" if r else "FAILED")
        # Availability first: prices can only be set in territories the subscription is available in.
        av = asc.call("GET", f"/v1/subscriptions/{sid}/subscriptionAvailability", quiet=True)
        if not av or not av.get("data"):
            terr = terr or territories()
            r = asc.call("POST", "/v1/subscriptionAvailabilities", {"data": {"type": "subscriptionAvailabilities",
                         "attributes": {"availableInNewTerritories": True},
                         "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                           "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terr]}}}})
            print("  availability", "ok" if r else "FAILED")
        prices = asc.call("GET", f"/v1/subscriptions/{sid}/prices", params={"limit": 200})
        if len(prices["data"]) < 150:
            pts = asc.call("GET", f"/v1/subscriptions/{sid}/pricePoints", params={"filter[territory]": "USA", "limit": 200, "include": "territory"})
            usa = None
            nxt = pts
            while nxt and not usa:
                usa = next((p for p in nxt["data"] if p["attributes"]["customerPrice"] == usd), None)
                link = nxt.get("links", {}).get("next")
                nxt = asc.call("GET", link) if (link and not usa) else None
            if not usa:
                print("  no USA price point", usd); continue
            eq = [usa]
            link = f"/v1/subscriptionPricePoints/{usa['id']}/equalizations"
            params = {"limit": 200, "include": "territory"}
            while link:
                page = asc.call("GET", link, params=params)
                params = None if "?" in (page.get("links", {}).get("next") or "") else params
                eq += page["data"]
                link = page.get("links", {}).get("next")
            have_terr = set()
            got = asc.call("GET", f"/v1/subscriptions/{sid}/prices", params={"limit": 200, "include": "territory"})
            for p in got["data"]:
                t = (p.get("relationships", {}).get("territory", {}).get("data") or {}).get("id")
                if t:
                    have_terr.add(t)
            todo = []
            for p in eq:
                t = (p.get("relationships", {}).get("territory", {}).get("data") or {}).get("id")
                if t is None:
                    # Equalization rows carry their territory in the id payload; fetch it if missing.
                    one = asc.call("GET", f"/v1/subscriptionPricePoints/{p['id']}", params={"include": "territory"})
                    t = one["data"]["relationships"]["territory"]["data"]["id"]
                if t not in have_terr:
                    todo.append(p["id"])
            ok = 0
            for ppid in todo:
                r = asc.call("POST", "/v1/subscriptionPrices", {"data": {"type": "subscriptionPrices",
                             "attributes": {"preserveCurrentPrice": False, "startDate": None},
                             "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                               "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": ppid}}}}})
                ok += 1 if r else 0
            print(f"  prices: {len(have_terr)} already, {ok}/{len(todo)} added at USD {usd} equivalents")
        if suffix == "plus.yearly":
            intro = asc.call("GET", f"/v1/subscriptions/{sid}/introductoryOffers", params={"limit": 200, "include": "territory"})
            have_i = {(o.get("relationships", {}).get("territory", {}).get("data") or {}).get("id") for o in intro["data"]}
            if len(intro["data"]) < 150:
                terr = terr or territories()
                ok = 0
                for t in [x for x in terr if x not in have_i]:
                    r = asc.call("POST", "/v1/subscriptionIntroductoryOffers", {"data": {"type": "subscriptionIntroductoryOffers",
                                 "attributes": {"duration": "ONE_WEEK", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1, "startDate": None, "endDate": None},
                                 "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                                   "territory": {"data": {"type": "territories", "id": t}}}}}, quiet=True)
                    ok += 1 if r else 0
                print(f"  free trial: {ok}/{len(terr)} territories")


def shot(png: str):
    data = Path(png).read_bytes()
    g = group()
    for suffix, *_ in SUBS:
        s = find(g["id"], BASE + suffix)
        if not s:
            continue
        sid = s["id"]
        cur = asc.call("GET", f"/v1/subscriptions/{sid}/appStoreReviewScreenshot", quiet=True)
        if cur and cur.get("data"):
            asc.call("DELETE", f"/v1/subscriptionAppStoreReviewScreenshots/{cur['data']['id']}")
        made = asc.call("POST", "/v1/subscriptionAppStoreReviewScreenshots", {"data": {"type": "subscriptionAppStoreReviewScreenshots",
                        "attributes": {"fileName": Path(png).name, "fileSize": len(data)},
                        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
        if not made:
            print(suffix, "reserve FAILED"); continue
        mid = made["data"]["id"]
        for op in made["data"]["attributes"]["uploadOperations"]:
            headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            requests.request(op["method"], op["url"], headers=headers, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
        r = asc.call("PATCH", f"/v1/subscriptionAppStoreReviewScreenshots/{mid}", {"data": {"type": "subscriptionAppStoreReviewScreenshots", "id": mid,
                     "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print(suffix, "review screenshot", "uploaded" if r else "FAILED")


def status():
    g = group()
    print("group", g["id"])
    for suffix, *_ in SUBS:
        s = find(g["id"], BASE + suffix)
        if not s:
            print(BASE + suffix, "missing"); continue
        n = len(asc.call("GET", f"/v1/subscriptions/{s['id']}/prices", params={"limit": 200})["data"])
        i = len(asc.call("GET", f"/v1/subscriptions/{s['id']}/introductoryOffers", params={"limit": 200})["data"])
        print(f"{BASE + suffix}: {s['id']} {s['attributes']['state']} prices={n} intro={i}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "shot":
        shot(sys.argv[2])
    else:
        {"create": create, "status": status}.get(cmd, lambda: sys.exit(__doc__))()
