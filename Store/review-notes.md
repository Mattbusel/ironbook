# App Review notes

---

No account, login or network connection is required.

FIX FOR THE PREVIOUS REJECTION (2.3.7): every screenshot was remade and none mentions a price, "free", a discount or a subscription. Prices appear only in the description.

WHAT IS NEW: Ironbook Plus (auto-renewable subscription group "Ironbook Plus": monthly and yearly, the yearly with a one-week free trial), a monthly challenge with medals (free), a 1RM calculator (free), Lock Screen widgets, a Control Center control (iOS 18), App Shortcuts for Siri, iCloud key-value backup of the log (Plus), muscle balance insights (Plus), TipKit tips, a Shield Pack consumable. Plus the earlier 1.2 work: rest timer Live Activity, week widget, streaks, warm-ups, Health saving, CSV, tape themes.

WHERE TO FIND THE SUBSCRIPTION: Train tab, scroll to the bottom card "Ironbook Plus and Pro" and tap SEE; or the Progress tab "See the plans"; or Progress > Muscle balance. The paywall lists Plus yearly, Plus monthly and the one-time Pro unlock with each price and period, the yearly trial terms, the auto-renew terms, Terms of Use (Apple standard EULA) and Privacy Policy links, Restore, Redeem code, and Manage subscription for subscribers. Restore is also on that Train tab card and in Settings (gear on the Train tab).

IN-APP PURCHASES (StoreKit 2):
- Ironbook Plus Monthly / Yearly (auto-renewable, same group): everything in Pro, plus Muscle balance (Progress tab), a monthly refill of credits (1 Next Block, 3 PR posters, 2 Week Shields, banked once per calendar month while subscribed), every tape colour and PR Fireworks while subscribed, iCloud backup (Settings > iCloud backup), and a medal poster for each finished monthly challenge (Train tab > the challenge card).
- Ironbook Pro (existing non-consumable, unchanged): Progress tab, full Records wall, lift history (tap a record), Program library, Apple Health saving, CSV export, the medium widget.
- Next Block (consumable, one credit): Train tab > Next Block. Needs a template logged with weights (start "Upper A", tick a few sets, Finish workout); one credit writes four templates with a target load on every lift.
- PR Posters x3 (consumable, three credits): the finish sheet offers a poster when a workout sets a PR.
- Week Shield (consumable, one credit) and Shield Pack x3 (consumable, three credits): Settings sets a weekly session goal. When last week fell short after a 2+ week streak, the Train tab shows a shield card; one shield per month is included for everyone.
- Cobalt, Volt, Rose, Bone tape colours and PR Fireworks (non-consumable): Settings > Tape, blocks and extras.
The shop (Settings > Tape, blocks and extras) lists every extra.

PROMOTED IN-APP PURCHASES: the app listens for StoreKit purchase intents, so a purchase started from the App Store product page completes in the app.

ICLOUD: Plus only, uses NSUbiquitousKeyValueStore to keep a compressed copy of the log in the user's own iCloud. Nothing is sent to any server of ours.

APPLE HEALTH: write-only, off by default. Each finished workout is saved as traditional strength training. Nothing is read from Health.

NOTIFICATIONS: asked once, the first time a rest timer starts, only for the "Rest's up" alert.

PRIVACY: no data is collected. No accounts, analytics, ads or third-party SDKs.

2. PURPOSE AND TARGET AUDIENCE
A personal strength-training log for adults who lift. Rated 4+.

3. SETUP AND ACCESS
No setup or credentials.

4. EXTERNAL SERVICES
None besides Apple frameworks.

5. REGIONAL DIFFERENCES
None.

6. REGULATED INDUSTRY / PROTECTED MATERIAL
Not applicable. Estimated one-rep max uses the standard Epley formula. The 10 to 20 weekly sets per muscle shown in Insights is presented as a common guide, not medical advice. All art, text and code are my own work.
