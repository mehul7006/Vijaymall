import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';
import 'session_store.dart';

/// Low-level HTTP talker for the Vijay Super Mall backend.
///
/// Responsibilities:
///  * prefix every call with `/api/v1`
///  * attach `Authorization: Bearer <jwt>`
///  * silently refresh the access token on a single 401 and retry once
///  * turn non-2xx responses into a typed [ApiException]
///  * generate `Idempotency-Key` values for POSTs that need them
class ApiClient {
  ApiClient({http.Client? httpClient, SessionStore? session})
      : _http = httpClient ?? http.Client(),
        _session = session ?? SessionStore.instance;

  final http.Client _http;
  final SessionStore _session;

  /// In-flight refresh, shared so parallel 401s only refresh once.
  Future<bool>? _refreshing;

  /// True when the last refresh was refused by the server (as opposed to a
  /// network failure): the session is dead and the user must sign in again.
  bool _refreshRejected = false;

  /// Called (once) after a refresh was refused and the stored tokens were
  /// wiped, so the app can drop to the sign-in state.
  void Function()? onSessionExpired;

  /// Idempotency keys of actions still in flight or retryable, by request
  /// fingerprint. One key per user action: kept across retries (timeout,
  /// network drop, 5xx, 429), dropped once the action succeeds or the server
  /// definitively rejects it, so the next genuine action gets a fresh key.
  final Map<String, String> _idemKeys = <String, String>{};

  static const int maxPageSize = 50;
  static const int maxUploadBytes = 5 * 1024 * 1024;

