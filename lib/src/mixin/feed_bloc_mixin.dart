import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';

import '../error/errors.dart';
import '../feed_bloc.dart';

/// A mixin which enables automatic state persistence
/// for [Bloc] and [Cubit] classes.
///
/// The [feed] method must be invoked in the constructor body
/// when using the [FeedBlocMixin] directly.
///
/// If a mixin is not necessary, it is recommended to
/// extend [FeedBloc] and [FeedCubit] respectively.
///
/// ```dart
/// class CounterBloc extends Bloc<CounterEvent, int> with FeedMixin {
///  CounterBloc() : super(0) {
///    feed();
///  }
///  ...
/// }
/// ```
///
/// See also:
///
/// * [FeedBloc] to enable automatic state persistence/restoration with [Bloc]
/// * [FeedCubit] to enable automatic state persistence/restoration with [Cubit]
///
mixin FeedBlocMixin<State> on BlocBase<State> {
  /// Populates the internal state storage with the latest state.
  /// This should be called when using the [FeedBlocMixin]
  /// directly within the constructor body.
  ///
  /// ```dart
  /// class CounterBloc extends Bloc<CounterEvent, int> with FeedMixin {
  ///  CounterBloc() : super(0) {
  ///    feed();
  ///  }
  ///  ...
  /// }
  /// ```
  void feed() {
    final storage = FeedBloc.storage;
    try {
      final stateJson = _toJson(state);
      if (stateJson != null) {
        storage.write(storageToken, stateJson).then((_) {}, onError: onError);
      }
    } catch (error, stackTrace) {
      onError(error, stackTrace);
      if (error is StorageNotFound) rethrow;
    }
  }

  State? _state;

  @override
  State get state {
    final storage = FeedBloc.storage;
    if (_state != null) return _state!;
    try {
      final stateJson = storage.read(storageToken) as Map<dynamic, dynamic>?;
      if (stateJson == null) {
        _state = super.state;
        return super.state;
      }
      final cachedState = _fromJson(stateJson);
      if (cachedState == null) {
        _state = super.state;
        return super.state;
      }
      _state = cachedState;
      return cachedState;
    } catch (error, stackTrace) {
      onError(error, stackTrace);
      _state = super.state;
      return super.state;
    }
  }

  @override
  void onChange(Change<State> change) {
    super.onChange(change);
    final storage = FeedBloc.storage;
    final state = change.nextState;
    try {
      final stateJson = _toJson(state);
      if (stateJson != null) {
        storage.write(storageToken, stateJson).then((_) {}, onError: onError);
      }
    } catch (error, stackTrace) {
      onError(error, stackTrace);
      rethrow;
    }
    _state = state;
  }

  State? _fromJson(dynamic json) {
    final dynamic traversedJson = _traverseRead(json);
    final castJson = _cast<Map<String, dynamic>>(traversedJson);
    return fromJson(castJson ?? <String, dynamic>{});
  }

  Map<String, dynamic>? _toJson(State state) {
    return _cast<Map<String, dynamic>>(_traverseWrite(toJson(state)).value);
  }

  dynamic _traverseRead(dynamic value) {
    if (value is Map) {
      return value.map<String, dynamic>((dynamic key, dynamic value) {
        return MapEntry<String, dynamic>(
          _cast<String>(key) ?? '',
          _traverseRead(value),
        );
      });
    }
    if (value is List) {
      for (var i = 0; i < value.length; i++) {
        value[i] = _traverseRead(value[i]);
      }
    }
    return value;
  }

  T? _cast<T>(dynamic x) => x is T ? x : null;

  _Traversed _traverseWrite(Object? value) {
    final dynamic traversedAtomicJson = _traverseAtomicJson(value);
    if (traversedAtomicJson is! NIL) {
      return _Traversed.atomic(traversedAtomicJson);
    }
    final dynamic traversedComplexJson = _traverseComplexJson(value);
    if (traversedComplexJson is! NIL) {
      return _Traversed.complex(traversedComplexJson);
    }
    try {
      _checkCycle(value);
      final dynamic customJson = _toEncodable(value);
      final dynamic traversedCustomJson = _traverseJson(customJson);
      if (traversedCustomJson is NIL) {
        throw FeedUnsupportedError(value);
      }
      _removeSeen(value);
      return _Traversed.complex(traversedCustomJson);
    } on FeedCyclicError catch (e) {
      throw FeedUnsupportedError(value, cause: e);
    } on FeedUnsupportedError {
      rethrow; // do not stack `FeedUnsupportedError`
    } catch (e) {
      throw FeedUnsupportedError(value, cause: e);
    }
  }

  dynamic _traverseAtomicJson(dynamic object) {
    if (object is num) {
      if (!object.isFinite) return const NIL();
      return object;
    } else if (identical(object, true)) {
      return true;
    } else if (identical(object, false)) {
      return false;
    } else if (object == null) {
      return null;
    } else if (object is String) {
      return object;
    }
    return const NIL();
  }

  dynamic _traverseComplexJson(dynamic object) {
    if (object is List) {
      if (object.isEmpty) return object;
      _checkCycle(object);
      List<dynamic>? list;
      for (var i = 0; i < object.length; i++) {
        final traversed = _traverseWrite(object[i]);
        list ??= traversed.outcome == _Outcome.atomic
            ? object.sublist(0)
            : (<dynamic>[]..length = object.length);
        list[i] = traversed.value;
      }
      _removeSeen(object);
      return list;
    } else if (object is Map) {
      _checkCycle(object);
      final map = <String, dynamic>{};
      object.forEach((dynamic key, dynamic value) {
        final castKey = _cast<String>(key);
        if (castKey != null) {
          map[castKey] = _traverseWrite(value).value;
        }
      });
      _removeSeen(object);
      return map;
    }
    return const NIL();
  }

  dynamic _traverseJson(dynamic object) {
    final dynamic traversedAtomicJson = _traverseAtomicJson(object);
    return traversedAtomicJson is! NIL ? traversedAtomicJson : _traverseComplexJson(object);
  }

  // ignore: avoid_dynamic_calls
  dynamic _toEncodable(dynamic object) => object.toJson();

  final _seen = <dynamic>[];

  void _checkCycle(Object? object) {
    for (var i = 0; i < _seen.length; i++) {
      if (identical(object, _seen[i])) {
        throw FeedCyclicError(object);
      }
    }
    _seen.add(object);
  }

  void _removeSeen(dynamic object) {
    assert(_seen.isNotEmpty, 'seen must not be empty');
    assert(identical(_seen.last, object), 'last seen object must be identical');
    _seen.removeLast();
  }

  /// [id] is used to uniquely identify multiple instances
  /// of the same [FeedBloc] type.
  /// In most cases it is not necessary;
  /// however, if you wish to intentionally have multiple instances
  /// of the same [FeedBloc], then you must override [id]
  /// and return a unique identifier for each [FeedBloc] instance
  /// in order to keep the caches independent of each other.
  String get id => '';

  /// Storage prefix which can be overridden to provide a custom
  /// storage namespace.
  /// Defaults to [runtimeType] but should be overridden in cases
  /// where stored data should be resilient to obfuscation or persist
  /// between debug/release builds.
  String get storagePrefix => runtimeType.toString();

  /// `storageToken` is used as registration token for hydrated storage.
  /// Composed of [storagePrefix] and [id].
  @nonVirtual
  String get storageToken => '$storagePrefix$id';

  /// [clear] is used to wipe or invalidate the cache of a [FeedBloc].
  /// Calling [clear] will delete the cached state of the bloc
  /// but will not modify the current state of the bloc.
  Future<void> clear() => FeedBloc.storage.delete(storageToken);

  /// Responsible for converting the `Map<String, dynamic>` representation
  /// of the bloc state into a concrete instance of the bloc state.
  State? fromJson(Map<String, dynamic> json);

  /// Responsible for converting a concrete instance of the bloc state
  /// into the the `Map<String, dynamic>` representation.
  ///
  /// If [toJson] returns `null`, then no state changes will be persisted.
  Map<String, dynamic>? toJson(State state);
}

/// {@template NIL}
/// Type which represents objects that do not support json encoding
///
/// This should never be used and is exposed only for testing purposes.
/// {@endtemplate}
@visibleForTesting
class NIL {
  /// {@macro NIL}
  const NIL();
}

enum _Outcome { atomic, complex }

class _Traversed {
  _Traversed._({required this.outcome, required this.value});

  _Traversed.atomic(dynamic value) : this._(outcome: _Outcome.atomic, value: value);

  _Traversed.complex(dynamic value) : this._(outcome: _Outcome.complex, value: value);
  final _Outcome outcome;
  final dynamic value;
}
