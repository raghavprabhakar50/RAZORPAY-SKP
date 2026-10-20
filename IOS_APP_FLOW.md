# iOS app flow and Mac handoff

This is the same Flutter application, not a second or reduced iOS app. iOS uses
the same products, account-owned guest/cart behavior, wishlist, profile, coupons,
checkout and native My Orders screens as Android. Native Magic Checkout is not
enabled. Shopify-hosted checkout and the merchant's existing Razorpay integration
remain the payment flow; no payment is created by opening/closing the browser.

## Configuration prepared in the repository

- Live middleware: `https://shri-middleware.ekarigar.com`.
- Existing iOS bundle ID: `com.srikrishnapearls.sriKrishnaPearlsMobile` (unchanged).
- Shopify callback: `shop.73316171914.app://callback`, registered in Info.plist.
- Display name and SKP icon match the Android app.
- Debug, Profile and Release use Runner.entitlements with an app-scoped Keychain
  group for the existing secure-storage account, OAuth and cart persistence.
- Photo library and when-in-use location descriptions already exist. No camera,
  background-location or arbitrary HTTP permission is added.
- The project already uses Flutter Swift Package Manager. No Podfile is added:
  installed native iOS plugins support SPM; path_provider_foundation is Dart/FFI.
  Use the matching Flutter 3.47.6 SDK, or validate a newer version on a Mac.
- The build script sets the geolocator SPM foreground-only permission flag.
  Do not edit generated registrants or ephemeral packages manually.

## On a Mac

Install Xcode and its iOS tools, Flutter, and accept Xcode's license/first-launch
setup. Clone the latest app source and run:

```bash
bash scripts/ios_live.sh check
bash scripts/ios_live.sh simulator
open ios/Runner.xcworkspace
```

In Xcode, select Runner > Signing & Capabilities > your real Apple Team and
automatic signing. Verify the existing bundle ID belongs to that team, and that
the app-scoped Keychain group resolves to the same Team/app ID. Never substitute
a random team, change the shop's OAuth callback, or commit private signing files.

```bash
flutter devices
bash scripts/ios_live.sh run <device-id>
# After real-device checks and distribution signing are configured:
bash scripts/ios_live.sh ipa
```

The IPA, if signing/export succeeds, is under `build/ios/ipa/`. Use Xcode Organizer
or App Store Connect/TestFlight for the appropriate signed distribution. A debug
simulator .app is not an installable iPhone IPA. Windows cannot compile/sign iOS.
This script does not upload anything to Apple or charge a customer.

## Required iPhone acceptance pass

1. Guest startup: splash 4 stays skipped; products/categories/media load.
2. Add guest items, sign in/signup using Shopify OTP, return to Cart without
   opening checkout. Guest items replace an older saved cart when nonempty.
3. Switch A/B, restart and sign out: verify cart isolation and secure persistence.
4. Wishlist, product sharing, gallery profile image and denied/granted foreground
   location must work, including phone/iPad layout and denied-permission handling.
5. Signed-in cart: fetch public coupons from middleware, verify applicability
   directly with Shopify, eligible first/others grey. Change quantity; stale
   selection must clear. Guests must not fetch or see coupons.
6. Check Out shows its spinner, creates a fresh authenticated Shopify cart, and
   opens hosted checkout in the iOS browser sheet. Verify quantities, gift/order
   instructions, discount, delivery and final Shopify total. Browser close must
   never mark paid or automatically clear the cart.
7. **Account-switch checkout is a mandatory unresolved device check:** after
   A logs out and B signs in, Shopify checkout must show B's email/address. A prior
   cross-account browser-session report is not certified fixed by this iOS setup.
   Do not pay or distribute if the previous identity appears.
8. With the merchant's approval, complete the intended payment validation and
   verify Shopify order creation, webhook/sync, and only that customer's My Orders.

## What is and is not verified

Shared Dart/widget tests and configuration checks can run on Windows. macOS
plugin resolution, Swift compilation, signing, SPM location macro resolution,
Keychain persistence, OTP browser callbacks, hosted checkout/bank-app return,
App Store review and physical iPhone payment are **not** certified by those tests.
No iOS build or IPA was produced on the Windows workstation. Native source is
prepared for Mac testing, not claimed production-ready or payment-certified.