  // ---------------------------------------------------------------------------
  // Public verbs
  // ---------------------------------------------------------------------------

  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? query,
    bool authRequired = true,
    Map<String, String>? headers,
  }) =>
      _send('GET', endpoint,
          query: query, authRequired: authRequired, headers: headers);

  /// Conditional GET (`If-None-Match`). Returns `(notModified, body, etag)`:
  /// on 304 `notModified` is true and `body` is null (keep the cached copy).
  Future<({bool notModified, dynamic body, String? etag})> getConditional(
    String endpoint, {
    String? etag,
    bool authRequired = false,
    Map<String, String>? query,
  }) async {
    final uri = _uri(endpoint, query);
    final hdrs = {
      'Accept': 'application/json',
      if (authRequired) ..._authHeaders(),
      if (etag != null && etag.isNotEmpty) 'If-None-Match': etag,
    };
    final resp = await _attempt('GET', uri, null, hdrs);
    if (resp.statusCode == 304) {
      return (notModified: true, body: null, etag: etag);
    }
    final body = _handle(uri, resp, authRequired: authRequired);
    return (notModified: false, body: body, etag: resp.headers['etag']);
  }

  Future<dynamic> post(
    String endpoint, {
    Object? body,
    Map<String, String>? query,
    bool authRequired = true,
    Map<String, String>? headers,
    bool idempotency = false,
  }) async {
    // A caller that already keeps one key per user action passes its own.
    final callerKey = headers?.keys
        .any((k) => k.toLowerCase() == 'idempotency-key') ?? false;
    if (!idempotency || callerKey) {
      return _send('POST', endpoint,
          body: body, query: query, authRequired: authRequired, headers: headers);
    }
    final fp = '$endpoint|${jsonEncode(query ?? const {})}|'
        '${body == null ? '' : jsonEncode(body)}';
    final key = _idemKeys.putIfAbsent(fp, newIdempotencyKey);
    try {
      final r = await _send('POST', endpoint,
          body: body,
          query: query,
          authRequired: authRequired,
          headers: {...?headers, 'Idempotency-Key': key});
      _idemKeys.remove(fp);
      return r;
    } on ApiException catch (e) {
      // Keep the key when the outcome is unknown or retryable (network,
      // timeout, 5xx, 401, 408, 429, in-progress 409) so the retry is the
      // SAME action; drop it on a definite rejection.
      final retryable = e.statusCode == 0 ||
          e.statusCode >= 500 ||
          e.statusCode == 401 ||
          e.statusCode == 408 ||
          e.statusCode == 429 ||
          (e.statusCode == 409 &&
              (e.code ?? '').toUpperCase().contains('IDEMPOTEN'));
      if (!retryable) _idemKeys.remove(fp);
      rethrow;
    }
  }

  Future<dynamic> put(
    String endpoint, {
    Object? body,
    Map<String, String>? query,
    bool authRequired = true,
    Map<String, String>? headers,
  }) =>
      _send('PUT', endpoint,
          body: body, query: query, authRequired: authRequired, headers: headers);

  Future<dynamic> patch(
    String endpoint, {
    Object? body,
    bool authRequired = true,
    Map<String, String>? headers,
  }) =>
      _send('PATCH', endpoint,
          body: body, authRequired: authRequired, headers: headers);

  Future<void> delete(
    String endpoint, {
    bool authRequired = true,
    Map<String, String>? headers,
  }) =>
      _send('DELETE', endpoint,
          authRequired: authRequired, headers: headers).then((_) {});

  /// `DELETE` that returns the decoded body (e.g. the saved shop profile
  /// after removing the logo).
  Future<dynamic> deleteJson(
    String endpoint, {
    bool authRequired = true,
    Map<String, String>? headers,
  }) =>
      _send('DELETE', endpoint, authRequired: authRequired, headers: headers);

  /// Multipart upload (product image). Returns decoded JSON.
  ///
  /// [query] carries the upload's own options — the product image endpoint
  /// takes `variants=missing|all|one` to decide how far the new picture
  /// spreads across the product's packs.
  Future<dynamic> postMultipart(
    String endpoint, {
    required String fileField,
    required List<int> bytes,
    required String filename,
    Map<String, String>? query,
    bool authRequired = true,
  }) async {
    if (bytes.length > maxUploadBytes) {
      throw const ApiException(
          400, 'This image is larger than 5 MB. Choose a smaller one.',
          code: 'VALIDATION_FAILED');
    }
    if (authRequired && _session.accessToken == null) {
      throw const NotAuthenticatedException();
    }
    final uri = _uri(endpoint, query);
    Future<http.Response> send() async {
      final req = http.MultipartRequest('POST', uri)
        ..headers.addAll(_authHeaders())
        ..files.add(http.MultipartFile.fromBytes(fileField, bytes,
            filename: filename));
      try {
        final streamed =
            await _http.send(req).timeout(ApiConfig.receiveTimeout);
        return await http.Response.fromStream(streamed);
      } on TimeoutException {
        throw const ApiException(
            0, 'The server is taking too long to respond.');
      } catch (e) {
        if (e is ApiException) rethrow;
        throw const ApiException(
            0, 'Could not reach the server. Check your connection.');
      }
    }

    var resp = await send();
    if (resp.statusCode == 401 && authRequired) {
      if (await _refreshTokens()) {
        resp = await send();
      } else {
        _expireSessionIfRejected();
      }
    }
    return _handle(uri, resp, authRequired: authRequired);
  }

  /// Server-Sent Events (order live updates): a GET whose body arrives
  /// incrementally instead of being read to the end.
  ///
  /// The connection is opened with the same auth rules as the buffered verbs
  /// (token attached, one silent refresh on a 401) and **no receive timeout**
  /// — an SSE stream is meant to stay open for minutes, with a keep-alive
  /// comment every 25 s and a deliberate close after 10 minutes that the
  /// caller reconnects to.
  Future<http.StreamedResponse> stream(
    String endpoint, {
    Map<String, String>? query,
    bool authRequired = true,
  }) async {
    if (authRequired && _session.accessToken == null) {
      throw const NotAuthenticatedException();
    }
    final uri = _uri(endpoint, query);

    Future<http.StreamedResponse> open() {
      final req = http.Request('GET', uri)
        ..headers.addAll({
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
          if (authRequired) ..._authHeaders(),
        });
      return _http.send(req);
    }

    try {
      var resp = await open();
      if (resp.statusCode == 401 && authRequired) {
        if (await _refreshTokens()) {
          resp = await open();
        } else {
          _expireSessionIfRejected();
        }
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        final http.Response full = await http.Response.fromStream(resp);
        throw _toApiException(full);
      }
      return resp;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException(0, 'Could not reach the server. Check your connection.');
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Map<String, String> _authHeaders() {
    final token = _session.accessToken;
    return {
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String endpoint, Map<String, String>? query) {
    final path = ApiConfig.path(endpoint);
    final base = Uri.parse('${ApiConfig.baseUrl}$path');
    if (query == null || query.isEmpty) return base;
    final filtered = <String, String>{};
    query.forEach((k, v) {
      if (v.isEmpty) return;
      if (k == 'size') {
        // The server clamps size to 1..50; never ask for more.
        final n = int.tryParse(v);
        if (n != null) {
          filtered[k] = '${n < 1 ? 1 : (n > maxPageSize ? maxPageSize : n)}';
          return;
        }
      }
      filtered[k] = v;
    });
    return filtered.isEmpty
        ? base
        : base.replace(queryParameters: {...base.queryParameters, ...filtered});
  }

  /// True for the backend's `503 SERVICE_BUSY` (connection pool full).
  static bool _isServiceBusy(http.Response r) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes, allowMalformed: true));
      return j is Map && j['code'] == 'SERVICE_BUSY';
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> _send(
    String method,
    String endpoint, {
    Object? body,
    Map<String, String>? query,
    required bool authRequired,
    Map<String, String>? headers,
  }) async {
    if (authRequired && _session.accessToken == null) {
      throw const NotAuthenticatedException();
    }
    final uri = _uri(endpoint, query);
    final encoded = body == null ? null : jsonEncode(body);
    final hdrs = {
      'Accept': 'application/json',
      if (encoded != null) 'Content-Type': 'application/json',
      if (authRequired) ..._authHeaders(),
      ...?headers,
    };

    var first = await _attempt(method, uri, encoded, hdrs);
    // A full database pool answers 503 SERVICE_BUSY with a Retry-After of
    // about 2 s. It is not a missing provider: wait that long and retry once,
    // but only for calls that are safe to repeat (reads, or writes that carry
    // an Idempotency-Key).
    if (first.statusCode == 503 &&
        _isServiceBusy(first) &&
        (method == 'GET' ||
            method == 'HEAD' ||
            hdrs.containsKey('Idempotency-Key'))) {
      final wait = int.tryParse((first.headers['retry-after'] ?? '').trim()) ?? 2;
      await Future<void>.delayed(Duration(seconds: wait.clamp(1, 5)));
      first = await _attempt(method, uri, encoded, hdrs);
    }
    // 429 RATE_LIMITED (01 rule 3): wait the advertised Retry-After and retry
    // ONCE, only for reads and keyed writes, and only for a short wait; a
    // longer wait is left to the screen (never a loop).
    if (first.statusCode == 429 &&
        (method == 'GET' ||
            method == 'HEAD' ||
            hdrs.containsKey('Idempotency-Key'))) {
      final wait = int.tryParse((first.headers['retry-after'] ?? '').trim());
      if (wait != null && wait >= 0 && wait <= 5) {
        await Future<void>.delayed(Duration(seconds: wait < 1 ? 1 : wait));
        first = await _attempt(method, uri, encoded, hdrs);
      }
    }
    // Silent refresh on a single 401, then retry once.
    if (first.statusCode == 401 && authRequired) {
      final refreshed = await _refreshTokens();
      if (refreshed) {
        final retryHdrs = {
          ...hdrs,
          ..._authHeaders(),
        };
        final second = await _attempt(method, uri, encoded, retryHdrs);
        return _handle(uri, second, authRequired: authRequired);
      }
      _expireSessionIfRejected();
    }
    return _handle(uri, first, authRequired: authRequired);
  }

  Future<http.Response> _attempt(
    String method,
    Uri uri,
    String? encoded,
    Map<String, String> headers,
  ) async {
    try {
      final req = http.Request(method, uri);
      req.headers.addAll(headers);
      if (encoded != null) req.body = encoded;
      final streamed =
          await _http.send(req).timeout(ApiConfig.connectTimeout);
      return await http.Response.fromStream(streamed)
          .timeout(ApiConfig.receiveTimeout);
    } on TimeoutException {
      throw const ApiException(0, 'The server is taking too long to respond.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException(0, 'Could not reach the server. Check your connection.');
    }
  }

  dynamic _handle(Uri uri, http.Response resp, {required bool authRequired}) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return null;
      final text = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
      if (text.isEmpty) return null;
      try {
        return jsonDecode(text);
      } catch (_) {
        return text;
      }
    }
    throw _toApiException(resp);
  }

  ApiException _toApiException(http.Response resp) {
    String message = 'Something went wrong (${resp.statusCode}).';
    String? code;
    Object? payload;
    final text = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
    if (text.isNotEmpty) {
      try {
        final decoded = jsonDecode(text);
        payload = decoded;
        if (decoded is Map) {
          // Backend error envelope: {"error":{"type":..,"message":..}}
          final err = decoded['error'];
          if (err is Map) {
            message = (err['message'] ?? err['type'] ?? message).toString();
            code = err['type']?.toString();
          } else {
            message = (decoded['message'] ??
                    err ??
                    decoded['detail'] ??
                    decoded['title'] ??
                    message)
                .toString();
            code = decoded['code']?.toString();
          }
          // Field-level validation detail, e.g.
          //   {"code":"VALIDATION_FAILED","message":"Please check the
          //    highlighted fields","details":{"fields":{"email":"…"}}}
          // or Spring's `errors: ["email: must be …"]`. Prefer the per-field
          // text so the UI can say exactly what to fix.
          final fields = _fieldMessages(decoded);
          if (fields.isNotEmpty) message = fields.join(' · ');
          if (message.trim().isEmpty) {
            message = 'The request was rejected (${resp.statusCode}).';
          }
        } else if (decoded is String && decoded.isNotEmpty) {
          message = decoded;
        }
      } catch (_) {
        if (text.length < 200) message = text;
      }
    }
    // traceId: envelope field first, else the X-Trace-Id header (same value).
    String? traceId = resp.headers['x-trace-id'];
    final p = payload;
    if (p is Map && (p['traceId']?.toString().isNotEmpty ?? false)) {
      traceId = p['traceId'].toString();
    }
    // details.fields -> per-input highlighting.
    final fieldMap = <String, String>{};
    if (p is Map && p['details'] is Map) {
      final f = (p['details'] as Map)['fields'];
      if (f is Map) {
        f.forEach((k, v) => fieldMap[k.toString()] = v.toString());
      }
    }
    if (fieldMap.isNotEmpty) ApiException.recordFields(fieldMap);
    // The backend still answers some bad input (bad enum, malformed JSON,
    // wrong type, missing header, non-UUID id) with a bare "Bad request" and
    // empty details. Say something the user can act on, with the reference
    // support needs, instead of showing the two words as they are.
    if (resp.statusCode == 400 &&
        fieldMap.isEmpty &&
        message.trim().toLowerCase() == 'bad request') {
      message = 'We could not process that request. Please check your '
          'details and try again.';
      if (traceId != null && traceId.isNotEmpty) {
        message = '$message (ref $traceId)';
      }
    }
    // 5xx: put the support reference into the text so every toast shows it.
    if (resp.statusCode >= 500 &&
        traceId != null &&
        traceId.isNotEmpty &&
        !message.contains('(ref ')) {
      message = '$message (ref $traceId)';
    }
    final retryAfter = int.tryParse((resp.headers['retry-after'] ?? '').trim());
    return ApiException(resp.statusCode, message,
        code: code,
        payload: payload,
        traceId: traceId,
        fields: fieldMap,
        retryAfterHeader: retryAfter);
  }

  /// Collects human-readable `field: reason` lines from a validation body.
  static List<String> _fieldMessages(Map decoded) {
    final out = <String>[];
    void add(Object? key, Object? value) {
      final v = value?.toString().trim() ?? '';
      if (v.isEmpty) return;
      final k = key?.toString().trim() ?? '';
      out.add(k.isEmpty ? v : '$k: $v');
    }

    // Our envelope: details.fields / details.fieldErrors
    final details = decoded['details'];
    if (details is Map) {
      final fields = details['fields'];
      if (fields is Map) fields.forEach(add);
      final fe = details['fieldErrors'];
      if (fe is List) {
        for (final e in fe) {
          if (e is Map) {
            add(e['field'], e['message'] ?? e['defaultMessage']);
          } else {
            add(null, e);
          }
        }
      }
    }

    // Spring / generic shapes.
    final errors = decoded['errors'];
    if (errors is Map) {
      errors.forEach(add);
    } else if (errors is List) {
      for (final e in errors) {
        if (e is Map) {
          add(e['field'] ?? e['name'], e['message'] ?? e['defaultMessage']);
        } else {
          add(null, e);
        }
      }
    }
    final topFieldErrors = decoded['fieldErrors'];
    if (topFieldErrors is List) {
      for (final e in topFieldErrors) {
        if (e is Map) {
          add(e['field'] ?? e['name'], e['message'] ?? e['defaultMessage']);
        } else {
          add(null, e);
        }
      }
    }
    // Cap: a form may report many fields; the first few are enough.
    return out.length > 4 ? out.sublist(0, 4) : out;
  }

  /// Refresh failed because the server refused the refresh token (expired,
  /// rotated away, revoked): wipe the dead session and tell the app to go to
  /// sign-in. A mere network failure keeps the session.
  void _expireSessionIfRejected() {
    if (!_refreshRejected) return;
    _refreshRejected = false;
    unawaited(_session.clear());
    onSessionExpired?.call();
  }

  /// Refresh the access token using the stored refresh token (single-flight).
  Future<bool> _refreshTokens() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refresh = _session.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final uri = _uri('/auth/refresh', null);
      final resp = await _attempt(
        'POST',
        uri,
        jsonEncode({'refreshToken': refresh}),
        {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        // 4xx = the refresh token itself was refused; 5xx = try again later.
        if (resp.statusCode >= 400 && resp.statusCode < 500 &&
            resp.statusCode != 429 && resp.statusCode != 408) {
          _refreshRejected = true;
        }
        return false;
      }
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final access = decoded['accessToken']?.toString();
      final newRefresh = decoded['refreshToken']?.toString();
      if (access == null) return false;
      await _session.save(
        accessToken: access,
        refreshToken: newRefresh ?? refresh,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _http.close();
}

/// RFC-4122-ish idempotency key.
String newIdempotencyKey() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
