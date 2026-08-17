import 'package:flutter/material.dart';

class WavePageRoute<T> extends MaterialPageRoute<T> {
  WavePageRoute({required super.builder, this.motionEnabled = true});

  final bool motionEnabled;

  @override
  Duration get transitionDuration =>
      motionEnabled ? const Duration(milliseconds: 220) : Duration.zero;

  @override
  Duration get reverseTransitionDuration =>
      motionEnabled ? const Duration(milliseconds: 180) : Duration.zero;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final page = ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
    if (!motionEnabled) return page;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(.025, 0),
            end: Offset.zero,
          ).animate(curved),
          child: page,
        ),
      ),
    );
  }
}
