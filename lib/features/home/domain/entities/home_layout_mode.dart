/// The two home ("Баш бит") presentation modes the user can toggle between.
/// The choice is remembered locally (see [HomeLayoutPreferenceRepository]).
enum HomeLayoutMode {
  /// Modern vertical social feed: large cover, comfortable typography.
  feed,

  /// Classic grid of cards.
  cards;

  String get wireValue => name;

  static HomeLayoutMode fromWireValue(String? value) {
    return HomeLayoutMode.values.firstWhere(
      (v) => v.wireValue == value,
      orElse: () => HomeLayoutMode.feed,
    );
  }
}
