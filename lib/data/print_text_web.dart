import 'dart:js_interop';

import 'package:web/web.dart' as web;

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Opens a small window holding [text] in a fixed-width font sized for the
/// paper ([width] 32 = 58 mm, 48 = 80 mm) and starts the browser print dialog.
/// Returns false when the browser blocked the window.
bool printText(String text, {int width = 32, String title = 'Receipt'}) {
  try {
    final w = web.window.open('', '_blank');
    if (w == null) return false;
    final mm = width >= 48 ? 80 : 58;
    final html = '<!doctype html><html><head><meta charset="utf-8">'
        '<title>${_esc(title)}</title>'
        '<style>@page{size:${mm}mm auto;margin:2mm}'
        'html,body{margin:0;padding:0;background:#fff;color:#000}'
        'pre{font:12px/1.35 "Courier New",monospace;margin:0;padding:4px;'
        'white-space:pre;width:${width}ch}</style></head>'
        '<body><pre>${_esc(text)}</pre>'
        '<script>window.onload=function(){window.focus();window.print();};'
        '</script></body></html>';
    w.document.open();
    w.document.write(html.toJS);
    w.document.close();
    return true;
  } catch (_) {
    return false;
  }
}
