# App Review notes

---

No account, login or network connection is required.

WHAT IS NEW IN 1.2: rest timer Live Activity (Lock Screen and Dynamic Island) plus an end-of-rest local notification, a Home Screen week widget (WidgetKit extension, app group group.com.mattbusel.ironbook), weekly goal and streak, warm-up sets, notes, an exercise pick-list, a finish sheet, optional Apple Health workout saving (write-only), CSV export, tape colour themes with alternate app icons, and eight new in-app purchases. Ironbook Pro is now $4.99.

IN-APP PURCHASES (StoreKit 2; Restore on the Pro card in Settings, the gear on the Train tab):
- Ironbook Pro (existing non-consumable): Progress tab, full Records wall, lift history (tap a record), Program library, Apple Health saving, CSV export, the medium widget. Free users see the paywall from the Progress tab, the lock card under the top three records, the Programs button, and the Pro toggles in Settings.
- Next Block, $0.99 consumable (one credit): Train tab > Next Block. Choose a template that has been logged with weights; week 1 is previewed, and one credit writes four templates (volume, build, heavy, deload) with a target load on every lift, computed on the device from the best estimated one-rep max. To test on a fresh install: Start "Upper A", type weights and reps, tick a few sets, Finish workout, then open Next Block.
- PR Posters x3, $0.99 consumable (three credits): after Finish workout, if a set beat the previous best for that lift, the finish sheet offers a PR poster. Each credit renders one shareable image on the device. To see it: log a workout, then repeat it with a heavier weight.
- Week Shield, $0.99 consumable (one credit): Settings sets a weekly session goal. When last week fell short and the streak before it was 2+ weeks, the Train tab shows a shield card; everyone gets one free shield per month, the purchase is for extras.
- Cobalt, Volt, Rose, Bone tape colours ($0.99 each, non-consumable) and PR Fireworks ($0.99, non-consumable): Settings > Tape, blocks and extras. A tape colour recolours the app and widget and switches the app icon (alternate icons).
All three consumables are also listed in that shop with their remaining credits.

APPLE HEALTH: write-only, off by default. Settings > "Save workouts to Apple Health" (Pro) asks for permission to write workouts; each finished workout is saved as traditional strength training with its start and end time. Nothing is read from Health.

NOTIFICATIONS: asked once, the first time a rest timer starts, only for the "Rest's up" alert.

HOW TO USE: the Train tab lists templates. Tap START, type a weight and reps (or leave them blank to copy last time), tick the set; the rest timer starts. Finish workout saves it. History, Progress and Records read the saved workouts.

PRIVACY: no data is collected. No accounts, analytics, ads or third-party SDKs.

2. PURPOSE AND TARGET AUDIENCE
A personal strength-training log for adults who lift. Rated 4+.

3. SETUP AND ACCESS
No setup or credentials.

4. EXTERNAL SERVICES
None besides Apple frameworks: SwiftUI, Swift Charts, WidgetKit, ActivityKit, StoreKit 2, HealthKit (write-only), UserNotifications (local).

5. REGIONAL DIFFERENCES
None.

6. REGULATED INDUSTRY / PROTECTED MATERIAL
Not applicable. Estimated one-rep max uses the standard Epley formula. All art, text and code are my own work.
