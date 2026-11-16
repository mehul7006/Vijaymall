import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api/api_service.dart';
import '../../data/api/push_dto.dart';
import '../../nav/nav.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/buttons.dart';
import '../../widgets/controls.dart';
import '../../widgets/panels.dart';
import 'admin_push_common.dart';
import 'admin_push_segments.dart';
import 'admin_push_wizard.dart';

/// `#/admin/push` - admin push notifications (`60-admin-push-notifications.md`).
///
/// Routes (query): none = broadcast history, `tab=segments` = saved segments,
/// `new=1[&segment=<id>][&again=<id>]` = new-broadcast wizard,
/// `id=<broadcast>` = one broadcast with live progress,
/// `seg=new|<id>` = segment editor.
class AdminPushScreen extends StatelessWidget {
  final Map<String, String> query;
  const AdminPushScreen({super.key, this.query = const {}});

  @override
  Widget build(BuildContext context) {
    if (query['new'] == '1') {
      return AdminPushWizard(
          key: ValueKey('wiz${query['segment']}${query['again']}'),
          segmentId: _nz(query['segment']),
          againId: _nz(query['again']));
    }
    final seg = query['seg'];
    if (seg != null && seg.isNotEmpty) {
      return PushSegmentEditor(
          key: ValueKey('seg$seg'), id: seg == 'new' ? null : seg);
    }
    final id = query['id'];
    if (id != null && id.isNotEmpty) {
      return _PushDetail(key: ValueKey(id), id: id);
    }
    return _PushHome(tab: query['tab'] == 'segments' ? 'segments' : 'history');
  }

  static String? _nz(String? s) => (s == null || s.isEmpty) ? null : s;
}

// ---------------------------------------------------------------------------
// Home: history + segments tabs
// ---------------------------------------------------------------------------

class _PushHome extends StatefulWidget {
  final String tab;
  const _PushHome({required this.tab});
  @override
  State<_PushHome> createState() => _PushHomeState();
}

