# Vijay Super Mall (Flutter web): Frontend Consolidated Document

**Audience:** the Flutter/web team and the product owner. The backend team's equivalent is `backend-review/BACKEND_CONSOLIDATED.md` (open backend items) with evidence in `functional-tests/flows/`.
**Date:** 2026-11-09. **Scope:** everything built, fixed, verified and still open in the app during this review cycle.

---

## 1. Status snapshot

| | |
|---|---|
| Target | **Flutter web** (the only target built and verified). Windows needs Visual Studio with the C++ workload, Android needs a JDK: neither is installed on the build machine. |
| Code health | `flutter analyze --no-pub lib`: **0 errors** (about 100 infos/warnings that predate this cycle). |
| Release build | `build/web`, shared zip `release/vijay_super_mall_web_release_20261109.zip` (built 18:18, checksum in section 9). |
| Verified against the live backend | Every customer flow (C1-C8) and admin/cashier flow (A1-A8): about 560 scenarios, documented in `functional-tests/flows/`. |
| **Not verified** | The rendered UI: nobody has looked at the new screens in a browser. UI-only checks are marked "UI-only (not run)" in the flow documents. Section 8 is the visual checklist. |
| Automated tests | Parked by the product owner (no test files in the repo). Live functional validation replaces them for now. |

---

## 2. How to run and build

**Servers (dev):** backend on `:8080`; the dev proxy serves the web build and forwards `/api` and `/img` to the backend (same origin, so no CORS): from `E:\Vijay mall Qoder` run `python proxy.py 8090`, then open `http://localhost:8090`. The proxy writes a per-minute request meter to `proxy.requests.log` (total `/api` calls, 429 count, busiest paths).

**Release build (web):** from `vijay_super_mall`:
```
$env:PATH="E:\flutter\bin;$env:PATH"
flutter build web --release --no-pub --no-wasm-dry-run --dart-define=API_BASE=http://localhost:8090
```
`API_BASE` is mandatory: without it the app starts in the offline demo mode with seed data. After a rebuild, hard-refresh the browser (Ctrl+Shift+R).

**Dev logins (dev profile, OTP always `12345`):** admin `admin@mall.com`; any e-mail becomes a customer; a cashier account exists (`abc@vijaymall.com`).
**Backend limits that affect testing:** 300 `/api` calls per minute per client address (everything behind the proxy is one address); OTP limits are high in dev.

---

## 3. Architecture decisions (what the app now guarantees)

