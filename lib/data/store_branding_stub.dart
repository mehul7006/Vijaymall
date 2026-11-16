/// No-op branding for non-web platforms.
class StoreBranding {
  StoreBranding._();

  static void apply({
    required String name,
    required String tagline,
    required String logoUrl,
    String iconUrl = '',
    String icon192Url = '',
  }) {}
}