class _PushHomeState extends State<_PushHome> {
  final List<PushBroadcast> _rows = [];
  int _total = 0;
  bool _totalExact = true;
  bool _hasMore = false;
  int _page = 0;
  bool _loading = true;
  bool _more = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    if (widget.tab == 'history') _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (widget.tab == 'history' && _rows.any((r) => r.isRunning)) {
        _refreshQuiet();
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refreshQuiet() async {
    try {
      final r = await Api.instance.push.broadcasts(page: 0, size: 20);
      if (!mounted) return;
      setState(() {
        // Replace the first page, keep any further pages already loaded.
        final extra = _rows.length > 20 ? _rows.sublist(20) : <PushBroadcast>[];
        _rows
          ..clear()
          ..addAll(r.items)
          ..addAll(extra);
        _total = r.total;
        _totalExact = r.totalExact;
      });
    } catch (_) {}
  }

  Future<void> _load({bool more = false}) async {
    if (more) {
      setState(() => _more = true);
    } else {
      setState(() {
        _loading = _rows.isEmpty;
        _error = null;
      });
    }
    try {
      final p = more ? _page + 1 : 0;
      final r = await Api.instance.push.broadcasts(page: p, size: 20);
      if (!mounted) return;
      setState(() {
        if (!more) _rows.clear();
        _rows.addAll(r.items);
        _page = r.page;
        _total = r.total;
        _totalExact = r.totalExact;
        _hasMore = r.hasMore;
        _loading = false;
        _more = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = pushError(e);
        _loading = false;
        _more = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final seg = widget.tab == 'segments';
    return PushAdminPage(
      title: gt('Push notifications'),
      sub: gt('Announce offers to customers and staff'),
      onRefresh: seg ? null : _load,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton('New broadcast',
              icon: 'bell', onTap: () => go('/admin/push?new=1')),
          const SizedBox(height: 12),
          Segmented(
            options: const [
              SegmentOption('history', 'Broadcasts'),
              SegmentOption('segments', 'Segments'),
            ],
            value: widget.tab,
            onChanged: (v) => Nav.instance
                .replace(v == 'segments' ? '/admin/push?tab=segments' : '/admin/push'),
          ),
          const SizedBox(height: 14),
          if (seg) const PushSegmentsList() else _history(),
        ],
      ),
    );
  }

  Widget _history() {
    if (_loading) {
      return const Column(children: [
        SkeletonBlock(height: 78, radius: 18),
        SizedBox(height: 10),
        SkeletonRows(rows: 4),
      ]);
    }
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
    if (_rows.isEmpty) {
      return EmptyState(
        icon: 'bell',
        title: gt('No broadcasts yet'),
        copy: gt('Send your first announcement to customers or staff.'),
        actionLabel: gt('New broadcast'),
        onAction: () => go('/admin/push?new=1'),
      );
    }
    final running = _rows.where((r) => r.isRunning).length;
    final delivered = _rows.fold<int>(0, (a, r) => a + r.delivered);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KpiGrid([
          KpiCard(
              icon: 'bell',
              tint: AppColors.navy,
              bg: AppColors.navyTint,
              label: gt('Broadcasts'),
              value: pushCount(_total, exact: _totalExact)),
          KpiCard(
              icon: 'check',
              tint: AppColors.green,
              bg: AppColors.greenTint,
              label: gt('Delivered'),
              value: pushCount(delivered)),
          KpiCard(
              icon: 'clock',
              tint: AppColors.goldInk,
              bg: AppColors.goldTint,
              label: gt('In progress'),
              value: '$running'),
        ]),
        const SizedBox(height: 12),
        for (final b in _rows) _row(b),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AppButton('Load more',
                variant: BtnVariant.soft,
                block: true,
                loading: _more,
                onTap: _more ? null : () => _load(more: true)),
          ),
      ],
    );
  }

  Widget _row(PushBroadcast b) {
    final total = b.recipientsExact ? '${b.recipients}' : '${pushCount(b.recipients)}+';
    return PushCard(
      onTap: () => go('/admin/push?id=${b.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(b.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: pushTs(size: 14.5, w: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            pushStatusPill(b.status),
          ]),
          const SizedBox(height: 3),
          Text(b.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: pushTs(size: 12, w: FontWeight.w600, color: AppColors.ink2)),
          const SizedBox(height: 8),
          Row(children: [
            pushAudiencePill(b.audience),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${b.delivered} / $total ${gt('delivered')}',
                  style: pushTs(size: 12, color: AppColors.ink2)),
            ),
            Text(pushWhen(b.createdAt),
                style: pushTs(size: 11.5, w: FontWeight.w600, color: AppColors.ink3)),
          ]),
          if (b.isRunning) ...[
            const SizedBox(height: 8),
            PushProgressBar(done: b.delivered, total: b.recipients),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail with live progress
// ---------------------------------------------------------------------------

class _PushDetail extends StatefulWidget {
  final String id;
  const _PushDetail({super.key, required this.id});
  @override
  State<_PushDetail> createState() => _PushDetailState();
}

class _PushDetailState extends State<_PushDetail> {
  PushBroadcast? _b;
  bool _loading = true;
  String? _error;
  Timer? _timer;
  late final DateTime _opened = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _error = null;
        _loading = _b == null;
      });
    }
    try {
      final b = await Api.instance.push.broadcastById(widget.id);
      if (!mounted) return;
      setState(() {
        _b = b;
        _loading = false;
      });
      _schedule();
    } catch (e) {
      if (!mounted) return;
      if (quiet) {
        _schedule();
        return;
      }
      setState(() {
        _error = pushError(e);
        _loading = false;
      });
    }
  }

  /// Every 2 s, backing off to 5 s after 30 s; stops once DONE / FAILED.
  void _schedule() {
    _timer?.cancel();
    final b = _b;
    if (b == null || b.isFinal) return;
    final slow = DateTime.now().difference(_opened).inSeconds > 30;
    _timer = Timer(Duration(seconds: slow ? 5 : 2), () => _load(quiet: true));
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    final b = _b;
    if (_loading) {
      body = const SkeletonRows(rows: 5);
    } else if (_error != null) {
      body = ErrorRetry(message: _error!, onRetry: _load);
    } else if (b == null) {
      body = const SizedBox.shrink();
    } else {
      body = _content(b);
    }
    return PushAdminPage(
      title: gt('Broadcast'),
      sub: b == null ? '' : pushWhen(b.createdAt),
      back: true,
      onRefresh: _load,
      child: body,
    );
  }

  Widget _content(PushBroadcast b) {
    final delivered = b.delivered;
    final recipients = b.recipients < delivered ? delivered : b.recipients;
    final totalText = b.recipientsExact
        ? pushCount(recipients)
        : '${pushCount(recipients)}+';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(b.title,
                      style: pushTs(size: 16, w: FontWeight.w800)),
                ),
                pushStatusPill(b.status),
              ]),
              const SizedBox(height: 6),
              Text(b.body,
                  style: pushTs(
                      size: 13, w: FontWeight.w600, color: AppColors.ink2, height: 1.45)),
              const SizedBox(height: 10),
              pushAudiencePill(b.audience),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CardPanel(
          title: gt('Progress'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PushProgressBar(done: delivered, total: recipients),
              const SizedBox(height: 8),
              Text('${pushCount(delivered)} / $totalText ${gt('delivered')}',
                  style: pushTs(size: 14, w: FontWeight.w800)),
              if (b.isRunning) ...[
                const SizedBox(height: 4),
                Text(gt('Sending. This page updates by itself.'),
                    style: pushTs(size: 12, w: FontWeight.w600, color: AppColors.ink3)),
              ],
              if (b.status == 'DONE' && delivered == 0) ...[
                const SizedBox(height: 8),
                PushNote(gt('Nobody was eligible when sending ran.'), warn: true),
              ],
            ],
          ),
        ),
        if (b.status == 'FAILED') ...[
          const SizedBox(height: 12),
          PushNote(
              '${gt('Sending stopped.')} ${pushCount(delivered)} ${gt('of')} ${pushCount(recipients)} ${gt('people received it. Contact support.')}',
              error: true),
          const SizedBox(height: 8),
          AppButton('Send again to everyone chosen',
              variant: BtnVariant.secondary,
              block: true,
              onTap: () => go('/admin/push?new=1&again=${b.id}')),
          const SizedBox(height: 4),
          Text(
              gt('People who already received it will get a second message.'),
              style: pushTs(size: 11.5, w: FontWeight.w600, color: AppColors.ink3)),
        ],
        const SizedBox(height: 12),
        if (!b.pushConfigured)
          PushNote(
              gt('Push is not set up: customers will see this in the app inbox only.'),
              warn: true)
        else if (b.pushFailedBatches > 0)
          PushNote(
              '${b.pushFailedBatches} ${gt('push batches failed. Their inbox messages were still delivered.')}',
              warn: true),
        const SizedBox(height: 12),
        CardPanel(
          title: gt('Details'),
          child: Column(children: [
            PushKv('Push sent to', '${pushCount(b.pushed)} ${gt('devices')}'),
            PushKv('Opens', b.ref ?? gt('Nothing (inbox only)')),
            PushKv('Created', pushWhen(b.createdAt)),
            if (b.startedAt != null) PushKv('Started', pushWhen(b.startedAt)),
            if (b.finishedAt != null) PushKv('Finished', pushWhen(b.finishedAt)),
          ]),
        ),
        if (b.skipped.isNotEmpty) ...[
          const SizedBox(height: 12),
          CardPanel(
            title: gt('Skipped (not found or blocked)'),
            child: Text(b.skipped.join(', '),
                style: pushTs(size: 12.5, w: FontWeight.w600, color: AppColors.ink2)),
          ),
        ],
        if (b.audience == 'SEGMENT' && b.segment != null) ...[
          const SizedBox(height: 12),
          CardPanel(
            title: gt('Conditions used'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gt(b.segment!.match == 'ANY' ? 'Any of these' : 'All of these'),
                    style: pushTs(size: 12, color: AppColors.ink3)),
                const SizedBox(height: 4),
                for (final r in b.segment!.rules)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      const AppIcon('filter', size: 13, color: AppColors.ink3),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(_ruleText(r),
                            style: pushTs(size: 12.5, w: FontWeight.w600)),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        AppButton('Send another',
            variant: BtnVariant.soft,
            block: true,
            onTap: () => go('/admin/push?new=1&again=${b.id}')),
        const SizedBox(height: 12),
      ],
    );
  }

  /// `Not TOTAL_SPENT GTE 500000`-style summary of a snapshot condition.
  static String _ruleText(PushCondition r) {
    final parts = <String>[];
    r.params.forEach((k, v) {
      if (k.toLowerCase().endsWith('paise') && v is int) {
        parts.add('$k Rs ${paiseText(v)}');
      } else {
        parts.add('$k ${v is List ? v.join(',') : v}');
      }
    });
    return '${r.negate ? '${gt('Not')} ' : ''}${r.type}${parts.isEmpty ? '' : ' (${parts.join(', ')})'}';
  }

  static String paiseText(int p) =>
      p % 100 == 0 ? '${p ~/ 100}' : (p / 100).toStringAsFixed(2);
}
