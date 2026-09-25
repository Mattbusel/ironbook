# App Review notes

---

No account or login is required.

VERSION 1.1, IN-APP PURCHASE: Ironbook is now free. One non-consumable in-app purchase, "Ironbook Pro" (com.mattbusel.ironbook.pro, $9.99, one time, no subscription), unlocks the Progress tab, the Records tab, plate maths and the program library. Logging, templates, history, the live session and the rest timer stay free. To see the paywall: open the Progress or Records tab and tap "See Ironbook Pro", or tap the plate maths card or the Programs button on the Train tab. Buy and Restore purchase are on the paywall; Restore is also on the Ironbook Pro card at the bottom of the Train tab. People who bought the paid version get Pro automatically (checked with StoreKit AppTransaction in production only, so the sandbox always shows the paywall).

HOW TO USE: The Train tab lists workout templates. Tap START on one to open the live workout. Type a weight and reps for a set (or leave them blank to copy last time) and tap the tick; a rest timer appears. Tap "Finish workout" to save it. History, Progress and Records show the saved workouts. A new install starts empty; finishing one workout with a few ticked sets fills the other tabs.

PRIVACY: no data is collected. Everything is stored in a JSON file in the app's Documents folder on the device.

2. PURPOSE AND TARGET AUDIENCE
Ironbook is a personal strength-training log. It shows the previous session's numbers beside each set so the user knows what to beat, runs a rest timer, and charts estimated one-rep max progress and personal records. The audience is adults who lift weights at a gym or at home. Rated 4+.

3. SETUP AND ACCESS
No setup, login, credentials or sample data are required. Tap START on a template, tick some sets, tap Finish workout.

4. EXTERNAL SERVICES, TOOLS AND PLATFORMS
None. No network requests, no analytics, no advertising, no third-party frameworks. Built only with Apple's SwiftUI, Swift Charts, StoreKit 2 (for the in-app purchase) and Foundation. The only network traffic is StoreKit talking to the App Store.

5. REGIONAL DIFFERENCES
None. Works identically everywhere, offline.

6. REGULATED INDUSTRY / PROTECTED MATERIAL
Not applicable. The one-rep max figure is the standard Epley estimate calculated on the device. No licensed material; all art, text and code are my own work.
