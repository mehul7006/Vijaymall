/// Inline SVG icon library — port of assets/icons.js (`P` map + `icon()` + `logo()`).
///
/// Icons are stroke-based 24×24 SVGs rendered with flutter_svg. The stroke
/// width used across the design is 1.8 (`1.5` where noted in screens).
class AppIcons {
  AppIcons._();

  static const Map<String, String> _paths = {
    'home':
        '<path d="M3.5 10.6 12 3.5l8.5 7.1"/><path d="M5.5 9.2v10.3a1 1 0 0 0 1 1h3.7v-5.6h3.6v5.6h3.7a1 1 0 0 0 1-1V9.2"/>',
    'grid':
        '<rect x="4" y="4" width="6" height="6" rx="1.8"/><rect x="14" y="4" width="6" height="6" rx="1.8"/><rect x="4" y="14" width="6" height="6" rx="1.8"/><rect x="14" y="14" width="6" height="6" rx="1.8"/>',
    'cart':
        '<path d="M3 4h2.2l2.1 10.2a2 2 0 0 0 2 1.6h7.5a2 2 0 0 0 2-1.5L20.4 8H6"/><circle cx="9.3" cy="19.5" r="1.4"/><circle cx="17.3" cy="19.5" r="1.4"/>',
    'wallet':
        '<path d="M4 7.5A2.5 2.5 0 0 1 6.5 5H18a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H6.5A2.5 2.5 0 0 1 4 17.5Z"/><path d="M4 8h15.2"/><path d="M20 12h-5a2 2 0 0 0 0 4h5"/>',
    'user': '<circle cx="12" cy="8" r="3.6"/><path d="M4.8 20a7.2 7.2 0 0 1 14.4 0"/>',
    'search': '<circle cx="11" cy="11" r="6.6"/><path d="m16 16 4.2 4.2"/>',
    'filter': '<path d="M4 6h16"/><path d="M7 12h10"/><path d="M10 18h4"/>',
    'bell':
        '<path d="M18 9.7a6 6 0 1 0-12 0c0 5-2 6.3-2 6.3h16s-2-1.3-2-6.3"/><path d="M10 20a2.2 2.2 0 0 0 4 0"/>',
    'back': '<path d="m14.5 5-7 7 7 7"/>',
    'right': '<path d="m9.5 5 7 7-7 7"/>',
    'down': '<path d="m5 9.5 7 7 7-7"/>',
    'up': '<path d="m5 14.5 7-7 7 7"/>',
    'heart':
        '<path d="M12 20.3S4 15.6 4 9.8A4.4 4.4 0 0 1 12 7a4.4 4.4 0 0 1 8 2.8c0 5.8-8 10.5-8 10.5Z"/>',
    'star':
        '<path fill="currentColor" stroke="none" d="m12 2.7 2.8 5.7 6.3.9-4.6 4.4 1.1 6.3-5.6-3-5.6 3 1.1-6.3L3 9.3l6.2-.9Z"/>',
    'plus': '<path d="M12 5v14M5 12h14"/>',
    'minus': '<path d="M5 12h14"/>',
    'pin': '<path d="M20 10.5c0 5.4-8 11-8 11s-8-5.6-8-11a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10.3" r="2.6"/>',
    'phone':
        '<path d="M6.4 3.5h3.1l1.6 4-2 1.4a13 13 0 0 0 6 6l1.4-2 4 1.6v3.1a2 2 0 0 1-2.2 2A17.5 17.5 0 0 1 4.4 5.7a2 2 0 0 1 2-2.2Z"/>',
    'whatsapp':
        '<path d="M20.2 11.6a8.2 8.2 0 0 1-12.1 7.2L3.8 20l1.2-4.2a8.2 8.2 0 1 1 15.2-4.2Z"/><path d="M8.7 7.7c-.2.5-.4 1.3.4 2.4a8.7 8.7 0 0 0 4.6 3.7c1.2.4 1.7 0 2.1-.4l.7-.8-2.1-1-.7.8a6.4 6.4 0 0 1-2.9-2.8l.8-.7-1-2.1-.9.1a1.7 1.7 0 0 0-1 .8Z"/>',
    'box':
        '<path d="M20.5 8 12 3.3 3.5 8v8L12 20.7 20.5 16V8Z"/><path d="M3.7 8.1 12 12.7l8.3-4.6M12 20.5v-7.8"/>',
    'coin': '<circle cx="12" cy="12" r="8.4"/><path d="M9 8.6a3.4 3.4 0 0 0 0 6.8h6M9.4 12h5.2M12 7v10"/>',
    'ticket':
        '<path d="M4 7.5a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2V10a2.2 2.2 0 0 0 0 4v2.5a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V14a2.2 2.2 0 0 0 0-4V7.5Z"/><path d="M14 5.5v13" stroke-dasharray="2.5 3"/>',
    'flame':
        '<path d="M12 21c4 0 6.5-2.5 6.5-6 0-3-1.8-5.1-3.4-7.1C13.7 6 13 4.2 13 2.5c-2.7 1.5-4.3 4-4.3 6.4 0 1.2.4 2 .4 2S7 9.7 6.3 7.3C5 9.2 4.5 10.9 4.5 12.7 4.5 17.3 7.3 21 12 21Z"/><path d="M12 21c-1.8 0-3-1.3-3-3 0-1.4.9-2.4 1.9-3.5.7-.8 1.1-1.5 1.1-2.5 1.8 1.3 3 2.9 3 4.5 0 2.5-1.4 4.5-3 4.5Z"/>',
    'settings':
        '<circle cx="12" cy="12" r="3.1"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.5v.2h-4v-.2a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.5-1H2.9v-4h.2a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1a1.7 1.7 0 0 0 1.9.3 1.7 1.7 0 0 0 1-1.5v-.2h4v.2a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.9-.3L17 4.2 19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.5 1h.2v4h-.2a1.7 1.7 0 0 0-1.5 1Z"/>',
    'chart': '<path d="M5 20V10M12 20V4M19 20v-7"/>',
    'check': '<path d="m5 12.5 4.4 4.4L19 7"/>',
    'close': '<path d="M6 6l12 12M18 6 6 18"/>',
    'share':
        '<circle cx="18" cy="5.5" r="2.5"/><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="18.5" r="2.5"/><path d="m8.2 10.8 7.6-4M8.2 13.2l7.6 4"/>',
    'truck':
        '<path d="M3 6.5h11v11H3z"/><path d="M14 10h4l3 3v4.5h-7"/><circle cx="7" cy="18.5" r="1.8"/><circle cx="17.5" cy="18.5" r="1.8"/>',
    'store':
        '<path d="M4 10v9.5h16V10"/><path d="M3 10 5 4h14l2 6"/><path d="M3 10a3 3 0 0 0 5 2 3 3 0 0 0 4 0 3 3 0 0 0 4 0 3 3 0 0 0 5-2"/><path d="M9.5 19.5v-5h5v5"/>',
    'card': '<rect x="3" y="5.5" width="18" height="13" rx="2.5"/><path d="M3 9.5h18M7 14.5h4"/>',
    'cash': '<rect x="3" y="6" width="18" height="12" rx="2.5"/><circle cx="12" cy="12" r="2.7"/><path d="M6.5 9v6M17.5 9v6"/>',
    'clock': '<circle cx="12" cy="12" r="8.5"/><path d="M12 7v5.4l3.5 2"/>',
    'edit': '<path d="M4 20h4l11-11a2.8 2.8 0 0 0-4-4L4 16v4Z"/><path d="m13.5 6.5 4 4"/>',
    'trash': '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/><path d="M10 11v5M14 11v5"/>',
    'logout': '<path d="M10 4H5v16h5"/><path d="M14 8l4 4-4 4M18 12H9"/>',
    'info': '<circle cx="12" cy="12" r="8.5"/><path d="M12 11v6M12 7.5v.5"/>',
    'shield': '<path d="M12 3 5 6v5.5c0 4.4 3 7.8 7 9.5 4-1.7 7-5.1 7-9.5V6l-7-3Z"/><path d="m9 12 2 2 4-4"/>',
    'spark':
        '<path d="M12 3v4M12 17v4M3 12h4M17 12h4M5.6 5.6l2.8 2.8M15.6 15.6l2.8 2.8M18.4 5.6l-2.8 2.8M8.4 15.6l-2.8 2.8"/>',
    'arrow': '<path d="M4 12h16M14 6l6 6-6 6"/>',
    'more':
        '<circle cx="5" cy="12" r="1.4" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.4" fill="currentColor" stroke="none"/><circle cx="19" cy="12" r="1.4" fill="currentColor" stroke="none"/>',
    'percent': '<path d="M19 5 5 19"/><circle cx="7.5" cy="7.5" r="2.5"/><circle cx="16.5" cy="16.5" r="2.5"/>',
    'bag': '<path d="M5.5 8h13l-1.2 12H6.7L5.5 8Z"/><path d="M9 8V6.2a3 3 0 0 1 6 0V8"/>',
    'gift':
        '<rect x="4" y="9" width="16" height="11" rx="2"/><path d="M3 9h18v4H3zM12 9v11"/><path d="M12 9C9 9 7 7.7 7 6.2A2.2 2.2 0 0 1 9.2 4C10.9 4 12 6 12 9ZM12 9c3 0 5-1.3 5-2.8A2.2 2.2 0 0 0 14.8 4C13.1 4 12 6 12 9Z"/>',
    'bolt': '<path d="M13 2 5 14h6l-1 8 8-12h-6l1-8Z"/>',
    'refresh': '<path d="M20 11a8 8 0 0 0-14.7-4M4 5v5h5M4 13a8 8 0 0 0 14.7 4M20 19v-5h-5"/>',
    'users':
        '<circle cx="9" cy="8" r="3.4"/><path d="M3 19a6 6 0 0 1 12 0"/><path d="M16 5.2a3.4 3.4 0 0 1 0 6.6M17.5 14.2A6 6 0 0 1 21 19"/>',
  };

