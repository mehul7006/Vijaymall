import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/pos_offline.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/confirm.dart';
import '../../widgets/controls.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';

String _rs(int paise) {
  final a = paise.abs();
  return '${paise < 0 ? '-' : ''}Rs ${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
}

const _lab = TextStyle(
    fontFamily: AppTheme.uiFont,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.ink);
const _small = TextStyle(
    fontFamily: AppTheme.uiFont, fontSize: 12, color: AppColors.ink2);

/// Header button of the till: shows "Offline" (with the number of bills still
/// to upload) or "Online"; opens the offline sheet.
class PosOfflineChip extends StatelessWidget {
  const PosOfflineChip({super.key});

  @override
  Widget build(BuildContext context) {
    final o = PosOffline.instance;
    return AnimatedBuilder(
      animation: o,
      builder: (_, __) {
        final off = o.offline;
        final n = o.unsent;
        final label = off
            ? '${gt('OFFLINE')}${n > 0 ? ' · $n' : ''}'
            : (n > 0 ? '${gt('Online')} · $n ${gt('to send')}' : gt('Online'));
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AppButton(label,
              size: BtnSize.sm,
              variant: off ? BtnVariant.danger : BtnVariant.secondary,
              onTap: () => showPosOfflineSheet(context)),
        );
      },
    );
  }
}

/// Thin banner under the header while the till bills offline.
class PosOfflineBanner extends StatelessWidget {
  const PosOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final o = PosOffline.instance;
    return AnimatedBuilder(
      animation: o,
      builder: (_, __) {
        if (!o.offline && !o.clockBad) return const SizedBox.shrink();
        final text = o.clockBad
            ? gt('The clock on this device differs from the server by several minutes. Fix the device time before billing offline.')
            : '${gt('OFFLINE MODE: bills are saved on this device and sent when the connection is back.')} '
                '${gt('Coupons, coins, credit and card machines are not available.')}';
        return Container(
          width: double.infinity,
          color: o.clockBad ? AppColors.goldTint : AppColors.redTint,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(text,
              style: _lab.copyWith(
                  color: o.clockBad ? AppColors.ink : AppColors.red)),
        );
      },
    );
  }
}

Future<void> showPosOfflineSheet(BuildContext context) => showAppSheet<void>(
      context: context,
      title: gt('Offline billing'),
      sub: gt('Bills saved on this device and the product copy'),
      builder: (_) => const _OfflineBody(),
    );

class _OfflineBody extends StatelessWidget {
  const _OfflineBody();

