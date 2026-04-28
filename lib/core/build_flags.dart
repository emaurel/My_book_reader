/// Compile-time flags toggled via `--dart-define=...` at build time.
///
/// Pass `--dart-define=STORE_BUILD=true` to produce a Play-Store-safe
/// edition that hides the Anna's Archive WebView (the "Download books"
/// screen + drawer entry + route).
const kStoreBuild = bool.fromEnvironment('STORE_BUILD');
