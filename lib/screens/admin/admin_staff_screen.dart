import 'package:flutter/material.dart';

import '../../data/validators.dart';
import '../../widgets/confirm.dart';
import '../../data/api/api_exception.dart';
import '../../data/api/dto.dart';
import '../../provider/state_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_kit.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/toast.dart';
import '../../state/gu_strings.dart';

/// `#/admin/staff` — staff roster (counter users).
///
/// Reads `GET /admin/staff`, adds via `POST /admin/staff` and toggles access
/// with `PATCH /admin/staff/{id}`.
class AdminStaffScreen extends StatelessWidget {
  const AdminStaffScreen({super.key});

  @override
  Widget build(BuildContext context) => const _StaffBody();
}

class _StaffBody extends StatefulWidget {
  const _StaffBody();

  @override
  State<_StaffBody> createState() => _StaffBodyState();
}

class _StaffBodyState extends State<_StaffBody> {
  bool _loaded = false;
  bool _adding = false;
  bool _busy = false;
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _mobile = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    StateScope.read(context).refreshStaff();
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Map<String, String> _errs = const {};

  Future<void> _add() async {
    if (_busy) return;
    final e = <String, String>{};
    final em = Validators.email(_email.text, required: true);
    if (em != null) e['email'] = gt(em);
    final nm = Validators.text(_name.text,
        label: 'Name', max: 80);
    if (nm != null) e['name'] = gt(nm);
    final mo = Validators.mobile(_mobile.text);
    if (mo != null) e['mobile'] = gt(mo);
    setState(() => _errs = e);
    if (e.isNotEmpty) return;
    setState(() => _busy = true);
    final st = StateScope.read(context);
    ApiException.clearFields();
    var err = await st.addStaff(
      email: _email.text,
      name: _name.text,
      mobile: _mobile.text,
    );
    if (!mounted) return;
    // 409 EMAIL_ALREADY_REGISTERED: an active customer can be promoted after
    // the admin confirms; any other account stays refused.
    if (err != null && st.staffConflictRole != null) {
      final role = st.staffConflictRole!.toUpperCase();
      if (role == 'CUSTOMER') {
        final ok = await confirmAction(
          context,
          title: 'Make this customer a cashier?',
          body: gt('This e-mail already belongs to a customer. Make them a cashier? They keep their order history.'),
          confirmLabel: 'Make cashier',
        );
        if (!mounted) return;
        if (ok) {
          err = await st.addStaff(
            email: _email.text,
            name: _name.text,
            mobile: _mobile.text,
            confirmPromote: true,
          );
          if (!mounted) return;
        } else {
          setState(() => _busy = false);
          return;
        }
      }
    }
    setState(() => _busy = false);
    if (err != null) {
      final f = ApiException.takeFields();
      if (f.isNotEmpty) {
        setState(() => _errs = {
              'email': ApiException.fieldError(f, ['email']) ?? '',
              'name': ApiException.fieldError(f, ['name']) ?? '',
              'mobile': ApiException.fieldError(f, ['mobile']) ?? '',
            }..removeWhere((k, v) => v.isEmpty));
      }
      showToast(err, 'error');
      return;
    }
    _email.clear();
    _name.clear();
    _mobile.clear();
    setState(() => _adding = false);
    showToast(gt('Staff added · they sign in with email OTP'));
  }

  Future<void> _toggle(StaffViewDto s) async {
    final id = s.id;
    if (id == null || _busy) return;
    final enable = !s.active; // the server's flag, not a session guess
    setState(() => _busy = true);
    final err = await StateScope.read(context).setStaffActive(id, enable);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showToast(err, 'error');
      return;
    }
    showToast(enable ? 'Access enabled' : 'Access disabled');
  }

  @override
  Widget build(BuildContext context) {
    final staff = StateScope.of(context).adminStaff;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('Staff'),
                  sub: '${staff.length} account${staff.length == 1 ? '' : 's'} · email OTP sign-in',
                  bell: false,
                  actions: [
                    if (!_adding)
                      Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: IconBtn(
                          'plus',
                          size: 38,
                          iconSize: 17,
                          onTap: () => setState(() => _adding = true),
                        ),
                      ),
                  ],
                ),
                ScreenScroll(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_adding) ...[
                        _addCard(),
                        const SizedBox(height: 12),
                      ],
                      if (staff.isNotEmpty) ...[
                        KpiGrid([
                          KpiCard(
                            icon: 'users',
                            tint: AppColors.navy2,
                            bg: AppColors.navyTint,
                            label: gt('Accounts'),
                            value: '${staff.length}',
                          ),
                          KpiCard(
                            icon: 'shield',
                            tint: AppColors.green,
                            bg: AppColors.greenTint,
                            label: gt('Access on'),
                            value:
                                '${staff.where((s) => s.active).length}',
                          ),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      if (staff.isEmpty)
                        AdminLoadingOrElse(
                          fallback: CardPanel(
                            title: gt('Roster'),
                            child: const Hint(
                                'No staff yet. Add the counter users who will '
                                'sign in with their email.'),
                          ),
                        )
                      else
                      CardPanel(
                        title: gt('Roster'),
                        child: Column(
                                children: [
                                  for (var i = 0; i < staff.length; i++)
                                    _staffRow(staff[i],
                                        last: i == staff.length - 1),
                                ],
                              ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
            const AdminNav(active: 'more'),
          ],
        ),
      ),
    );
  }

  Widget _addCard() {
    return CardPanel(
      title: gt('Add staff'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppField(
            label: gt('Email (sign-in)'),
            value: _email.text,
            placeholder: gt('staff@vijaysupermall.in'),
            error: _errs['email'],
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) => _email.text = v,
          ),
          const SizedBox(height: 10),
          FieldRow(
            flex: const [3, 2],
            children: [
              AppField(
                label: gt('Name'),
                value: _name.text,
                placeholder: gt('Ramesh Patel'),
                error: _errs['name'],
                maxLength: 80,
                onChanged: (v) => _name.text = v,
              ),
              AppField(
                label: gt('Mobile'),
                value: _mobile.text,
                numeric: true,
                placeholder: '9825011223',
                maxLength: 10,
                error: _errs['mobile'],
                onChanged: (v) => _mobile.text = v,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  'Add staff',
                  block: true,
                  loading: _busy,
                  onTap: _busy ? null : _add,
                ),
              ),
              const SizedBox(width: 10),
              AppButton(
                'Cancel',
                variant: BtnVariant.secondary,
                onTap: () => setState(() => _adding = false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _staffRow(StaffViewDto s, {required bool last}) {
    final off = !s.active;
    final who = (s.name ?? '').isEmpty ? (s.email ?? '') : s.name!;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(right: 11),
            decoration: BoxDecoration(
              color: off ? AppColors.bg : AppColors.navyTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              who.isEmpty ? '?' : who.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontFamily: AppTheme.uiFont,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: off ? AppColors.ink3 : AppColors.navy2,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  who,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (s.mobile ?? '').isEmpty
                      ? (s.email ?? '')
                      : '${s.email} · ${s.mobile}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.uiFont,
                    fontSize: 11.5,
                    color: AppColors.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(off ? 'Disabled' : 'Active',
              fg: off ? AppColors.red : AppColors.green,
              bg: off ? AppColors.redTint : AppColors.greenTint),
          const SizedBox(width: 8),
          AppButton(
            off ? 'Enable' : 'Disable',
            variant: BtnVariant.secondary,
            onTap: s.id == null ? null : () => _toggle(s),
          ),
        ],
      ),
    );
  }
}
