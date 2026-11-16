/// India Standard Time helpers (Asia/Kolkata, fixed UTC+5:30, no DST).
///
/// Convention used across the app: every [DateTime] shown to the user is an
/// "IST wall-clock" value - a UTC-flagged DateTime whose year/month/day/hour/
/// minute fields read as India time. That makes `d.hour`, `d.day`, weekday
/// and `difference` correct whatever the device time zone is.
library;

const Duration istOffset = Duration(hours: 5, minutes: 30);

/// Current India wall-clock time.
DateTime istNow() => DateTime.now().toUtc().add(istOffset);

/// Converts any instant (UTC or local) to an India wall-clock value.
DateTime toIst(DateTime instant) => instant.toUtc().add(istOffset);

/// Parses a backend ISO string (normally a UTC instant ending in `Z`) into an
/// India wall-clock value. A string with no offset (e.g. `2026-11-09`) is
/// already a calendar value and is kept as written.
DateTime? parseIst(String? iso) {
  if (iso == null || iso.trim().isEmpty) return null;
  final p = DateTime.tryParse(iso.trim());
  if (p == null) return null;
  if (p.isUtc) return toIst(p);
  return DateTime.utc(p.year, p.month, p.day, p.hour, p.minute, p.second,
      p.millisecond);
}
