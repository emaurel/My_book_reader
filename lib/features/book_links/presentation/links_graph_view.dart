import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphview/GraphView.dart';

import '../../../main.dart';
import '../../library/domain/book.dart';
import '../../library/providers/library_provider.dart';
import '../domain/book_link.dart';
import '../providers/book_link_provider.dart';
import 'widgets/book_links_sheet.dart';

const _positionsPrefsKey = 'book_links.graph_positions';
const _transformPrefsKey = 'book_links.graph_transform';

/// Force-directed graph of all books that participate in cross-book
/// links. The first build runs Fruchterman-Reingold to lay nodes out;
/// after that they stay put unless the user drags them. Tapping a node
/// opens a sheet with the book's incoming / outgoing links.
class LinksGraphView extends ConsumerStatefulWidget {
  const LinksGraphView({super.key});

  @override
  ConsumerState<LinksGraphView> createState() => _LinksGraphViewState();
}

class _LinksGraphViewState extends ConsumerState<LinksGraphView> {
  Graph? _graph;
  Algorithm? _algorithm;
  int? _lastLinksHash;

  /// True while a finger is on a node — used to disable the
  /// InteractiveViewer's pan so the node grabs the gesture instead of
  /// the canvas.
  bool _draggingNode = false;

  /// Cached node positions keyed by bookId. Loaded from
  /// SharedPreferences on init, written back on drag end and after
  /// the first auto-layout.
  Map<int, Offset> _storedPositions = const {};

