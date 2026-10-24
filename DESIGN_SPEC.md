# Vijay Super Mall – Design Handoff (for OpenCode / developers)

Source of truth: `design-source.html` (open in a browser; all CSS tokens are in `:root`).
Reference images: `screens/` (19 frames, 390×844 @2x) and `boards/` (full boards).
Note: PNGs were rendered without the web fonts installed, so typefaces are fallbacks. Use the fonts below.

## Apps and screens
Customer app: 01 Splash, 02 Welcome, 03 Sign in, 04 Home, 05 Products, 06 Product detail, 07 Cart, 08 Checkout, 09 Order placed, 10 Tracking, 11 Wallet
Admin app: A1 Dashboard, A2 Orders, A3 Order detail, A4 Inventory, A5 Edit product, A6 Hot Sale, A7 Coin earning rules, A8 Coupons

## Design tokens
Colors: red #D3202B (2: #EE4A52, 3: #B3121C, tint #FDE8E9) · navy #1F2A6B (2: #3447B5, deep: #121A47, tint #E8EBF8) · maroon #5E0F18 / #8E1B1B · gold #F5B301 (2: #FFD66B, ink #7A4B00, tint #FFF1C8) · green #12875A (tint #DDF3E8) · orange #F26B1D · ink #14162B / #565A78 / #8A8EA8 · line #E4E6F1 · bg #F4F5FB
Fonts: Plus Jakarta Sans (UI), DM Serif Display (display), Hind Vadodara (Gujarati text)
Radii: screen 40, panel 24, button 18 (small 13), chip/pill fully rounded
Sizes: button 54 (small 40), chip 36, pill 24 (large 34), status bar 46
Glass: fill rgba(255,255,255,.72), 1px border rgba(255,255,255,.85), blur 22 + saturate 1.5
Shadows: sh-1 `0 1px 2px rgba(20,22,43,.06),0 6px 18px rgba(31,42,107,.08)` · sh-2 `0 2px 6px rgba(20,22,43,.06),0 20px 44px rgba(31,42,107,.18)` · sh-red `0 10px 24px rgba(211,32,43,.35)`
Primary button gradient: 135° #EE4A52 → #D3202B 60% → #B3121C

## Product notes visible in the design
Bilingual (English + Gujarati) labels, ₹ currency, coins/wallet loyalty (e.g. spend ₹1,000 get 10 coins), Hot Sale pricing, coupons, order tracking.

## Suggested prompt for OpenCode
"Read DESIGN_SPEC.md and design-source.html. Build the customer app and admin app screens listed, matching the PNGs in screens/. Put the tokens in a shared theme file and build reusable Button, Chip, Pill and GlassPanel components first."