  @override
  Widget build(BuildContext context) {
    final o = PosOffline.instance;
    return AnimatedBuilder(
      animation: o,
      builder: (ctx, _) {
        final waiting =
            o.queue.where((b) => b['status'] == PosOffline.queued).toList();
        final attn =
            o.queue.where((b) => b['status'] == PosOffline.attention).toList();
        final done =
            o.queue.where((b) => b['status'] == PosOffline.synced).toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                    child: Text(gt('Work offline (do not call the server)'),
                        style: _lab)),
                AppSwitch(value: o.forced, onChanged: (v) => o.setForced(v)),
              ]),
              const SizedBox(height: 6),
              Text(
                  o.reachable
                      ? gt('The server is reachable.')
                      : gt('The server cannot be reached: billing offline.'),
                  style: _small),
              const SizedBox(height: 10),
              Text(
                  '${gt('Product copy')}: ${o.products.length} ${gt('products')}'
                  '${o.lastFull == null ? '' : ' · ${gt('full download')} ${_ago(o.lastFull!)}'}',
                  style: _small),
              if (o.refreshError != null)
                Text(o.refreshError!, style: _small.copyWith(color: AppColors.red)),
              if (o.clockBad)
                Text(
                    gt('The device clock differs from the server. Offline billing is blocked until it is corrected.'),
                    style: _small.copyWith(color: AppColors.red)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                AppButton(gt('Send bills now'),
                    size: BtnSize.sm,
                    loading: o.syncing,
                    disabled: waiting.isEmpty || o.syncing,
                    onTap: () async {
                      final n = await o.sync();
                      if (o.syncMessage != null) {
                        showToast(o.syncMessage!, 'error');
                      } else {
                        showToast('$n ${gt('bills recorded')}');
                      }
                    }),
                AppButton(gt('Refresh product copy'),
                    size: BtnSize.sm,
                    variant: BtnVariant.secondary,
                    loading: o.refreshing,
                    onTap: () => unawaited(o.refreshCatalogue(full: true))),
              ]),
              if (o.syncMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(o.syncMessage!,
                      style: _small.copyWith(color: AppColors.red)),
                ),
              const SizedBox(height: 14),
              _section(gt('Needs attention'), attn.length),
              if (attn.isEmpty)
                Text(gt('Nothing needs attention.'), style: _small),
              for (final b in attn) _row(ctx, o, b),
              const SizedBox(height: 12),
              _section(gt('Waiting to be sent'), waiting.length),
              if (waiting.isEmpty)
                Text(gt('No bills waiting.'), style: _small),
              for (final b in waiting) _row(ctx, o, b),
              const SizedBox(height: 12),
              _section(gt('Recorded'), done.length),
              for (final b in done.reversed.take(10)) _row(ctx, o, b),
            ],
          ),
        );
      },
    );
  }

  Widget _section(String t, int n) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text('$t ($n)',
            style: _lab.copyWith(fontSize: 14, fontWeight: FontWeight.w800)),
      );

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 2) return gt('just now');
    if (d.inHours < 1) return '${d.inMinutes} min ${gt('ago')}';
    if (d.inDays < 1) return '${d.inHours} h ${gt('ago')}';
    return '${d.inDays} ${gt('days ago')}';
  }

  Widget _row(BuildContext ctx, PosOffline o, Map<String, dynamic> b) {
    final st = '${b['status']}';
    final ex = (b['exceptions'] as List? ?? []).whereType<Map>().toList();
    final old = st == PosOffline.queued && o.ageDays(b) >= o.maxOfflineDays - 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: st == PosOffline.attention ? AppColors.red : AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            '${b['invoiceNo'] ?? b['localNo']} · ${_rs((b['totalPaise'] as num?)?.toInt() ?? 0)}',
            style: _lab),
        Text('${b['soldAt']}'.replaceFirst('T', ' ').split('.').first + ' UTC',
            style: _small),
        if (old)
          Text(
              '${gt('Older than')} ${o.maxOfflineDays - 1} ${gt('days: the server refuses bills older than')} ${o.maxOfflineDays}. ${gt('Send it now.')}',
              style: _small.copyWith(color: AppColors.red)),
        if (st == PosOffline.attention) ...[
          Text('${b['errorCode'] ?? ''} ${b['message'] ?? ''}'.trim(),
              style: _small.copyWith(color: AppColors.red)),
          Text(
              gt('Not recorded. Ask the manager; the bill stays here until you remove it.'),
              style: _small),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            AppButton(gt('Try again'),
                size: BtnSize.xs,
                variant: BtnVariant.secondary,
                onTap: () => o.retry('${b['key']}')),
            AppButton(gt('Remove'),
                size: BtnSize.xs,
                variant: BtnVariant.dangerSoft,
                onTap: () async {
                  final ok = await confirmAction(ctx,
                      title: 'Remove this bill?',
                      body: gt(
                          'It was not recorded on the server. Removing it deletes it from this device for good.'),
                      confirmLabel: 'Remove');
                  if (ok) o.remove('${b['key']}');
                }),
          ]),
        ],
        if (st == PosOffline.synced && ex.isNotEmpty)
          for (final e in ex)
            Text('${gt('Recorded, the manager will review')}: ${e['kind']} ${e['detail'] ?? ''}',
                style: _small.copyWith(color: AppColors.ink)),
        if (st == PosOffline.queued && '${b['message'] ?? ''}'.isNotEmpty)
          Text('${b['message']}', style: _small),
      ]),
    );
  }
}

/// Baskets parked on this device while offline (holds need the server).
Future<void> showLocalHoldsSheet(BuildContext context,
        void Function(List<Map<String, dynamic>> items, String? mobile) onResume) =>
    showAppSheet<void>(
      context: context,
      title: gt('Parked on this device'),
      sub: gt('Offline: kept locally until you resume or remove them'),
      builder: (ctx) => AnimatedBuilder(
        animation: PosOffline.instance,
        builder: (_, __) {
          final list = PosOffline.instance.localHolds();
          if (list.isEmpty) {
            return Padding(
                padding: const EdgeInsets.all(20),
                child: Text(gt('Nothing parked.'), style: _small));
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            child: Column(children: [
              for (final h in list)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.line)),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                            '${h['label']} · ${(h['items'] as List).length} ${gt('items')}',
                            style: _lab)),
                    AppButton(gt('Resume'), size: BtnSize.xs, onTap: () {
                      final items = (h['items'] as List)
                          .whereType<Map>()
                          .map((e) => Map<String, dynamic>.from(e))
                          .toList();
                      PosOffline.instance.removeLocalHold('${h['id']}');
                      Navigator.of(ctx).pop();
                      onResume(items, h['mobile']?.toString());
                    }),
                    const SizedBox(width: 6),
                    AppButton(gt('Discard'),
                        size: BtnSize.xs,
                        variant: BtnVariant.dangerSoft,
                        onTap: () =>
                            PosOffline.instance.removeLocalHold('${h['id']}')),
                  ]),
                ),
            ]),
          );
        },
      ),
    );