  static bool has(String name) => _paths.containsKey(name);

  /// Builds the same `<svg>` string the prototype's `icon()` helper produced.
  /// [color] replaces `currentColor`; falls back to the `info` icon like the JS.
  static String svg(String name, {double size = 20, double sw = 1.8, String color = 'currentColor'}) {
    final path = _paths[name] ?? _paths['info']!;
    return '<svg width="$size" height="$size" viewBox="0 0 24 24" fill="none" '
        'stroke="$color" stroke-width="$sw" stroke-linecap="round" stroke-linejoin="round">'
        '$path</svg>';
  }

  /// Store logo (48×48 cart + sparkle + wheels), colorable.
  static String logoSvg({double size = 44, String color = 'currentColor'}) {
    return '<svg width="$size" height="$size" viewBox="0 0 48 48" fill="none">'
        '<path d="M13 15.5h22l-2.5 15.2a4.2 4.2 0 0 1-4.1 3.5h-8.8a4.2 4.2 0 0 1-4.1-3.5L13 15.5Z" stroke="$color" stroke-width="2.4" stroke-linejoin="round"/>'
        '<path d="M14 15.5 12 9h-4" stroke="$color" stroke-width="2.4" stroke-linecap="round"/>'
        '<circle cx="19" cy="39" r="2.2" fill="$color"/>'
        '<circle cx="31" cy="39" r="2.2" fill="$color"/>'
        '<path d="M24 8V2.5M24 2.5l-2.4 2.4M24 2.5l2.4 2.4" stroke="$color" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>'
        '<path d="M21.5 22.5c1.5-1 4.5-1 5 1.2.5 2-1.4 3.6-4.5 3.6-3 0-4.6-1.6-4.2-3.5.4-1.9 2.4-2.4 3.7-1.3Z" stroke="$color" stroke-width="1.7" stroke-linejoin="round"/>'
        '</svg>';
  }
}
