import 'dart:async';
import 'package:flutter/material.dart';

import 'package:drapemind_mobile/core/services/navigation_service.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';

class InAppNotificationBanner {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;
  static GlobalKey<_BannerWidgetState>? _bannerKey;

  static void show({
    required String title,
    required String message,
    required String screen,
    Map<String, dynamic>? data,
  }) {
    dismissImmediate();

    final overlay = NavigationService.navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _bannerKey = GlobalKey<_BannerWidgetState>();

    _currentEntry = OverlayEntry(
      builder: (context) => _BannerWidget(
        key: _bannerKey,
        title: title,
        message: message,
        screen: screen,
        data: data,
        onClose: () => dismiss(),
        onTap: () {
          dismiss(onComplete: () {
            NavigationService.navigateTo(screen: screen, data: data);
          });
        },
      ),
    );

    overlay.insert(_currentEntry!);
    _dismissTimer = Timer(const Duration(seconds: 5), () => dismiss());
  }

  static void dismiss({VoidCallback? onComplete}) {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    final state = _bannerKey?.currentState;
    if (state != null && state.mounted) {
      state.animateOut(() {
        dismissImmediate();
        onComplete?.call();
      });
    } else {
      dismissImmediate();
      onComplete?.call();
    }
  }

  static void dismissImmediate() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    try {
      _currentEntry?.remove();
    } catch (_) {}
    _currentEntry = null;
    _bannerKey = null;
  }
}

class _BannerWidget extends StatefulWidget {
  final String title;
  final String message;
  final String screen;
  final Map<String, dynamic>? data;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _BannerWidget({
    super.key,
    required this.title,
    required this.message,
    required this.screen,
    this.data,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  void animateOut(VoidCallback onDone) {
    if (_isDismissing) return;
    _isDismissing = true;
    _controller.reverse().then((_) {
      if (mounted) onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _iconForScreen() {
    final s = widget.screen.toLowerCase();
    if (s.contains('order') || s.contains('compra') || s.contains('pedido')) return Icons.local_mall_outlined;
    if (s.contains('ai') || s.contains('chat') || s.contains('studio')) return Icons.auto_awesome_outlined;
    if (s.contains('report')) return Icons.analytics_outlined;
    if (s.contains('catalog') || s.contains('ropa') || s.contains('prenda')) return Icons.checkroom_outlined;
    return Icons.notifications_active_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              splashColor: AppColors.gold.withAlpha(40),
              highlightColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold.withAlpha(120), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(90),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withAlpha(35),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold.withAlpha(100), width: 1),
                      ),
                      child: Icon(_iconForScreen(), color: AppColors.gold, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white.withAlpha(150), size: 18),
                      onPressed: widget.onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