| Area | Behaviour |
|---|---|
| Auth | Bearer token, one silent refresh on 401 (rotated refresh token), session ends cleanly when refresh fails, multipart uploads refresh and retry once, per-install `deviceId`, logout sends the device token when one exists |
| Idempotency | One `Idempotency-Key` per user action, reused on retries (order, POS sale, return, credit repayment, delivery), replaced only when the content changes |
| Errors | Error envelope parsed (`code`, `message`, `traceId`, `details.fields`); field errors highlight the matching inputs on the main forms; 5xx shows `ref <traceId>`; a bare "Bad request" is shown as a readable message with the reference; `503 SERVICE_BUSY` retries once after `Retry-After` (safe calls only); 429 honours `Retry-After` and is never retried in a loop |
| Rate-limit safety | Order list refresh caches each order's detail (re-fetches only when status or total changed), one refresh at a time, 5-300 s back-off on 429; the live-update poller is 45 s |
| Lists | `size` never above 50; paging follows `hasMore`; `10,000+` is shown when `totalExact` is false |
| Caching | ETag/`If-None-Match` for `/shop-settings`, categories, units and hot-sale; the store profile is also persisted (section 4) |
| Money | Exact paise end to end (`₹125.50`, not rounded) |
| Time | All dates shown in India time (UTC+5:30) regardless of the device zone; requests send UTC with `Z` |
| Language | `gt('...')` lookup with Gujarati tables (`gu_strings.dart`, `gu_flash.dart`, `gu_push.dart`, `gu_store.dart`); untranslated strings fall back to English |
| Roles | ADMIN sees everything; CASHIER gets Orders, POS till and Flash sales only (matches the backend's 403s) |
| Orders safety | A live build never shows a success screen for an order the server did not receive; the order screen adopts the server's totals; `COD`/`ONLINE` are the only payment codes sent; the applied coupon is always sent so the server decides |

---

## 4. Store profile (name, logo, address everywhere)

- One `StoreProfile` (from public `GET /shop-settings`) feeds the header, side rail, splash, welcome, sign-in, store info, pickup, tracking, bills, profile footer, Razorpay name and every contact action (call, WhatsApp, map, e-mail, website, Instagram, Facebook). No hardcoded brand remains except the offline demo data.
- **Cache:** persisted in the browser (`store.profile.v1`: payload, ETag, logo bytes up to 200 KB), painted **before the first frame**, then revalidated with a conditional GET; again after 30 minutes away, on the live `SHOP` event and after every admin save. A network failure keeps the cache. The logo is cached by the app because the backend serves images with `no-store` (backend item R2-18).
- **Hard refresh:** customer Profile and the store-info sheet ("Refresh store details"), Admin > Shop settings ("Refresh from server"), Admin > System > Caches ("This device: store details" with Clear).
- **Web branding:** page title, favicon, apple-touch-icon, description and a generated install manifest follow the store; `index.html` sets title and favicon from the cache before Flutter boots. `web/favicon.png` and `web/icons/*` are the old artwork and apply only when the shop has no logo.
- The backend has no Gujarati store fields: the same text is shown in both languages (backend item R2-20).

---

## 5. What was built in this cycle

**Customer:** home flash-sale strip and upcoming teaser; product flash badge, countdown and per-customer limit; coupons sheet with "You save Rs X" per coupon (server preview); order cancel remark beside "ORDER CANCELLED" (track, list, notifications, admin); pay-now card with countdown and online payment on web (Razorpay session, server-confirmed); delete account; address default/delete/phone; order line images; credit (udhar) card on the wallet; coin expiry text; notification routing (orders, products, categories, offers, coins, flash sales); store info sheet.

**Admin / cashier:** Categories (list incl. hidden, image, delete with 409 message), Credit (udhar) accounts and limits, Customers (search, block, coins, orders and ledger), Counter desk (shifts, controls, low stock, audit log, payment problems, returned goods with write-off/return-to-supplier, offline bills, sync status, approval PIN), Flash sales (list, form, start/end/duplicate/cancel, items, reports), Push notifications (history, 4-step broadcast wizard, saved segments), System (refunds, shop profile, configuration, caches, logs), Stock operations (receive stock, stock take), POS extras (returns with refund mode and "damaged: do not restock", credit collection, receipts, manual discount with manager PIN), admin order returns, shop settings and profile editor.

**Look and feel (all screens):** skeleton loaders, KPI cards, hover-row tables on wide screens, sticky action bars, step headers, animated timeline, pull-to-refresh, empty/error states with retry, 44 px tap targets, content width caps. Shared kits: `widgets/skeleton.dart`, `widgets/admin_kit.dart`, `widgets/sheet.dart` (sticky footer, refresh), `widgets/flash_widgets.dart`, `widgets/store_actions.dart`.

---

## 6. Frontend defects fixed (by source)

**Reported during testing:** cancel remark missing on the track page and lists; coupon discount missing in the final bill; order success screen without a server order (staff session or empty refresh); 429 storm on order details; `POST /orders` 400 (wrong payment code); POS "payment mode" 400 (online-order codes sent to the till); inventory showing each variant twice; image only on the first variant; no product delete; low-stock threshold not editable; unit options (kg, item, dozen); store address shown from seed data; POS search without variant details; hot-sale product picker without search; Gujarati only on headings.

**From the guide alignment (13):** idempotency key reuse, session expiry handling, upload refresh, error parsing, page-size cap, ETag for shop settings, Gujarati name fallback, cashier navigation, out-of-stock products hidden from customers (`includeOutOfStock`), wallet ledger kind names, hot-banner and coin-rule saves no longer wiping stored fields, date formats, reviews form only for `canReview`.

**From the functional flows (about 25):**
- *Customer:* rejected profile edit now reverts; sign-out and delete-account clear the basket, coupon and coins; quantity cap 99 (was 999) and 100-line cap enforced; coin "percent of my coins" and "custom N coins" now map to the server's percent exactly; order result uses the server's delivery fee and total; flash-price change at checkout needs a second confirming tap; customer credit view added; coin expiry shown; admin coin history reloads and shows readable kinds; credit amounts reject NaN/infinity/huge values.
- *Admin:* dashboard tiles use the server dashboard once more orders exist than are loaded; POS GST value validated (0/3/5/12/18/28); saving a product with stock no longer forces "available" back on; unit code over 20 characters gets a clear message; editing a coupon keeps its per-customer limit; "no cap" no longer shown as "max Rs 0"; coin max-redeem % can be 0 and a blank field is no longer 0; parking a POS ticket no longer clears it on failure or duplicates holds; the staff screen shows blocked cashiers as blocked; reports show online refunds and net of refunds; stock correction from the product form sends `ADJUST`; weighed-prefix field says 1-2 digits.

**From the admin dashboard validation (product owner, in the browser):** admin/staff title bars differ by role (ADMIN navy with a gold chip, STAFF teal with a white chip) and the customer bar stays white; one aligned top bar at every width with the store name shortened instead of clipping buttons; profile avatar menu (dropdown on desktop, sheet on phone) and an admin/staff profile page at /admin/profile; two-column desktop layouts for cart, checkout, orders, wallet and profile; notification dropdown/sheet no longer cut off (sheets opened from the header were sized to the whole window); dashboard tiles and banners open the right screen already filtered (deep links ?day=, ?view=action|new, ?filter=low|out|active|inactive); order date bar (Today, Yesterday, arrows, calendar); Needs action and New (24h) views; filters and search clear when you leave the screen; inventory chips with counts and out-of-stock/low-stock first; the dashboard's Need action count now uses the same definition as the list (payment-pending orders excluded). Details: unctional-tests/flows/A9-dashboard-actions-filters.md. Backend items S-F1 (no date filter on orders) and S-F2 (one status per request) are in the backend document.

**From the POS, credit, hot sale, purchases and filter validation (product owner, in the browser):**
- *POS:* the till can no longer add or type a quantity above stock (cap with "Only N in stock", also for repeated scans, grams, stepper and resumed holds); the mobile number is optional for cash, UPI and card (a half-typed number used to break the quote and block Charge) and required only for credit, a coupon or coins; "could not remove hold" fixed (the parked-tickets sheet was stale, so a second delete hit a 404 that was treated as a failure); refund works by ticking lines with a quantity limited to sold minus already returned, "Select all", "Refund selected items (N)", and plain messages for nothing selected, too many, already returned and return window passed.
- *Credit:* the screen lists credit-eligible customers (limit above zero) with search, a "With dues" toggle and limit/owes/available per row; on the till, choosing Credit shows the customer's limit, owes and available or the exact reason credit is not possible; an admin gets one-click "Enable credit for <customer>" with an editable limit (default Rs 5,000); a cashier sees "Ask an admin" (backend item S-G2); POS has a credit-customer picker.
- *Hot sale:* configured per sale (sale card with live switch and India-time window); items inherit the sale window, can be overridden or reset, and can be removed (or all removed); "Apply to all items that use the sale window". Recommendation (not built): merge it into Flash sales.
- *Purchases:* vendor suggestions as you type (derived from past purchases, no suppliers endpoint yet); the receive form and deliveries search have Clear; **payment tracking (Paid / Part paid / Pending / Overdue) is not built because the backend cannot store it (S-H1)**.
- *Filters:* shop search X and "Clear filters" now reset everything (search text, category, hot sale, sort, toggles); header search no longer keeps stale text; customer order status chip no longer resets on live updates; admin customers got "Clear search" and queued searches; flash-sale list ignores stale responses; counter desk audit Clear, stock report "Reset to today"; deep links that change a tab or filter work on an already-open screen. Orders and inventory (previous pass) were re-verified in code.
- *Icon tiles:* equal-height tile rows (KPI grid, dashboard quick tiles, product promise, profile and counter-desk stats), icon buttons stay square, bottom-nav badge anchored to its icon, store logo uses contain (no cropping). Real appearance at 360/390 px and 900 px or wider was not seen: tell us the screen and width if anything still looks wrong.
- Details: `functional-tests/flows/A10-pos-credit-fixes.md`, `A11-hot-sale-purchases.md`, `A12-filters-and-icon-tiles.md`.

**Title bar hover fix:** hovering the profile avatar made the title bar collapse to just the logo and the bell, and the bell's hover label was cut off. Cause: the site header is built above the Navigator (no `Overlay` ancestor), so the avatar's `Tooltip` threw on hover, and the bell's inline label was painted below the 64 px bar where the page covered it. Fix: a small `HoverLabel` (`lib/widgets/hover_label.dart`) draws the label in the root navigator's overlay (never throws, never clipped, stays inside the window, flips above when there is no room). Rule for the team: **never use `Tooltip` in the site header or other widgets built above the Navigator**; use `HoverLabel`.

**POS counter and cashier shift redesigned to the design samples (`pos and cahier/`):** the till (`admin_pos_screen.dart`) now follows `POS counter-html`: teal staff bar (Console, logo, "Shift open · since · float" pill, Close/Start shift), a large scan/search field with English / Gujarati tabs and tap-to-add product tiles on the left, and one "Current bill" card on the right (Hold / Held / Clear, customer mobile with coupon and customer box, bill lines with - qty +, "Give a discount" panel, totals with GST and round-off, big "To pay", Cash / UPI / Card / Udhar buttons, cash received with Exact / 500 / 1,000 / 2,000 and change line, UPI box, credit panel, big Charge, Find old bill / Return, Take credit repayment, Today's totals). After a charge the card shows the "Paid" panel with Print receipt and Start next sale. All existing till logic is unchanged (stock cap, idempotent sale key, quotes, credit checks, holds, split payments - folded under "Split this payment"). The cash drawer is now a full page, `#/admin/shift` (`admin_shift_screen.dart`), following `Cashier shift-html`: Start your shift, Close your shift (expected cash, counted, short/over box, note when it does not match) and Shift closed; a till sale with no open shift sends the cashier there. Not in the sample because the backend has no such data: counter choice (no counters in the API) and the cash-sales / repayments / returns breakdown (the shift only exposes opening float and expected cash).

---

## 7. Open frontend items

**Fixed in the final pass (all items the flow testing left open):**
- **Price-change guard (P2):** the quote total minus the delivery fee is compared with the total the customer saw; if it is higher the order is not placed and the customer sees "The price changed - total is now Rs X. Tap Place order again to confirm"; the second tap sends that quoted total. A lower total proceeds. Checkout shows the delivery fee and server total when a fee applies. (A 1-paise rounding difference costs one extra confirming tap, never a wrong charge.)
- **Deactivated basket line:** the "product is not available" 400 now removes the named line, tells the customer which item went, and re-runs the quote.
- **Admin order status chips:** they call `GET /admin/orders?status=` and "Load more" pages within that status.
- **Return dialog key:** already correct (one key per identical request until it succeeds or is refused); the flow document row was stale and is corrected.
- **Coin settings and rules:** success is shown only after the server answers; on an error the server values are reloaded and rule toggles roll back.
- **Unlimited coupons:** unlimited is sent as `totalLimit: 0` (documented), a blank "Max uses" means unlimited, and the list shows an infinity sign.
- **POS till:** Charge compares typed quantity with stock for non-weighed items and names the short item; a second press still goes through so the server's 409 is shown (a hard block would prevent selling when the shelf count is wrong).
- **Reports:** "Today" uses the server summary for today's date; the Revenue tab uses the 30-day summary plus a 12-month range (the server limit is 366 days); the "All time" panel is now titled "Last 12 months". Removing the logo asks for confirmation.
- **Customer extras:** a failed mark-read re-reads the inbox from the server; the review form keeps the posted values; the redundant promote PUT is gone; the address list is re-read after deleting the default.
- **Admin customers and credit:** credit adjust and limit change ask for confirmation; approving by mobile checks for 10 digits first.
- New shared pieces: `lib/widgets/confirm.dart` (confirm dialog) and `lib/state/gu_followup.dart` (Gujarati strings).

**Still open (by design):** `F-C8-2`: the flash-sale cart total is a local estimate while the server quote stays authoritative.

**Not built / known limits:**
- **Purchase payment tracking** (paid / pending / due) waits for backend item S-H1; supplier suggestions are derived from past purchases until S-H2 exists; cashiers cannot enable credit until S-G2 is decided.
- Offline POS (the till has no offline mode; only the sync status is shown); manager-PIN discount path for cashiers was not exercised.
- Push: no FCM client, so no device registration and no tap handling (also needs backend item P-1).
- Razorpay on native mobile (needs the `razorpay_flutter` package); online payment is web only and untested end to end because ONLINE is not enabled on the dev server.
- Tokens are in plain browser `localStorage` (no secure storage on web); a mobile build would need secure storage first.
- No print buttons for receipts (show and copy only).
- Cart screen does not yet show "x of y at sale price" per line (the quote fields are parsed).
- Gujarati: long help paragraphs and some dynamic sentences stay English.
- Windows/Android builds are blocked by missing toolchains on the build machine.

---

## 8. Visual checklist for the product owner (nothing below has been looked at in a browser)

1. **Stock report:** a bad edit removed several widgets and they were rewritten from their call sites: check the Report tab, the "Choose date" button and the day chips first.
2. **Product edit:** section cards, pack cards with per-row errors, sticky save bar.
3. **Checkout:** step headers, payment option cards, sticky total bar, price-change message.
4. **Header and store info:** logo or letter badge, name, address, hours table, contact buttons, hard-refresh buttons; browser tab title and icon.
5. **Home, product, cart:** flash strip, flash badge and countdown, stock pills.
6. **Admin dashboard, orders, inventory, POS (wide screen):** KPI cards, tables, two-panel till, change-due box.
7. **New admin screens:** Categories, Credit, Customers, Counter desk, Flash sales, Push, System.
8. **Sign-in:** two-step indicator, OTP boxes (red on a rejected code), resend countdown.
9. **Gujarati:** switch language and walk the customer flow once.

---

## 9. Final pass and release

- **Analyzer:** `flutter analyze --no-pub lib`: **0 errors** (98 infos, none new).
- **Release build:** built 2026-11-09 18:18 with `--release --dart-define=API_BASE=http://localhost:8090`; no source file is newer than the build.
- **Share zip:** `vijay_super_mall/release/vijay_super_mall_web_release_20261109.zip`, 14.40 MB, SHA-256 `00E327B3F23F2F6C124D36658EEC35FABDD01A7E58B6D3D216FF3956F60B7CBB`.
- **Served at:** `http://localhost:8090` (hard-refresh with Ctrl+Shift+R).
- **Request load seen through the proxy meter** (real browser use after the fixes): 3 to 14 backend calls a minute with no 429, against the backend's limit of 300. Before the order-detail cache the order list alone could issue 21 calls per refresh.
- **Not yet done:** a visual pass by the product owner (section 8) and an end-to-end ONLINE payment test (needs ONLINE enabled and a configured gateway on the backend).

---

## 10. Where everything lives

| What | Where |
|---|---|
| App | `E:\Vijay mall Qoder\vijay_super_mall` (not a git repository) |
| Backend findings (one document) | `backend-review/BACKEND_CONSOLIDATED.md`; the same file is committed in the backend repo at `docs/frontend-review/` on branch `frontend-review-round2` (not pushed) |
| Per-flow functional documents (21 + summaries) | `functional-tests/flows/` (also in the backend repo under `docs/frontend-review/flows/`) |
| Status notes of the larger modules | `backend-review/flash-sales-status.md`, `push-status.md`, `store-profile-status.md`, `admin-leftovers-status.md` |
| Release zip | `vijay_super_mall/release/` |
| Dev proxy and request meter | `proxy.py`, `proxy.requests.log` in `E:\Vijay mall Qoder` |
| Test data left in the dev backend | Listed in each `functional-tests/flows/_summary-*.md` and in section 5 of the backend document. All test products are inactive; orders and POS records cannot be deleted through the API. |
