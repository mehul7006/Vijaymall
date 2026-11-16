import 'package:flutter/foundation.dart';

import 'api/api_exception.dart';
import 'api/api_service.dart';
import 'api/label_api.dart';
import 'api/label_dto.dart';
import 'local_store.dart';

/// Cache of the label templates plus the per-device choices the guide asks to
/// remember (last template, last output mode).
class LabelStore extends ChangeNotifier {
  LabelStore._();
  static final LabelStore instance = LabelStore._();

  static const _kTemplate = 'vsm.label.template';
  static const _kMode = 'vsm.label.mode';

  LabelApi? _api;
  LabelApi get api => _api ??= LabelApi(Api.instance.client);

  List<LabelTemplate> templates = const [];
  bool loaded = false;
  bool loading = false;
  String? error;

  String? get lastTemplateId => LocalStore.get(_kTemplate);
  set lastTemplateId(String? v) {
    if (v == null) {
      LocalStore.remove(_kTemplate);
    } else {
      LocalStore.set(_kTemplate, v);
    }
  }

  String get lastMode => LocalStore.get(_kMode) ?? 'PDF';
  set lastMode(String v) => LocalStore.set(_kMode, v);

  LabelTemplate? byId(String? id) {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Loads every template (the server has few; page size 50).
  Future<void> load({bool force = false}) async {
    if (loading || (loaded && !force)) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final all = <LabelTemplate>[];
      var page = 0;
      while (true) {
        final r = await api.templates(page: page, size: 50);
        all.addAll(r.items);
        if (!r.hasMore || r.items.isEmpty || page > 20) break;
        page++;
      }
      templates = all;
      loaded = true;
    } on ApiException catch (e) {
      error = e.messageWithRef;
    } catch (_) {
      error = 'Could not reach the server. Please try again.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
