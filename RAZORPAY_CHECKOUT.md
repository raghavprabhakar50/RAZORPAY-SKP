# App / middleware native checkout

Cart Check Out calls the authenticated middleware quote/start endpoints and
opens the official Razorpay Android/iOS SDK without a separate checkout page.
The screenshot's Shopify Magic Checkout (contact/address/payment steps) is a
different product/integration; this implementation does not reproduce that UI
or change the existing Shopify Razorpay integration.

The backend determines the order ID, mode and final amount. SDK callbacks are
verified by middleware; the app does not trust a local paid flag. Shared payment
tokens, Shopify Admin credentials and Razorpay secrets are never sent in builds.
Customer login and a completed delivery profile are required. Double taps are
blocked and saved provider orders/callbacks recover after cancellation/timeouts.
The cart is retained; no items are deleted on an unverified payment.

Cart accepts a Shopify discount code before a new checkout. Middleware applies
it alongside eligible automatic discounts and exposes Shopify's actual discount
amount/codes in the final quote. The app displays these separately from native
Razorpay bank/UPI offers. A saved payment retains its original cart/code and
cannot silently be repriced during recovery. Existing saved quotes may not have
discount breakdown fields; no historical saving is invented.

API root defaults to https://shri-middleware.ekarigar.com and may be overridden:

```powershell
flutter run --dart-define="SKP_MIDDLEWARE_BASE_URL=http://10.0.2.2/Sri%20Krishna%20Pearls%20Middleware"
```

Local HTTP is debug-only. API calls do not follow redirects with customer tokens.
Rebuild/reinstall after SDK changes; hot reload cannot add the native plugin.

## Verified 2026-10-17

Session follow-up: signed-in startup skips onboarding, expired access tokens
refresh non-interactively using the saved refresh token. Public probes with
and without a deliberately invalid Bearer token both returned the missing-token
message. Local middleware now preserves Apache Authorization and reads CGI
HTTP_AUTHORIZATION/REDIRECT_HTTP_AUTHORIZATION before rejecting a request.
Deploy `.htaccess` and `application/controllers/Mobile_checkout.php` to the public
middleware (and forward Authorization in nginx/PHP-FPM if applicable). This is
not an authentication bypass: Shopify still validates the customer on each call.

- Mocked native SDK, server-priced amount, signature handoff, cancel recovery,
  mode/key validation, HTML API rejection and saved state tests pass.
- Public middleware unauthenticated quote/start/verify/status routes return
  401 JSON. This does not certify configured keys or a signed-in payment.
- Local middleware has matching live credentials and required Shopify scopes,
  but live activation flags remain off. No live transaction was charged.
- Actual native checkout against the activated backend and signed provider
  webhook fulfillment still need end-to-end verification. Do not treat
  successful compilation/unit tests as payment certification.
