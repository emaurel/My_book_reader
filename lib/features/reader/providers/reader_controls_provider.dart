import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReaderControls {
  const ReaderControls({this.goPrev, this.goNext});

  final VoidCallback? goPrev;
  final VoidCallback? goNext;
}

/// Each viewer registers its prev/next callbacks here on init.
/// `ReaderScreen` reads these to dispatch tap-left / tap-right gestures.
final readerControlsProvider =
    StateProvider<ReaderControls>((_) => const ReaderControls());
