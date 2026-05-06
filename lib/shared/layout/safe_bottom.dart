import 'package:flutter/widgets.dart';

/// Helpers to keep the last item in a scrollable list out of the
/// device's gesture / navigation bar. Without this, the bottom of a
/// long ListView lands flush against the system inset and the last
/// row reads as cut off.
extension SafeBottomPadding on EdgeInsets {
  /// Returns this padding with extra bottom space to clear the
  /// device's bottom system inset plus a small visual gap.
  EdgeInsets clearBottomInset(
    BuildContext context, {
    double extra = 24,
  }) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return copyWith(bottom: bottom + inset + extra);
  }
}

/// Same as [SafeBottomPadding.clearBottomInset] but for callers that
/// don't already have an [EdgeInsets] in hand.
EdgeInsets safeBottomPadding(
  BuildContext context, {
  double horizontal = 0,
  double top = 0,
  double extra = 24,
}) {
  final inset = MediaQuery.viewPaddingOf(context).bottom;
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    inset + extra,
  );
}
