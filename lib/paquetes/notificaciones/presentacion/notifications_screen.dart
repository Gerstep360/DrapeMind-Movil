import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:drapemind_mobile/core/models/notification_model.dart';
import 'package:drapemind_mobile/core/services/navigation_service.dart';
import 'package:drapemind_mobile/core/services/push_notification_service.dart';
import 'package:drapemind_mobile/core/theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  final String? filterType;

  const NotificationsScreen({super.key, this.filterType});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = 'TODAS';

  @override
  void initState() {
    super.initState();
    if (widget.filterType != null) {
      _selectedFilter = widget.filterType!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PushNotificationService>().fetchNotifications();
    });
  }

  IconData _iconForType(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'COMPRA':
      case 'PEDIDO_PROCESO':
        return Icons.local_mall_outlined;
      case 'AI_RESPUESTA':
        return Icons.auto_awesome_outlined;
      case 'REPORTE_GENERADO':
        return Icons.analytics_outlined;
      case 'NUEVA_ROPA':
        return Icons.checkroom_outlined;
      case 'PROMOCION':
        return Icons.loyalty_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _accentForType(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'COMPRA':
        return const Color(0xFF2E7D32);
      case 'PEDIDO_PROCESO':
        return const Color(0xFFE65100);
      case 'AI_RESPUESTA':
        return AppColors.gold;
      case 'REPORTE_GENERADO':
        return const Color(0xFF0288D1);
      case 'NUEVA_ROPA':
        return const Color(0xFF8E24AA);
      default:
        return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pushService = context.watch<PushNotificationService>();
    final all = pushService.notifications;

    final filtered = all.where((n) {
      if (_selectedFilter == 'TODAS') return true;
      if (_selectedFilter == 'PEDIDOS') return n.tipo == 'COMPRA' || n.tipo == 'PEDIDO_PROCESO';
      if (_selectedFilter == 'AI') return n.tipo == 'AI_RESPUESTA';
      if (_selectedFilter == 'CATALOGO') return n.tipo == 'NUEVA_ROPA' || n.tipo == 'PROMOCION';
      if (_selectedFilter == 'REPORTES') return n.tipo == 'REPORTE_GENERADO';
      return n.tipo == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Centro de Notificaciones',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          if (pushService.unreadCount > 0)
            TextButton.icon(
              onPressed: () => pushService.markAllAsRead(),
              icon: const Icon(Icons.done_all, color: AppColors.gold, size: 18),
              label: const Text(
                'Leer todo',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(pushService),
          Expanded(
            child: pushService.isLoading && all.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppColors.gold,
                        onRefresh: pushService.fetchNotifications,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final notif = filtered[index];
                            return _buildNotificationCard(context, notif, pushService);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(PushNotificationService service) {
    final filters = [
      {'label': 'Todas', 'key': 'TODAS'},
      {'label': 'Pedidos', 'key': 'PEDIDOS'},
      {'label': 'Altair AI', 'key': 'AI'},
      {'label': 'Catálogo', 'key': 'CATALOGO'},
      {'label': 'Reportes', 'key': 'REPORTES'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                f['label']!,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.ink,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedFilter = f['key']!),
              backgroundColor: Colors.white,
              selectedColor: AppColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.gold : Colors.black.withAlpha(25),
                ),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    AtelierNotification notif,
    PushNotificationService service,
  ) {
    final accent = _accentForType(notif.tipo);
    final icon = _iconForType(notif.tipo);

    return InkWell(
      onTap: () {
        service.markAsRead(notif.id);
        final payload = notif.dataPayload;
        String screen = (payload['screen'] ?? payload['enlace'] ?? payload['url'] ?? '').toString();
        if (screen.isEmpty) {
          final tipo = notif.tipo.toUpperCase();
          if (tipo.contains('PEDIDO') || tipo.contains('ORDER') || tipo.contains('PAGO')) {
            screen = '/orders';
          } else if (tipo.contains('RESERVA')) {
            screen = '/reservations';
          } else if (tipo.contains('AI') || tipo.contains('ALTAIR')) {
            screen = '/chat';
          } else if (tipo.contains('CATALOG') || tipo.contains('PROMO')) {
            screen = '/catalog';
          }
        }
        if (screen.isNotEmpty && screen != '/notifications') {
          Navigator.of(context).pop();
          NavigationService.navigateTo(screen: screen, data: payload);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.leido ? Colors.white : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.leido ? Colors.black.withAlpha(15) : AppColors.gold.withAlpha(150),
            width: notif.leido ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(notif.leido ? 10 : 25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withAlpha(80), width: 1),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.titulo,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: notif.leido ? FontWeight.w600 : FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (!notif.leido)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.mensaje,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.ink.withAlpha(180),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTimestamp(notif.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.ink.withAlpha(120),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'Ver detalle',
                            style: TextStyle(
                              fontSize: 12,
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.arrow_forward_ios, size: 10, color: accent),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} horas';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Widget _buildEmptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.gold.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_none, size: 36, color: AppColors.gold),
              ),
              const SizedBox(height: 18),
              const Text(
                'Sin notificaciones pendientes',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Las alertas sobre tus compras, pedidos, recomendaciones de Altair AI y nuevas colecciones aparecerán aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.ink.withAlpha(150),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
}
