"""The 1.2 in-app purchases: three 99-cent consumables (Next Block, PR Posters, Week Shield) and one-time tape colours and PR Fireworks.

    python Store/iap2.py create                 make every product (idempotent): text, $0.99, all territories
    python Store/iap2.py shot <kind> <png>      review screenshot for every product of a kind (block | poster | shield | theme | fireworks)
    python Store/iap2.py status                 show each product's state
    python Store/iap2.py submit                 queue every product for the next version submission
"""
import hashlib
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402
import iap  # noqa: E402

THEME_NOTE = ("Non-consumable, one-time. Train tab > gear (Settings) > Tape, blocks and extras opens the shop. "
              "Tapping a tape colour's price buys it; it recolours the app's tape and widgets and switches the app icon to match. "
              "Restore is on the Pro card in Settings.")
SHOP = "Train tab > gear (Settings) > Tape, blocks and extras. "
PRODUCTS = [
    # product id suffix, type, name (30 max), description (55 max), kind, review note
    ("block", "CONSUMABLE", "Next Block", "A 4-week plan with targets from your own lifts.", "block",
     "Consumable, one credit per purchase. Train tab > Next Block (also in the shop: " + SHOP + "). Pick a template you have "
     "logged with weights; Next Block shows week 1 and, for one credit, writes four templates (volume, build, heavy, deload) "
     "with a target load on every lift, computed on the device from the user's best estimated one-rep max. Each purchase builds one block. "
     "On a fresh install: start Upper A, tick a few sets, Finish workout, then open Next Block."),
    ("posters", "CONSUMABLE", "PR Posters x3", "Three gold PR posters to share.", "poster",
     "Consumable, three credits per purchase. After Finish workout, if the workout set a personal record, the finish sheet offers "
     "'PR poster x3'. Each credit renders one shareable poster of that PR (made on the device). Also listed in the shop: " + SHOP),
    ("shield", "CONSUMABLE", "Week Shield", "Keeps your weekly streak after a short week.", "shield",
     "Consumable, one credit per purchase. Settings has a weekly session goal; meeting it builds a week streak. When last week "
     "fell short, the Train tab shows a shield card: everyone gets one free shield a month, and Week Shield ($0.99) is for an extra. "
     "Also in the shop: " + SHOP),
    ("theme.cobalt", "NON_CONSUMABLE", "Cobalt Tape", "Blue tape for the app and widgets, with its icon.", "theme", THEME_NOTE),
    ("theme.volt", "NON_CONSUMABLE", "Volt Tape", "Green tape for the app and widgets, with its icon.", "theme", THEME_NOTE),
    ("theme.rose", "NON_CONSUMABLE", "Rose Tape", "Pink tape for the app and widgets, with its icon.", "theme", THEME_NOTE),
    ("theme.bone", "NON_CONSUMABLE", "Bone Tape", "White tape for the app and widgets, with its icon.", "theme", THEME_NOTE),
    ("fireworks", "NON_CONSUMABLE", "PR Fireworks", "Gold fireworks over every new PR.", "fireworks",
     "Non-consumable, one-time. " + SHOP + "Plays gold fireworks on the finish sheet when a workout sets a PR (chalk dust is free). "
     "A Try button previews it once bought."),
]
PRICE = "0.99"
BASE = "com.mattbusel.ironbook."


def find(pid: str):
    got = asc.call("GET", f"/v1/apps/{iap.app_id()}/inAppPurchasesV2", params={"filter[productId]": pid, "limit": 10})
    for d in (got or {}).get("data", []):
        if d["attributes"]["productId"] == pid:
            return d
    return None


def create():
    terr = None
    for suffix, kind, name, desc, _, note in PRODUCTS:
        pid = BASE + suffix
        it = find(pid)
        if not it:
            made = asc.call("POST", "/v2/inAppPurchases", {"data": {
                "type": "inAppPurchases",
                "attributes": {"name": name, "productId": pid, "inAppPurchaseType": kind, "reviewNote": note, "familySharable": False},
                "relationships": {"app": {"data": {"type": "apps", "id": iap.app_id()}}}}})
            if not made:
                print(f"{pid}: create FAILED"); continue
            it = made["data"]
        iid = it["id"]
        print(f"{pid}: {iid} {it['attributes'].get('state')}")
        locs = asc.call("GET", f"/v2/inAppPurchases/{iid}/inAppPurchaseLocalizations") or {"data": []}
        if not any(l["attributes"]["locale"] == "en-US" for l in locs["data"]):
            r = asc.call("POST", "/v1/inAppPurchaseLocalizations", {"data": {
                "type": "inAppPurchaseLocalizations", "attributes": {"locale": "en-US", "name": name, "description": desc},
                "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}})
            print("  localization", "added" if r else "FAILED")
        sched = asc.call("GET", f"/v2/inAppPurchases/{iid}/iapPriceSchedule", quiet=True)
        if not sched or not sched.get("data"):
            points = asc.call("GET", f"/v2/inAppPurchases/{iid}/pricePoints", params={"filter[territory]": "USA", "limit": 200})
            pp = next((d["id"] for d in (points or {}).get("data", []) if d["attributes"].get("customerPrice") == PRICE), None)
            r = pp and asc.call("POST", "/v1/inAppPurchasePriceSchedules", {
                "data": {"type": "inAppPurchasePriceSchedules", "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p1}"}]}}},
                "included": [{"type": "inAppPurchasePrices", "id": "${p1}", "attributes": {"startDate": None},
                              "relationships": {"inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": pp}}}}]})
            print("  price", f"${PRICE}" if r else "FAILED")
        avail = asc.call("GET", f"/v2/inAppPurchases/{iid}/inAppPurchaseAvailability", quiet=True)
        if not avail or not avail.get("data"):
            terr = terr or [t["id"] for t in asc.call("GET", "/v1/territories", params={"limit": 200})["data"]]
            r = asc.call("POST", "/v1/inAppPurchaseAvailabilities", {"data": {
                "type": "inAppPurchaseAvailabilities", "attributes": {"availableInNewTerritories": True},
                "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                                  "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terr]}}}})
            print("  availability", f"{len(terr)} territories" if r else "FAILED")


