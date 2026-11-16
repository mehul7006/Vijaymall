/// Web-only branding side effects (document title, favicon, touch icon, meta
/// description, PWA manifest) driven by the store profile. Every other
/// platform gets the no-op in `store_branding_stub.dart`.
export 'store_branding_stub.dart'
    if (dart.library.js_interop) 'store_branding_web.dart';
