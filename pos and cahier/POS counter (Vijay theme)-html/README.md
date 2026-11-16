# POS counter — design reference

This is a design mockup created in a visual design tool, exported as a
standalone page. Treat it as a REFERENCE MOCKUP, not production code:
the markup and inline styles carry the design's precise values — colors,
font sizes, spacing, radii, shadows, layout — which an implementation
should replicate faithfully in its own components and styling system
rather than copy wholesale.

## Contents

- `POS.dc.html` — the artboard (a Design Component: an `<x-dc>`
  template + a small logic class). The values to replicate live in its
  inline `style="…"` attributes and the `<helmet><style>` block.
- `support.js`, `vendor/react*.js` — the runtime that renders the
  component in a browser; not part of the design.

## Viewing

Serve the folder (e.g. `python3 -m http.server`) and open `POS.dc.html`;
some browsers block the scripts over file://.

## Vijay Super Mall theme

Same structure, layout, copy and behaviour as the original sample; only colours and fonts are changed to the site's design tokens (`lib/theme/app_colors.dart`): brand red primary actions, navy selected states, teal cashier top bar, gold focus and highlights, Plus Jakarta Sans / DM Serif Display / Hind Vadodara (bundled in `fonts/`, no internet needed).
