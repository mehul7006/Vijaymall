import '../nav/nav.dart';
import '../state/app_state.dart';
import '../state/gu_strings.dart';
import 'toast.dart';

/// Guests may browse the store, but adding to the cart and checking out need
/// an account. Returns true when the visitor is signed in. Otherwise it says
/// so, remembers the current page and opens the OTP sign-in; after signing in
/// the customer comes back to the page they were on.
bool ensureSignedIn(AppState state) {
  if (state.signedIn || state.backendMode) return true;
  showToast(gt('Please sign in with your mobile number or email to continue'),
      'error');
  Nav.instance.returnTo = Nav.instance.route;
  Nav.instance.go('/signin');
  return false;
}
