import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/models.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets.dart';

/// Room above the avatar where the love bubbles float.
const _bubbleSpace = 64.0;
const _pinWidth = 96.0;

/// Size of the marker box for a pin with an avatar of [avatarSize]; the box's bottom
/// center is the pin tip, so use `Alignment.topCenter` on the `Marker`.
Size userPinSize(double avatarSize) => Size(_pinWidth, avatarSize + 12 + _bubbleSpace);

/// Map marker: the user's profile picture in a colored ring with a diamond pointer.
/// While [movement] is set it shows a movement badge and floating love bubbles.
class UserPin extends StatelessWidget {
  const UserPin({
    super.key,
    required this.user,
    required this.color,
    required this.avatarSize,
    this.movement,
    this.faded = false,
  });

  final AppUser user;
  final Color color;
  final double avatarSize;
  final Movement? movement;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final size = userPinSize(avatarSize);
    final pinLeft = (size.width - avatarSize) / 2;
    final avatarTop = size.height - avatarSize - 12;
    final m = movement;

    return Opacity(
      opacity: faded ? 0.85 : 1,
      child: Stack(clipBehavior: Clip.none, children: [
        if (m != null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: avatarTop + avatarSize / 2,
            child: const IgnorePointer(child: _LoveBubbles()),
          ),
        Positioned(
          left: pinLeft + avatarSize / 2 - 7,
          top: avatarTop + avatarSize - 7,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
        Positioned(
          left: pinLeft,
          top: avatarTop,
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
              boxShadow: floatingShadow,
            ),
            child: UserAvatar(user: user, size: avatarSize - 6, fontSize: avatarSize * 0.375),
          ),
        ),
        if (m != null)
          Positioned(
            left: pinLeft + avatarSize - 16,
            top: avatarTop - 6,
            child: Tooltip(
              message: movementLabel(m),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: floatingShadow,
                ),
                child: Icon(movementIcon(m), size: 14, color: Colors.white, fill: 1),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Little heart bubbles that rise from the pin, sway and fade out, on a loop.
class _LoveBubbles extends StatefulWidget {
  const _LoveBubbles();

  @override
  State<_LoveBubbles> createState() => _LoveBubblesState();
}

class _LoveBubblesState extends State<_LoveBubbles> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));

  // (size, horizontal offset from center, phase offset)
  static const _bubbles = [(22.0, -14.0, 0.0), (15.0, 13.0, 0.2), (19.0, 2.0, 0.4), (14.0, -8.0, 0.6), (17.0, 17.0, 0.8)];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the system "remove animations" setting with a still frame.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.35;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => LayoutBuilder(builder: (context, box) {
        return Stack(clipBehavior: Clip.none, children: [
          for (final (size, dx, offset) in _bubbles) _bubble(box, size, dx, (_controller.value + offset) % 1),
        ]);
      }),
    );
  }

  Widget _bubble(BoxConstraints box, double size, double dx, double t) {
    // Fade in quickly, then fade out while rising.
    final opacity = t < 0.15 ? t / 0.15 : (1 - t) / 0.85;
    final sway = math.sin(t * math.pi * 2 + dx) * 6;
    final scale = 0.55 + 0.45 * math.min(1, t * 2.5);
    final left = box.maxWidth / 2 + dx + sway - size / 2;
    final top = (box.maxHeight - size) * (1 - t);

    return Positioned(
      left: left,
      top: top,
      child: Opacity(
        opacity: opacity.clamp(0, 1).toDouble(),
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.love.withValues(alpha: 0.18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1),
            ),
            child: Icon(Symbols.favorite_rounded, size: size * 0.62, color: AppColors.love, fill: 1),
          ),
        ),
      ),
    );
  }
}
