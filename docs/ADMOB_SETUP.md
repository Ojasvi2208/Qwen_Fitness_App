# AdMob setup for PulseFit

Written for: the app owner, working in the AdMob console at
https://apps.admob.com (account: malik.ojasvi22@gmail.com).

The app currently ships **Google's public test ids**. Ads display but earn
nothing, and serving test ids to real users is against AdMob policy. These are
the steps that replace them.

---

## 1. Add the app

*Apps → Add app → Android*

- **Is your app listed on a supported app store?** → **No**.
  It is not published yet. Once PulseFit is live on Play you can link it from
  the same screen, and AdMob will match it automatically.
- **App name**: `PulseFit`

Result: an **App ID** shaped like

```
ca-app-pub-1234567890123456~1234567890
```

Note the **tilde** `~`. This goes in `AndroidManifest.xml`.

---

## 2. Create a banner ad unit

*(inside the app) → Ad units → Add ad unit → Banner*

- **Ad unit name**: `PulseFit Banner`
- Leave the advanced settings at their defaults for v1.

Result: an **ad unit ID** shaped like

```
ca-app-pub-1234567890123456/9876543210
```

Note the **slash** `/`. This goes in `AdUnitIds`.

**One unit is enough.** PulseFit renders ads only through the `AdBanner`
widget, so `AdPolicy` cannot be bypassed and no interstitial or rewarded unit
is used. Do not add ads mid-flow — that was a deliberate design decision, not
an oversight.

---

## 3. Payments — start this now, it is the slow one

*AdMob → Payments → Payments profile*

Add name, address and tax information. Google then posts a **PIN to the
physical address** once earnings pass a threshold, and verification can take
one to two weeks. Ads will serve without it, but nothing is ever paid out.

Starting it now means it is done by the time there is anything to pay.

---

## 4. app-ads.txt — not needed for v1

It authorises sellers against a website domain. There is no PulseFit site yet,
so skip it. Add it later if a domain appears.

---

## 5. Hand the two ids over

Neither is a secret — both ship inside every APK and can be read out of any
install. Paste them in chat and they get wired in two files:

| Id | Goes in |
|---|---|
| App ID (`~`) | `android/app/src/main/AndroidManifest.xml` |
| Banner unit ID (`/`) | `AdUnitIds` (`lib/data/platform/`) |

A release build must override both — the test ids are the default precisely so
a debug build never serves live ads.

---

## What changes in the Play Console once ads are live

This matters and is easy to get wrong.

The **Data safety** form currently answers *"no data collected"*, which is
true of the app itself: nothing leaves the device. **Google Mobile Ads
changes that** — it collects a device advertising identifier.

If the build you upload has live ad ids, the form must declare:

- Data collected: **Device or other IDs**
- Purpose: **Advertising or marketing**
- Shared with third parties: **Yes** (Google)

Submitting "no data collected" with ads live is a policy violation and a
common cause of rejection or later removal.

**The safe v1 sequence**: ship without ads, answer "no data collected"
honestly, then enable ads in a later release and update the form in the same
submission.
