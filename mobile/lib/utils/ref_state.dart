import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A minimal [Notifier] for simple mutable state, replacing the Riverpod 2.x
/// [StateProvider] which was removed in Riverpod 3.x.
///
/// Usage:
/// ```dart
/// final myProvider = refStateProvider('default');
///
/// // Read:
/// final value = ref.watch(myProvider);
///
/// // Write:
/// ref.read(myProvider.notifier).setState('new value');
/// ```
/// A minimal [Notifier] for simple mutable state, replacing the Riverpod 2.x
/// [StateProvider] which was removed in Riverpod 3.x.
///
/// Usage:
/// ```dart
/// final myProvider = refStateProvider<String>('default');
///
/// // Read:
/// final value = ref.watch(myProvider);
///
/// // Write:
/// ref.read(myProvider.notifier).setState('new value');
/// ```
class RefState<T> extends Notifier<T> {
  /// Create a RefState with the given initial value.
  /// The initializer is called once when the provider is first read.
  RefState(T initialValue) : _initialValue = initialValue;

  final T _initialValue;

  @override
  T build() => _initialValue;

  /// Public setter for mutable state.
  /// Replaces `ref.read(provider.notifier).state = value` from Riverpod 2.x.
  void setState(T value) => state = value;
}

/// Creates a [NotifierProvider] for simple mutable state with an initial value.
/// This is the Riverpod 3.x replacement for [StateProvider].
///
/// Example:
/// ```dart
/// final counterProvider = refStateProvider<int>(0);
/// ```
NotifierProvider<RefState<T>, T> refStateProvider<T>(T initialValue) {
  return NotifierProvider<RefState<T>, T>(
    () => RefState<T>(initialValue),
  );
}
