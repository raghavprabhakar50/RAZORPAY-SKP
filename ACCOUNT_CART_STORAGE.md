# Account-isolated carts

Cart storage is local to this device, keyed by verified Shopify Customer GID.
Guest items merge once into the next authenticated customer, matching gift-aware
line keys and adding quantities. The guest cart is then consumed. Logout switches
to a separate guest cart immediately; switching A to B never merges A's cart into
B. Returning to A restores A's own saved cart (not an always-empty cart).

Startup disk restoration replays account switches and edits made while storage
was loading. This avoids overwriting early guest additions or merging a persisted
guest cart twice. Authenticated sessions without a verified customer GID do not
claim the guest cart by email/name.

`shopping_cart_accounts_v2` contains scoped cart snapshots in secure storage.
The old global `shopping_store_v1.cart` had no ownership metadata. It is retained
as an unassigned legacy backup, but not automatically displayed or given to the
next user. Existing legacy items may therefore not appear immediately after this
update; they are not deleted. The previous wishlist behaviour is unchanged.

This does not sync carts between phones and does not change Shopify checkout,
orders, credentials or middleware payment mappings. No login credentials/tokens
are stored inside cart payloads. Tests cover guest transfer, account switching,
gift variants, quantity merge, restart ownership and startup races.