def shot(kind: str, png: str):
    data = Path(png).read_bytes()
    for suffix, _, _, _, k, _ in PRODUCTS:
        if k != kind:
            continue
        it = find(BASE + suffix)
        if not it:
            continue
        iid = it["id"]
        cur = asc.call("GET", f"/v2/inAppPurchases/{iid}/appStoreReviewScreenshot", quiet=True)
        if cur and cur.get("data"):
            asc.call("DELETE", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{cur['data']['id']}")
        made = asc.call("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {
            "type": "inAppPurchaseAppStoreReviewScreenshots", "attributes": {"fileName": Path(png).name, "fileSize": len(data)},
            "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}})
        if not made:
            print(suffix, "reserve FAILED"); continue
        sid = made["data"]["id"]
        for op in made["data"]["attributes"]["uploadOperations"]:
            headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
            requests.request(op["method"], op["url"], headers=headers, data=data[op["offset"]: op["offset"] + op["length"]], timeout=120).raise_for_status()
        r = asc.call("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{sid}", {"data": {
            "type": "inAppPurchaseAppStoreReviewScreenshots", "id": sid,
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print(suffix, "screenshot", "uploaded" if r else "FAILED")


def status():
    for suffix, *_ in PRODUCTS:
        it = find(BASE + suffix)
        print(f"{BASE + suffix}: {it['id'] + ' ' + it['attributes']['state'] if it else 'missing'}")


def submit():
    for suffix, *_ in PRODUCTS:
        it = find(BASE + suffix)
        if not it:
            continue
        r = asc.call("POST", "/v1/inAppPurchaseSubmissions", {"data": {"type": "inAppPurchaseSubmissions",
                     "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": it["id"]}}}}})
        print(suffix, "queued" if r else "refused")


def release(version: str = None):
    """Queue every product, then submit the version with them in one review submission."""
    submit()
    aid = iap.app_id()
    version = version or asc.current_version()
    v = asc.call("GET", f"/v1/apps/{aid}/appStoreVersions", params={"filter[versionString]": version})["data"][0]
    subs = asc.call("GET", "/v1/reviewSubmissions", params={"filter[app]": aid, "filter[state]": "READY_FOR_REVIEW", "filter[platform]": "IOS"})
    sub = subs["data"][0] if subs and subs.get("data") else asc.call("POST", "/v1/reviewSubmissions", {"data": {
        "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})["data"]
    items = asc.call("GET", f"/v1/reviewSubmissions/{sub['id']}/items") or {"data": []}
    if not items["data"]:
        r = asc.call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems", "relationships": {
            "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": v["id"]}}}}})
        print("version item", "added" if r else "FAILED")
    done = asc.call("PATCH", f"/v1/reviewSubmissions/{sub['id']}", {"data": {"type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}})
    print("review submission:", "SUBMITTED" if done else "failed")



def pro_price(amount: str = "4.99"):
    """Move Ironbook Pro to a new price, now, in every territory (base USA)."""
    it = find(iap.PRODUCT_ID)
    iid = it["id"]
    points = asc.call("GET", f"/v2/inAppPurchases/{iid}/pricePoints", params={"filter[territory]": "USA", "limit": 200})
    pp = next((d["id"] for d in (points or {}).get("data", []) if d["attributes"].get("customerPrice") == amount), None)
    if not pp:
        sys.exit(f"no USA price point at {amount}")
    r = asc.call("POST", "/v1/inAppPurchasePriceSchedules", {
        "data": {"type": "inAppPurchasePriceSchedules", "relationships": {
            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p1}"}]}}},
        "included": [{"type": "inAppPurchasePrices", "id": "${p1}", "attributes": {"startDate": None},
                      "relationships": {"inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": pp}}}}]})
    print("Pro price", f"${amount}" if r else "FAILED")
    got = asc.call("GET", f"/v2/inAppPurchases/{iid}/iapPriceSchedule", params={"include": "manualPrices"}, quiet=True)
    for inc in (got or {}).get("included", []):
        print("  manual price", inc["id"], inc.get("attributes"))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "shot":
        shot(sys.argv[2], sys.argv[3])
    elif cmd == "pro-price":
        pro_price(*(sys.argv[2:3]))
    else:
        {"create": create, "status": status, "submit": submit, "release": release}.get(cmd, lambda: sys.exit(__doc__))()
