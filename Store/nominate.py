"""Featuring nomination for this update (App Store Connect > Featuring > Nominations), through the API.

    python Store/nominate.py            create and submit it (skips if one with the same name exists)
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402

APP = "6814264434"
NAME = "Ironbook: Ironbook Plus, monthly challenges and insights"
DESCRIPTION = (
    "Ironbook is a strength-training log that looks like a gym blackboard: chalk on iron, gaffer tape, gold for records. "
    "It is built only with Apple frameworks and has no account, ads or tracking. This update adds a new challenge every month "
    "with gold medals and a medal wall, a 1RM calculator with every percentage worked out, Lock Screen widgets, a Control Center "
    "control and Siri shortcuts that start your next workout, TipKit onboarding, and Ironbook Plus: muscle balance insights "
    "(weekly sets per muscle against the 10 to 20 set guide), a monthly refill of its Next Block plans, PR posters and streak shields, "
    "every tape colour and iCloud backup of the whole log. It keeps the rest timer Live Activity in the Dynamic Island, Apple Health "
    "workout saving and Swift Charts progress. Two In-App Events run with it: the Plus premiere, and Iron Month, a 12-session "
    "November challenge. The store page is localized in 13 locales."
)
NOTES = "Made by one independent developer. Happy to provide anything the editorial team needs."


def main():
    for st in ("DRAFT", "SUBMITTED"):
        got = asc.call("GET", "/v1/nominations", params={"filter[state]": st, "limit": 50, "filter[relatedApps]": APP}, quiet=True) or {"data": []}
        for n in got["data"]:
            if n["attributes"]["name"] == NAME:
                print("already", st, n["id"]); return
    body = {"data": {"type": "nominations", "attributes": {
        "name": NAME, "type": "APP_ENHANCEMENTS", "description": DESCRIPTION, "notes": NOTES, "submitted": True,
        "publishStartDate": "2026-10-27T15:00:00Z", "deviceFamilies": ["IPHONE"],
        "locales": ["EN-US", "EN-GB", "EN-AU", "EN-CA", "DE-DE", "ES-ES", "ES-MX", "FR-FR", "IT", "JA", "KO", "PT-BR", "ZH-HANS"],
        "hasInAppEvents": True, "launchInSelectMarketsFirst": False, "preOrderEnabled": False},
        "relationships": {"relatedApps": {"data": [{"type": "apps", "id": APP}]}}}}
    r = asc.call("POST", "/v1/nominations", body)
    print(json.dumps(r)[:400] if r else "nomination FAILED")


if __name__ == "__main__":
    main()
