import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drapemind_mobile/core/services/push_notification_service.dart';
import 'package:drapemind_mobile/paquetes/notificaciones/presentacion/notifications_screen.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});
  @override
  Widget build(BuildContext context) {
    final count = context.watch<PushNotificationService?>()?.unreadCount ?? 0;
    return IconButton(
      tooltip: 'Notificaciones',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
      ),
    );
  }
}
