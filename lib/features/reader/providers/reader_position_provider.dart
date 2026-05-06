import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../characters/services/spoiler_position.dart';

/// Tracks the reader's current position globally so non-reader screens
/// (Characters list, sheets opened from outside the reader) can filter
/// spoiler-anchored content against where the user actually is in the
/// story. Set to null when no book is open — listeners should treat
/// that as "show everything", not "block everything".
final currentReaderPositionProvider =
    StateProvider<ReaderPosition?>((_) => null);
