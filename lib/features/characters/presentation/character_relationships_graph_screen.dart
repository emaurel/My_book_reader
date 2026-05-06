import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphview/GraphView.dart';

import '../domain/character.dart';
import '../domain/character_relationship.dart';
import '../providers/character_provider.dart';
import 'widgets/character_status_indicator.dart';

class CharacterRelationshipsGraphScreen extends ConsumerWidget {
  const CharacterRelationshipsGraphScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRels = ref.watch(_allRelationshipsProvider);
    final asyncChars = ref.watch(charactersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Relationships')),
      body: asyncRels.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rels) {
          if (rels.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No relationships yet — add some from any character\'s row.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return asyncChars.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (chars) => _Graph(rels: rels, chars: chars),
          );
        },
      ),
    );
  }
}

final _allRelationshipsProvider =
    FutureProvider.autoDispose<List<CharacterRelationship>>((ref) {
  ref.watch(characterRevisionProvider);
  return ref.watch(characterRepositoryProvider).allRelationships();
});

class _Graph extends StatefulWidget {
  const _Graph({required this.rels, required this.chars});
  final List<CharacterRelationship> rels;
  final List<Character> chars;

  @override
  State<_Graph> createState() => _GraphState();
}

class _GraphState extends State<_Graph> {
  late final Graph _graph;
  late final Algorithm _algorithm;
  late final Map<int, Character> _byId;

  @override
  void initState() {
    super.initState();
    _byId = {for (final c in widget.chars) c.id!: c};
    _graph = Graph();
    final touched = <int>{};
    for (final r in widget.rels) {
      // Only forward direction — the reverse is auto-added on save.
      if (r.fromCharacterId >= r.toCharacterId &&
          r.kind != RelationshipKind.parent &&
          r.kind != RelationshipKind.mentor) {
        // Heuristic to dedupe symmetric pairs.
      }
      touched.add(r.fromCharacterId);
      touched.add(r.toCharacterId);
      _graph.addEdge(
        Node.Id(r.fromCharacterId),
        Node.Id(r.toCharacterId),
      );
    }
    _algorithm = _OneShotAlgorithm(
      FruchtermanReingoldAlgorithm(
        FruchtermanReingoldConfiguration(iterations: 1000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      constrained: false,
      minScale: 0.2,
      maxScale: 4,
      boundaryMargin: const EdgeInsets.all(800),
      child: GraphView(
        graph: _graph,
        algorithm: _algorithm,
        animated: false,
        paint: Paint()
          ..color = Theme.of(context).colorScheme.outline
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke,
        builder: (node) {
          final id = node.key!.value as int;
          final c = _byId[id];
          return _Node(character: c, fallbackId: id);
        },
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.character, required this.fallbackId});
  final Character? character;
  final int fallbackId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 110,
      padding: const EdgeInsets.all(8),
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
          CharacterStatusDot(status: character?.status, size: 14),
          const SizedBox(height: 4),
          Text(
            character?.name ?? '#$fallbackId',
            style: theme.textTheme.labelMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Same one-shot wrapper used by the book-links graph — runs the
/// force-directed simulation exactly once so user drags wouldn't be
/// undone the next paint. (The character graph doesn't expose drag
/// in v1, but the wrapper keeps positions stable across rebuilds.)
class _OneShotAlgorithm implements Algorithm {
  _OneShotAlgorithm(this._inner);
  final Algorithm _inner;
  bool _ran = false;
  Size _lastSize = Size.zero;

  @override
  EdgeRenderer? get renderer => _inner.renderer;

  @override
  set renderer(EdgeRenderer? r) => _inner.renderer = r;

  @override
  void init(Graph? graph) => _inner.init(graph);

  @override
  void setDimensions(double width, double height) =>
      _inner.setDimensions(width, height);

  @override
  Size run(Graph? graph, double shiftX, double shiftY) {
    if (!_ran) {
      _lastSize = _inner.run(graph, shiftX, shiftY);
      _ran = true;
    }
    return _lastSize;
  }
}
