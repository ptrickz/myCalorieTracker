import "package:flutter/material.dart";
import "package:flutter/rendering.dart";

/// Transparent app bar that slides up out of view while the user scrolls
/// down and returns as soon as they scroll back up. Use together with
/// [AppBarVisibilityMixin], which owns the visibility flag and translates
/// scroll notifications into it.
class HidingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool visible;
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;

  const HidingAppBar({
    super.key,
    required this.visible,
    this.title,
    this.leading,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, -1.5),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: AppBar(title: title, leading: leading, actions: actions),
      ),
    );
  }
}

/// Owns the [appBarVisible] flag for a screen with a [HidingAppBar]. Wrap the
/// screen's scrollable in a `NotificationListener<UserScrollNotification>`
/// and pass [handleScrollNotification] as its onNotification.
mixin AppBarVisibilityMixin<T extends StatefulWidget> on State<T> {
  bool appBarVisible = true;

  bool handleScrollNotification(UserScrollNotification notification) {
    // Only the page's own scrollable (depth 0) drives visibility — nested
    // scrollables (the workout week calendar, capped inner lists) shouldn't
    // toggle the bar.
    if (notification.depth != 0) return false;
    if (notification.direction == ScrollDirection.reverse && appBarVisible) {
      setState(() => appBarVisible = false);
    } else if (notification.direction == ScrollDirection.forward && !appBarVisible) {
      setState(() => appBarVisible = true);
    }
    return false;
  }
}
