import 'dart:math';
import 'dart:ui';

import './overflow_rules.dart';
import 'package:flutter/material.dart';

class ColorfulSafeArea extends StatelessWidget {
  const ColorfulSafeArea({
    super.key,
    this.color = Colors.transparent,
    this.topColor = Colors.transparent,
    this.bottomColor = Colors.transparent,
    this.overflowRules = const OverflowRules.all(false),
    this.overflowTappable = false,
    this.bottom = true,
    this.left = true,
    this.top = true,
    this.right = true,
    this.minimum = EdgeInsets.zero,
    this.maintainBottomViewPadding = false,
    this.filter,
    required this.child,
  });

  final Color color;
  final Color topColor;
  final Color bottomColor;
  final OverflowRules overflowRules;
  final bool overflowTappable;

  final bool left;
  final bool top;
  final bool right;
  final bool bottom;
  final EdgeInsets minimum;
  final bool maintainBottomViewPadding;
  final Widget child;
  final ImageFilter? filter;

  @override
  Widget build(BuildContext context) {
    MediaQueryData data = MediaQuery.of(context);
    EdgeInsets padding = _createAdjustedPadding(data);
    EdgeInsets adjustedMinimum = _createAdjustedMinimum();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: <Widget>[
            SafeArea(
              left: !overflowRules.left && left,
              top: !overflowRules.top && top,
              right: !overflowRules.right && right,
              bottom: !overflowRules.bottom && bottom,
              minimum: adjustedMinimum,
              maintainBottomViewPadding: maintainBottomViewPadding,
              child: child,
            ),
            _Top(
              color: topColor != Colors.transparent ? topColor : color,
              padding: padding,
              overflowTappable: overflowTappable,
              constraints: constraints,
              filter: filter,
            ),
            _Bottom(
              color: bottomColor != Colors.transparent ? bottomColor : color,
              padding: padding,
              overflowTappable: overflowTappable,
              constraints: constraints,
              filter: filter,
            ),
            _LeftAndRight(
              color: color,
              padding: padding,
              overflowTappable: overflowTappable,
              constraints: constraints,
              filter: filter,
            ),
          ],
        );
      },
    );
  }

  // calculates the padding required
  EdgeInsets _createAdjustedPadding(MediaQueryData data) {
    return EdgeInsets.only(
      left: (left) ? max(data.padding.left, minimum.left) : minimum.left,
      top: (top) ? max(data.padding.top, minimum.top) : minimum.top,
      right: (right) ? max(data.padding.right, minimum.right) : minimum.right,
      bottom:
          (bottom) ? max(data.padding.bottom, minimum.bottom) : minimum.bottom,
    );
  }

  // ignores the minimum for a side if it is allowed to overflow
  EdgeInsets _createAdjustedMinimum() {
    return minimum.copyWith(
      left: overflowRules.left ? 0 : minimum.left,
      top: overflowRules.top ? 0 : minimum.top,
      right: overflowRules.right ? 0 : minimum.right,
      bottom: overflowRules.bottom ? 0 : minimum.bottom,
    );
  }
}

class _Top extends StatelessWidget {
  const _Top({
    required this.color,
    required this.padding,
    required this.overflowTappable,
    required this.constraints,
    this.filter,
  });

  final Color color;
  final EdgeInsets padding;
  final bool overflowTappable;
  final BoxConstraints constraints;
  final ImageFilter? filter;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: overflowTappable,
      child: Column(
        children: <Widget>[
          (filter != null)
              ? ClipRect(
                  child: BackdropFilter(
                    filter: filter!,
                    child: Container(
                      height: padding.top,
                      width: constraints.maxWidth,
                      color: color,
                    ),
                  ),
                )
              : Container(
                  height: padding.top,
                  width: constraints.maxWidth,
                  color: color,
                ),
        ],
      ),
    );
  }
}

class _Bottom extends StatelessWidget {
  const _Bottom({
    required this.color,
    required this.padding,
    required this.overflowTappable,
    required this.constraints,
    this.filter,
  });

  final Color color;
  final EdgeInsets padding;
  final bool overflowTappable;
  final BoxConstraints constraints;
  final ImageFilter? filter;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: overflowTappable,
      child: Column(
        children: <Widget>[
          const Spacer(),
          (filter != null)
              ? ClipRect(
                  child: BackdropFilter(
                    filter: filter!,
                    child: Container(
                      height: padding.bottom,
                      width: constraints.maxWidth,
                      color: color,
                    ),
                  ),
                )
              : Container(
                  height: padding.bottom,
                  width: constraints.maxWidth,
                  color: color,
                ),
        ],
      ),
    );
  }
}

class _LeftAndRight extends StatelessWidget {
  const _LeftAndRight({
    required this.color,
    required this.padding,
    required this.overflowTappable,
    required this.constraints,
    this.filter,
  });

  final Color color;
  final EdgeInsets padding;
  final bool overflowTappable;
  final BoxConstraints constraints;
  final ImageFilter? filter;

  double get _sideHeight =>
      constraints.maxHeight - padding.top - padding.bottom;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: overflowTappable,
      child: Row(
        children: <Widget>[
          Column(
            children: <Widget>[
              SizedBox(
                height: padding.top,
              ),
              (filter != null)
                  ? ClipRect(
                      child: BackdropFilter(
                        filter: filter!,
                        child: Container(
                          width: padding.left,
                          height: _sideHeight,
                          color: color,
                        ),
                      ),
                    )
                  : Container(
                      width: padding.left,
                      height: _sideHeight,
                      color: color,
                    ),
            ],
          ),
          const Spacer(),
          Column(
            children: <Widget>[
              SizedBox(
                height: padding.top,
              ),
              (filter != null)
                  ? ClipRect(
                      child: BackdropFilter(
                        filter: filter!,
                        child: Container(
                          width: padding.right,
                          height: _sideHeight,
                          color: color,
                        ),
                      ),
                    )
                  : Container(
                      width: padding.right,
                      height: _sideHeight,
                      color: color,
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
