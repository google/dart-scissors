library scissors.src.css_mirroring.util_classes;

import 'transformer.dart' show Direction;
import 'package:source_maps/refactor.dart';

/// Indicates which parts of a CSS must be retained.
enum RetentionMode {
  /// Keep parts of CSS which are direction-independent eg: color and width.
  keepBidiNeutral,

  /// Keep direction dependent parts of original CSS eg: margin.
  keepOriginalBidiSpecific,

  /// to keep direction dependent parts of flipped CSS.
  keepFlippedBidiSpecific
}

/// Stores the start and end locations of the pending removals.
class PendingRemovals {
  final String source;
  final TextEditTransaction transaction;

  // List to contain start and end location of pending removals.
  final _removalStartEndLocations = <_Range>[];

  PendingRemovals(TextEditTransaction trans)
      : transaction = trans,
        source = trans.file.getText(0);

  void remove(int start, int end) {
    _removalStartEndLocations.add(new _Range(start, end));
  }

  void commit() {
    _removalStartEndLocations.forEach((_Range p) {
      transaction.edit(p.start, p.end, '');
    });
    _removalStartEndLocations.clear();
  }

  List<_Range> getRemovalStartEndLocations() {
    return _removalStartEndLocations;
  }
}

class _Range {
  final int start;
  final int end;

  const _Range(this.start, this.end);
}

class FlippableEntity<T> {
  final FlippableEntities<T> _entities;
  final int index;
  FlippableEntity(this._entities, this.index);

  T get original => _entities.originals[index];
  T get flipped => _entities.flippeds[index];
  FlippableEntity<T> get next => index < _entities.originals.length - 1
      ? new FlippableEntity<T>(_entities, index + 1)
      : null;
}

class FlippableEntities<T> {
  final List<T> originals;
  final List<T> flippeds;

  FlippableEntities(this.originals, this.flippeds) {
    assert(originals.length == flippeds.length);
  }

  void forEach(void process(FlippableEntity<T> entity)) {
    for (int i = 0; i < originals.length; i++) {
      process(new FlippableEntity<T>(this, i));
    }
  }
}

class EditConfiguration {
  final RetentionMode mode;
  final Direction targetDirection;

  const EditConfiguration(this.mode, this.targetDirection);
}
