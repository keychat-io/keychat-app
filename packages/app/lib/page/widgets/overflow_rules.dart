class OverflowRules {
  const OverflowRules.all(bool value)
      : left = value,
        top = value,
        right = value,
        bottom = value;

  const OverflowRules.symmetric({
    bool vertical = false,
    bool horizontal = false,
  })  : left = horizontal,
        top = vertical,
        right = horizontal,
        bottom = vertical;

  const OverflowRules.only({
    this.left = false,
    this.top = false,
    this.right = false,
    this.bottom = false,
  });

  final bool left;
  final bool top;
  final bool right;
  final bool bottom;

  bool get allowsOverflow {
    return (left || top || right || bottom);
  }
}