  late final TransformationController _transformController;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_positionsPrefsKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _storedPositions = {
          for (final e in decoded.entries)
            int.parse(e.key): Offset(
              (e.value['x'] as num).toDouble(),
              (e.value['y'] as num).toDouble(),
            ),
        };
      } catch (_) {
        // Corrupt prefs — fall back to fresh layout.
      }
    }

    _transformController = TransformationController();
    final tRaw = prefs.getString(_transformPrefsKey);
    if (tRaw != null) {
      try {
        final list = (jsonDecode(tRaw) as List)
            .map((e) => (e as num).toDouble())
            .toList();
        if (list.length == 16) {
          _transformController.value = Matrix4.fromList(list);
        }
      } catch (_) {/* fall back to identity */}
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _saveTransform() {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(
      _transformPrefsKey,
      jsonEncode(_transformController.value.storage.toList()),
    );
  }

  void _savePositions() {
    if (_graph == null) return;
    final map = <String, Map<String, double>>{};
    final next = <int, Offset>{};
    for (final node in _graph!.nodes) {
      final id = node.key!.value as int;
      map[id.toString()] = {
        'x': node.position.dx,
        'y': node.position.dy,
      };
      next[id] = node.position;
    }
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_positionsPrefsKey, jsonEncode(map));
    _storedPositions = next;
  }

  /// Rebuild the underlying graph instance only when the link list
  /// itself changes. Otherwise we'd reset positions on every Riverpod
  /// notification (and the user's drags would snap back).
  void _maybeRebuildGraph(List<BookLink> linkList) {
    final hash = Object.hashAll(
      linkList.map((l) => Object.hash(
            l.id,
            l.sourceBookId,
            l.targetBookId,
          )),
    );
    if (hash == _lastLinksHash && _graph != null) return;
    _lastLinksHash = hash;

    final graph = Graph();
    final byId = <int, Node>{};
    final touched = <int>{};
    for (final link in linkList) {
      touched.add(link.sourceBookId);
      touched.add(link.targetBookId);
    }
    for (final id in touched) {
      final node = Node.Id(id);
      byId[id] = node;
      graph.addNode(node);
    }
    for (final link in linkList) {
      graph.addEdge(
        byId[link.sourceBookId]!,
        byId[link.targetBookId]!,
      );
    }
    _graph = graph;
    _algorithm = _PinnedOrLayoutAlgorithm(
      fallback: FruchtermanReingoldAlgorithm(
        FruchtermanReingoldConfiguration(iterations: 1000),
      ),
      positions: _storedPositions,
      onLaidOut: () {
        // After the first layout pass we capture whatever positions
        // FRA produced so the next session sees them already pinned.
        // Schedule the prefs write off the build phase.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _savePositions();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final links = ref.watch(bookLinksProvider);
    final library = ref.watch(libraryProvider);

    return links.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (linkList) {
        if (linkList.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No links yet — add some from the reader\'s '
                'selection menu first.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return library.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (books) {
            _maybeRebuildGraph(linkList);
            final byId = {for (final b in books) b.id: b};
            return InteractiveViewer(
              constrained: false,
              transformationController: _transformController,
              onInteractionEnd: (_) => _saveTransform(),
              panEnabled: !_draggingNode,
              scaleEnabled: !_draggingNode,
              minScale: 0.2,
              maxScale: 4,
              boundaryMargin: const EdgeInsets.all(800),
              child: GraphView(
                graph: _graph!,
                algorithm: _algorithm!,
                // Disable graphview's built-in position lerp so dragged
                // nodes track the finger 1:1 instead of easing toward
                // the target position over 600ms.
                animated: false,
                paint: Paint()
                  ..color = Theme.of(context).colorScheme.outline
                  ..strokeWidth = 1.4
                  ..style = PaintingStyle.stroke,
                builder: (node) {
                  final bookId = node.key!.value as int;
                  final book = byId[bookId];
                  return _DraggableBookNode(
                    book: book,
                    bookId: bookId,
                    onTap: () => showBookLinksSheet(context, bookId),
                    onDragStart: () =>
                        setState(() => _draggingNode = true),
                    onDragEnd: () {
                      setState(() => _draggingNode = false);
                      _savePositions();
                    },
                    onDrag: (delta) {
                      setState(() {
                        node.position = node.position.translate(
                          delta.dx,
                          delta.dy,
                        );
                      });
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// Layout algorithm with two modes:
///   * If every current node has a stored position, snap each node to
///     it and skip simulation — this preserves the user's hand-tuned
///     layout across sessions.
///   * Otherwise, fall back to the wrapped force-directed algorithm
///     for a one-time layout, then overlay any stored positions on
///     top so existing books keep their saved spots.
/// In both cases [run] executes exactly once, so subsequent paints
/// don't perturb positions.
class _PinnedOrLayoutAlgorithm implements Algorithm {
  _PinnedOrLayoutAlgorithm({
    required Algorithm fallback,
    required Map<int, Offset> positions,
    required VoidCallback onLaidOut,
  })  : _fallback = fallback,
        _positions = positions,
        _onLaidOut = onLaidOut;

  final Algorithm _fallback;
  final Map<int, Offset> _positions;
  final VoidCallback _onLaidOut;
  bool _ran = false;
  Size _lastSize = Size.zero;

  @override
  EdgeRenderer? get renderer => _fallback.renderer;

  @override
  set renderer(EdgeRenderer? r) => _fallback.renderer = r;

  @override
  void init(Graph? graph) => _fallback.init(graph);

  @override
  void setDimensions(double width, double height) =>
      _fallback.setDimensions(width, height);

  @override
  Size run(Graph? graph, double shiftX, double shiftY) {
    if (_ran || graph == null) return _lastSize;
    _ran = true;
    final allKnown = graph.nodes.every((n) {
      final id = n.key!.value as int;
      return _positions.containsKey(id);
    });
    if (allKnown) {
      for (final node in graph.nodes) {
        final id = node.key!.value as int;
        node.position = _positions[id]!;
      }
      _lastSize = graph.calculateGraphSize();
    } else {
      _lastSize = _fallback.run(graph, shiftX, shiftY);
      for (final node in graph.nodes) {
        final id = node.key!.value as int;
        final stored = _positions[id];
        if (stored != null) {
          node.position = stored;
        }
      }
    }
    _onLaidOut();
    return _lastSize;
  }
}

class _DraggableBookNode extends StatefulWidget {
  const _DraggableBookNode({
    required this.book,
    required this.bookId,
    required this.onTap,
    required this.onDrag,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final Book? book;
  final int bookId;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final void Function(Offset delta) onDrag;

  @override
  State<_DraggableBookNode> createState() => _DraggableBookNodeState();
}

class _DraggableBookNodeState extends State<_DraggableBookNode> {
  Offset? _pointerStart;
  bool _movedEnoughToBeDrag = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverPath = widget.book?.coverPath;
    final hasCover = coverPath != null && File(coverPath).existsSync();
    // Outer Listener uses raw pointer events so the node always wins
    // the gesture race with InteractiveViewer (we toggle the parent's
    // panEnabled flag in the parent's onDragStart / onDragEnd).
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        _pointerStart = event.position;
        _movedEnoughToBeDrag = false;
        widget.onDragStart();
      },
      onPointerMove: (event) {
        widget.onDrag(event.delta);
        if (_pointerStart != null &&
            (event.position - _pointerStart!).distance > 6) {
          _movedEnoughToBeDrag = true;
        }
      },
      onPointerUp: (event) {
        widget.onDragEnd();
        if (!_movedEnoughToBeDrag) widget.onTap();
        _pointerStart = null;
      },
      onPointerCancel: (_) {
        widget.onDragEnd();
        _pointerStart = null;
      },
      child: Padding(
        // Extends the hit target beyond the visible card.
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 110,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: hasCover
                    ? Image.file(
                        File(coverPath),
                        width: 96,
                        height: 132,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 96,
                        height: 132,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.book_outlined),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.book?.title ?? '#${widget.bookId}',
                style: theme.textTheme.labelSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
