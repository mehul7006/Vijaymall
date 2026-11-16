import 'package:web/web.dart' as web;

/// Opens [url] in the browser. `tel:` / `mailto:` navigate the current tab
/// (the OS hands them to the dialler / mail app); web links open a new tab.
bool openLink(String url) {
  try {
    if (url.startsWith('tel:') || url.startsWith('mailto:')) {
      web.window.location.href = url;
    } else {
      web.window.open(url, '_blank', 'noopener');
    }
    return true;
  } catch (_) {
    return false;
  }
}
