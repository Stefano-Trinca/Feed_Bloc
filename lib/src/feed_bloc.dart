// ignore_for_file: avoid_catching_errors

import 'package:bloc/bloc.dart';
import 'package:feed_bloc/src/mixin/feed_mixin.dart';

import 'error/errors.dart';
import 'feed_storage.dart';
import 'mixin/feed_bloc_mixin.dart';

/// {@template feed_bloc}
/// Specialized [Bloc] which handles initializing the [Bloc] state
/// based on the persisted state. This allows state to be persisted
/// across hot restarts as well as complete app restarts.
///
/// ```dart
/// abstract class CounterEvent {}
/// class CounterIncrementPressed extends CounterEvent {}
/// class CounterDecrementPressed extends CounterEvent {}
///
/// class CounterBloc extends FeedBloc<CounterEvent, int> {
///   CounterBloc() : super(0) {
///     on<CounterIncrementPressed>((event, emit) => emit(state + 1));
///     on<CounterDecrementPressed>((event, emit) => emit(state - 1));
///   }
///
///   @override
///   int fromJson(Map<String, dynamic> json) => json['value'] as int;
///
///   @override
///   Map<String, int> toJson(int state) => {'value': state};
/// }
/// ```
///
/// {@endtemplate}
abstract class FeedBloc<Event, State> extends Bloc<Event, State> with FeedBlocMixin {
  /// {@macro feed_bloc}
  FeedBloc(State state) : super(state) {
    feed();
  }

  static Storage? _storage;

  /// Setter for instance of [Storage] which will be used to
  /// manage persisting/restoring the [Bloc] state.
  static set storage(Storage? storage) => _storage = storage;

  /// Instance of [Storage] which will be used to
  /// manage persisting/restoring the [Bloc] state.
  static Storage get storage {
    if (_storage == null) throw const StorageNotFound();
    return _storage!;
  }
}

/// {@template feed_cubit}
/// Specialized [Cubit] which handles initializing the [Cubit] state
/// based on the persisted state. This allows state to be persisted
/// across application restarts.
///
/// ```dart
/// class CounterCubit extends FeedCubit<int> {
///   CounterCubit() : super(0);
///
///   void increment() => emit(state + 1);
///   void decrement() => emit(state - 1);
///
///   @override
///   int fromJson(Map<String, dynamic> json) => json['value'] as int;
///
///   @override
///   Map<String, int> toJson(int state) => {'value': state};
/// }
/// ```
///
/// {@endtemplate}
abstract class FeedCubit<State> extends Cubit<State> with FeedBlocMixin<State> {
  /// {@macro feed_cubit}
  FeedCubit(State state) : super(state) {
    feed();
  }
}


/// {@template feed}
/// Specialized Class which handles initializing the Class variables
/// based on the persisted state.
///
/// ```dart
/// class CounterClass extends Feed {
///   CounterClass();
///
///   @override
///   int fromJson(Map<String, dynamic> json) => json['value'] as int;
///
///   @override
///   Map<String, int> toJson(int state) => {'value': state};
/// }
/// ```
///
/// {@endtemplate}
abstract class Feed with FeedMixin{
  /// {@macro feed}
  Feed(){
    feed();
  }
}

