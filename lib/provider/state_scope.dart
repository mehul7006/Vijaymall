import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

export 'package:provider/provider.dart';

/// Convenience accessor for the single `AppState` provider.
///
/// `StateScope.of(context)` listens (rebuilds the calling widget on change),
/// `StateScope.read(context)` mutates without listening.
class StateScope {
  StateScope._();

  static AppState of(BuildContext context, {bool listen = true}) =>
      Provider.of<AppState>(context, listen: listen);

  static AppState read(BuildContext context) =>
      Provider.of<AppState>(context, listen: false);
}
