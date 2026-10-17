# App checkout: existing Shopify hosted checkout

## Live app configuration

The default middleware is `https://shri-middleware.ekarigar.com`. VS Code's first
launch configuration is **Sri Krishna Pearls - Live Middleware**. Alternatively,
run `powershell -File scripts/run_live.ps1` or build for production with:

```powershell
flutter build appbundle --release --dart-define=SKP_MIDDLEWARE_BASE_URL=https://shri-middleware.ekarigar.com
```

Do not use `scripts/run_local.ps1` or an old private `.env` file containing a
localhost override for live builds. Local XAMPP remains an explicit development
option. This configures the URL only; deploy and verify middleware authentication,
database access and Shopify order sync before releasing to customers.

My Orders now uses the authenticated middleware `/api/mobile/orders` endpoint
and native list screen instead of website order history. Its data source is the
middleware's synchronized orders/customer mapping. Deploy the corresponding
`Skp_customer_orders` library and `Mobile_checkout` controller change together
with this app update; webhook/order sync determines how fresh that list is.

## Active flow (supersedes the Online Store cart experiment below)

Check Out now directly creates an authenticated Shopify Storefront cart and
opens its checkoutUrl in the in-app browser sheet. The website cart detour and
native Magic are not the active path. Gift properties and order instructions
are preserved. Existing saved-native-payment migration safeguards remain.

Cart displays public coupon offers with Apply/Remove. A selected code is sent in
CartInput.discountCodes; Shopify must accept it for the actual customer/cart.
No savings or reduced cart totals are invented before verification. Invalid codes
produce a clear error; remove the selection to continue without that code.

Public offer source: Storefront-readable `discount_banner` metaobjects with an
explicit `coupon_code`, active flag and optional start/end dates. Existing banner
titles or discount IDs are never interpreted as codes. Current public banners
have no code field set, so the merchant's publicly advertised SKP5 code is the
fallback. This fallback is not a guarantee of eligibility or an enumeration of
all Shopify Admin discounts. Publish public `coupon_code` fields to change the
list without an app code edit; do not expose private or customer-targeted codes.

Coupon entries are requested newest-created first (`sortKey: id`, reverse order,
up to 100 entries) before eligibility-date/public-code filtering. Duplicate codes
keep their newest entry. The default card previews the first offer; explicitly
selected coupons remain visible on the card. The list is not a complete Admin
discount-code inventory; unpublished codes cannot appear through this feed.

Shopify-hosted checkout's own UI is unchanged. The coupon list is in the app cart,
not injected into Shopify's hosted payment page. Existing Shopify webhook/order
sync continues to save orders in middleware; no new native provider order is made.

## Previous experiment: Online Store cart / website Magic button (inactive)

The app now opens the officially supported Online Store cart permalink
`/cart/<numeric-variant>:<quantity>,...?storefront=true` on the merchant domain.
This loads the actual website theme, not the headless API `checkoutUrl`. The
customer uses the website's existing Check Out button. A public isolated-session
probe verified the exact variant/quantity in `/cart.js`, final `/cart` location,
HTTP 200 and the existing Razorpay `magic-shopify.js` script. This is not a real
payment or a certification that the Magic popup completed successfully.

No Customer Account token, email, phone or address is placed in this URL. Website
session/login is separate and may require authentication/OTP. The browser cart
is populated from the app cart; payment/stock/prices remain Shopify-authoritative.

Permalinks support properties only on the FIRST product. Its gift attributes are
encoded using Shopify's documented `properties` parameter. Carts with subsequent
gift properties or ambiguous duplicate gifted variants use the authenticated
hosted checkout below instead; gift details are never silently discarded. Large
gift URLs also use that fallback.

Middleware still consumes Shopify order webhooks and scheduled order sync to
save/update its local order/customer/item/payment records. It no longer needs to
create a separate Razorpay/draft order for this website flow. Delivery depends on
the deployed webhook/sync configuration. No live order was created in this check.

Reference: https://shopify.dev/docs/apps/build/checkout/create-cart-permalinks

## Order special instructions

Cart has an optional 1000-character instructions field. Its text is carried as
the permalink `note` and as `CartInput.note` for the hosted fallback. An isolated
live-cart probe confirmed `/cart.js` retained the supplied note; no order/payment
was submitted. Rendering or prefilling it inside Razorpay's plugin remains a
separate end-to-end check. Do not enter passwords or payment credentials here.

## Proposed API handoff is not implemented

A server can validate app cart/customer data and return an expiring checkout
handoff URL, but an API does not itself render a browser modal. A web page must
launch a merchant-supported Magic integration. Razorpay's custom-web documentation
describes order line items, web JavaScript and coupon/shipping callbacks; that is
not evidence of a direct launcher for this account's existing Shopify plugin.
Do not switch the Shopify platform profile or treat native rejection as approval
of a custom-web profile. Contact prefill in the custom integration does not
guarantee delivery address prefill, authenticated Shopify login, or bypass of OTP.
No new Magic API/session or checkout activation was implemented by the note-field
change. Existing merchant settings remain unchanged.

Reference: https://razorpay.com/docs/payments/magic-checkout/web/

## Authenticated hosted-checkout fallback

Fallback Check Out attempts create a Shopify Storefront cart using the actual variant
IDs, quantities, gift attributes and optional discount code. Prices/taxes/shipping
are determined by Shopify. The current Customer Account access token is attached
to buyerIdentity for authenticated checkout, never placed in an app-built URL.

The Shopify-returned HTTPS checkoutUrl opens through url_launcher's
inAppBrowserView (Android Custom Tab / iOS Safari view). This is a hosted web
checkout, not a native Razorpay SDK popup or raw embedded payment WebView.
Payment/UPI handoffs are handled by the browser and the merchant's existing
Shopify payment integration. Actual branding, Razorpay/Magic presentation and
available methods depend on Shopify/Razorpay configuration; identical website
popup behaviour has not been certified by these offline tests.

The old recovery popup and cart-side coupon/quote section have been removed.
Native attempts are checked server-side before migration: confirmed unpaid or
not-started attempts are archived in secure storage and the hosted flow proceeds.
Paid, authorized or ambiguous states remain saved and block a new payment with
an inline message. No server payment ledger or recovery evidence is deleted.
Opening/closing the hosted checkout never marks payment paid
or clears the cart; customers must confirm payment/order status in Shopify orders.
Existing Shopify webhooks/order sync remain responsible for order updates. No
new middleware draft or provider order is created for the hosted path.

No Shopify platform profile, payment key, merchant setting or callback URL was
changed. Native Magic remains disabled. The hosted path talks directly to Shopify;
local middleware is retained only for recovery and other existing app features.

Verification: `flutter test` covers payload preservation, unsafe checkout URLs,
unavailable/changed quantities, coupon rejection and missing authentication.
Actual live checkout/payment must still be checked without submitting a charge
unless the merchant explicitly authorizes it.

References:
- https://shopify.dev/docs/storefronts/mobile/checkout-kit/authenticate-checkouts
- https://pub.dev/documentation/url_launcher/latest/url_launcher/LaunchMode.html
