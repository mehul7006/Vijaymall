/// Shared input validators: each returns `null` when the value is fine (or
/// empty and optional) and a short, plain message otherwise. Use these on every
/// form so a bad value is caught on the device with the same wording
/// everywhere (the server still has the final say and its `details.fields`
/// message is shown when it refuses something).
///
/// Messages are English; wrap with `gt()` at the call site.
library;

class Validators {
  Validators._();

  static String _t(String? v) => (v ?? '').trim();

  /// Indian mobile: exactly 10 digits, starting 6-9.
  static String? mobile(String? v, {bool required = false}) {
    final s = _t(v);
    if (s.isEmpty) return required ? 'Enter the mobile number' : null;
    if (!RegExp(r'^\d+$').hasMatch(s)) return 'Mobile number must be digits only';
    if (s.length != 10) return 'Mobile number must be 10 digits';
    if (!RegExp(r'^[6-9]').hasMatch(s)) {
      return 'Mobile number must start with 6, 7, 8 or 9';
    }
    return null;
  }

  static String? email(String? v, {bool required = false}) {
    final s = _t(v);
    if (s.isEmpty) return required ? 'Enter the e-mail address' : null;
    if (s.length > 254) return 'E-mail is too long (254 characters at most)';
    if (!RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$')
        .hasMatch(s)) {
      return 'Enter a valid e-mail address';
    }
    return null;
  }

  /// GSTIN: 15 characters - 2 digit state code, 10 character PAN, entity
  /// number, `Z`, check character.
  static String? gstin(String? v, {bool required = false}) {
    final s = _t(v).toUpperCase();
    if (s.isEmpty) return required ? 'Enter the GSTIN' : null;
    if (s.length != 15) return 'GSTIN must be 15 characters';
    if (!RegExp(r'^[0-3][0-9][A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
        .hasMatch(s)) {
      return 'Enter a valid GSTIN (for example 24ABCDE1234F1Z5)';
    }
    return null;
  }

  static String? pan(String? v, {bool required = false}) {
    final s = _t(v).toUpperCase();
    if (s.isEmpty) return required ? 'Enter the PAN' : null;
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(s)) {
      return 'PAN must look like ABCDE1234F';
    }
    return null;
  }

  static String? pincode(String? v, {bool required = false}) {
    final s = _t(v);
    if (s.isEmpty) return required ? 'Enter the pincode' : null;
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(s)) return 'Pincode must be 6 digits';
    return null;
  }

  static String? ifsc(String? v, {bool required = false}) {
    final s = _t(v).toUpperCase();
    if (s.isEmpty) return required ? 'Enter the IFSC code' : null;
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(s)) {
      return 'IFSC must be 11 characters, like HDFC0001234';
    }
    return null;
  }

  static String? upiId(String? v, {bool required = false}) {
    final s = _t(v);
    if (s.isEmpty) return required ? 'Enter the UPI ID' : null;
    if (!RegExp(r'^[A-Za-z0-9.\-_]{2,}@[A-Za-z][A-Za-z0-9]{1,}$').hasMatch(s)) {
      return 'Enter a valid UPI ID, like name@bank';
    }
    return null;
  }

  /// Bank account number: 9 to 18 digits.
  static String? bankAccount(String? v, {bool required = false}) {
    final s = _t(v);
    if (s.isEmpty) return required ? 'Enter the account number' : null;
    if (!RegExp(r'^\d{9,18}$').hasMatch(s)) {
      return 'Account number must be 9 to 18 digits';
    }
    return null;
  }

  static String? text(String? v,
      {String label = 'This field',
      bool required = false,
      int min = 0,
      int max = 120}) {
    final s = _t(v);
    if (s.isEmpty) return required ? '$label is required' : null;
    if (s.length < min) return '$label must be at least $min characters';
    if (s.length > max) return '$label must be $max characters or fewer';
    return null;
  }

  /// Rupee amount typed by a person (up to 2 decimals), between [min] and [max].
  static String? rupees(String? v,
      {String label = 'Amount',
      bool required = false,
      double min = 0,
      double? max}) {
    final s = _t(v);
    if (s.isEmpty) return required ? 'Enter the ${label.toLowerCase()}' : null;
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(s)) {
      return '$label must be a number with at most 2 decimals';
    }
    final n = double.parse(s);
    if (n < min) return '$label must be $min or more';
    if (max != null && n > max) return '$label must be $max or less';
    return null;
  }

  /// A whole number between [min] and [max].
  static String? whole(String? v,
      {String label = 'Value', bool required = false, int min = 0, int? max}) {
    final s = _t(v);
    if (s.isEmpty) return required ? 'Enter the ${label.toLowerCase()}' : null;
    if (!RegExp(r'^\d+$').hasMatch(s)) return '$label must be a whole number';
    final n = int.parse(s);
    if (n < min) return '$label must be $min or more';
    if (max != null && n > max) return '$label must be $max or less';
    return null;
  }

  /// GST slab percentage the Indian rate card allows.
  static const gstSlabs = <int>[0, 3, 5, 12, 18, 28];

  static String? gstSlab(int? v) {
    if (v == null) return 'Choose a GST rate';
    return gstSlabs.contains(v) ? null : 'GST rate must be 0, 3, 5, 12, 18 or 28';
  }
}
