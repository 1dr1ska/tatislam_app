import 'package:flutter_riverpod/legacy.dart' as legacy;

export 'package:flutter_riverpod/legacy.dart'
    show
        StateProvider,
        StateController;

/// Version counter that increments after any publication create/update/delete.
/// Watched by [mainPublicationsProvider] to trigger automatic refresh.
final publicationListVersionProvider = legacy.StateProvider<int>((ref) => 0);

/// Current search query text (updated immediately on every keystroke).
final searchQueryProvider = legacy.StateProvider<String>((ref) => '');

/// Whether to show only favorites.
final favoritesFilterProvider = legacy.StateProvider<bool>((ref) => false);