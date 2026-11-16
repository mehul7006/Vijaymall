import 'package:flutter/material.dart';

import '../../data/api/api_config.dart';
import '../../data/api/api_exception.dart';
import '../../nav/nav.dart';
import '../../provider/state_scope.dart';
import '../../state/app_state.dart';
import '../../state/gu_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chrome.dart';
import '../../widgets/controls.dart';
import '../../widgets/fields.dart';
import '../../widgets/panels.dart';
import '../../widgets/profile_menu.dart';
import '../../widgets/toast.dart';

/// `#/admin/profile` — the signed-in admin / staff member's own account:
/// name and mobile (`PUT /me`), e-mail and role read-only, language and
/// sign out. Works for ADMIN and CASHIER (staff) sessions alike.
class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  String? _nameErr;
  String? _phoneErr;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = StateScope.read(context);
    _name = TextEditingController(text: s.userName);
    _phone = TextEditingController(text: s.userPhone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final state = StateScope.read(context);
    final name = _name.text.trim();
    final phone = digits(_phone.text);
    if (name.isEmpty) {
      setState(() => _nameErr = gt('Enter your name'));
      showToast(gt('Enter your name'), 'error');
      return;
    }
    if (phone.isNotEmpty && phone.length != 10) {
      setState(() => _phoneErr = gt('Enter a 10-digit mobile number'));
      showToast(gt('Enter a 10-digit mobile number'), 'error');
      return;
    }
    setState(() {
      _saving = true;
      _nameErr = null;
      _phoneErr = null;
    });
    ApiException.clearFields();
    final err = await state.updateProfile(name: name, phone: phone);
    if (!mounted) return;
    final f = err == null ? <String, String>{} : ApiException.takeFields();
    setState(() {
      _saving = false;
      if (f.isNotEmpty) {
        _nameErr = ApiException.fieldError(f, ['name']);
        _phoneErr = ApiException.fieldError(f, ['mobile', 'phone']);
      }
    });
    if (err != null) {
      showToast(err, 'error');
    } else {
      showToast(gt('Profile updated'));
    }
  }

  Widget _accountCard(AppState s, BarRole role) {
    final email = (s.userEmail ?? '').trim();
    final mobileLocked =
        ApiConfig.isLive && email.isEmpty && s.userPhone.isNotEmpty;
    return CardPanel(
      title: gt('Account'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialsAvatar(state: s, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.userName.trim().isEmpty ? gt('My account') : s.userName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.uiFont,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RoleChip(role),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AppField(
            label: gt('Name'),
            controller: _name,
            error: _nameErr,
            placeholder: gt('Your name'),
          ),
          const SizedBox(height: 10),
          FieldRow(
            children: [
              AppField(
                label: gt('Mobile'),
                controller: _phone,
                error: _phoneErr,
                numeric: true,
                placeholder: '98250 11223',
                readOnly: mobileLocked,
              ),
              AppField(
                label: gt('Role'),
                value: role == BarRole.admin
                    ? gt('Store admin')
                    : gt('Staff (counter)'),
                readOnly: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppField(
            label: gt('E-mail'),
            value: email.isEmpty ? '-' : email,
            readOnly: true,
          ),
          const SizedBox(height: 16),
          AppButton(
            'Save profile',
            block: true,
            loading: _saving,
            onTap: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _prefsCard(AppState s, BarRole role) {
    return CardPanel(
      title: gt('Preferences'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            gt('Language'),
            style: const TextStyle(
              fontFamily: AppTheme.uiFont,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.ink2,
            ),
          ),
          const SizedBox(height: 8),
          Segmented(
            value: s.lang,
            onChanged: (v) => s.setLang(v),
            options: const [
              SegmentOption('en', 'English'),
              SegmentOption('gu', 'ગુજરાતી'),
            ],
          ),
          const SizedBox(height: 18),
          if (role == BarRole.admin) ...[
            AppButton(
              'Shop settings',
              variant: BtnVariant.secondary,
              block: true,
              onTap: () => go('/admin/shop-settings'),
            ),
            const SizedBox(height: 10),
          ],
          AppButton(
            'Sign out',
            variant: BtnVariant.danger,
            block: true,
            onTap: () {
              StateScope.read(context).adminSignOut();
              go('/signin');
              showToast(gt('Signed out'));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = StateScope.of(context);
    final role = barRoleOf(s) == BarRole.staff ? BarRole.staff : BarRole.admin;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                AdminHead(
                  title: gt('My profile'),
                  sub: gt('Your account and preferences'),
                  bell: false,
                ),
                ScreenScroll(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final twoCol = c.maxWidth >= 760;
                      if (!twoCol) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 14),
                            _accountCard(s, role),
                            const SizedBox(height: 12),
                            _prefsCard(s, role),
                          ],
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _accountCard(s, role)),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: _prefsCard(s, role)),
                          ],
                        ),
                      );
                    },
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
}
