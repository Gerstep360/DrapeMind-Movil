import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/ai_models.dart';
import '../../core/models/cart_models.dart';
import '../../core/models/catalog_models.dart';
import '../../core/services/ai_socket_service.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/catalog_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_svg.dart';
import '../ar_fitting/ar_fitting_screen.dart';
import '../catalog/product_detail_screen.dart';


class AiStudioScreen extends StatefulWidget {
  const AiStudioScreen({super.key});

  @override
  State<AiStudioScreen> createState() => _AiStudioScreenState();
}

class _AiStudioScreenState extends State<AiStudioScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Variables para el cuestionario de medidas modal
  String _selectedOccasion = 'cena';
  String _selectedTopType = 'polera';
  String _selectedTopSize = 'M';
  String _selectedBottomType = 'pantalon';
  String _selectedBottomSize = '32';
  String _selectedShoeSize = '42';
  double _budget = 700.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AiSocketService>().connect();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage([String? text]) {
    final query = text ?? _inputController.text;
    if (query.trim().isEmpty) return;

    final ai = context.read<AiSocketService>();
    if (ai.isBusy) return;

    ai.sendMessage(query);
    if (text == null) {
      _inputController.clear();
    }
    _scrollToBottom();
  }

  void _handleAction(AiActionItem item) async {
    final cart = context.read<CartService>();

    if (item.accion == AiActionType.agregar) {
      if (item.varianteId != null) {
        await cart.addItem(item.varianteId!, cantidad: 1);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.forest,
              content: Text('${item.nombre} agregada a tu perchero'),
            ),
          );
        }
      }
    } else if (item.accion == AiActionType.quitar) {
      if (item.itemId != null) {
        await cart.removeItem(item.itemId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.danger,
              content: Text('${item.nombre} quitada de tu perchero'),
            ),
          );
        }
      }
    }
  }

  void _replaceAllWithOutfit(List<AiActionItem> items) async {
    final cart = context.read<CartService>();
    final batch = items
        .where((i) => i.varianteId != null)
        .map((i) => BatchCartItemRequest(varianteId: i.varianteId!, cantidad: 1))
        .toList();

    if (batch.isEmpty) return;

    try {
      await cart.replaceCartWithBatch(batch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.forest,
            content: Text('Perchero actualizado con las ${batch.length} prendas del outfit'),
          ),
        );
      }
    } catch (_) {}
  }

  // --- MODAL DE SESIONES / MULTI-CHAT ---
  void _showSessionsBottomSheet() {
    final ai = context.read<AiSocketService>();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final sessions = ai.sessions;

            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          AppSvg.raw(AppSvg.clock, size: 18, color: AppColors.forest),
                          const SizedBox(width: 8),
                          const Text(
                            'HISTORIAL DE CHATS (24H)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: AppColors.forest,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: AppSvg.raw(AppSvg.close, size: 18, color: AppColors.textMuted),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // BOTÓN NUEVA CONVERSACIÓN
                  InkWell(
                    onTap: () {
                      ai.createNewSession();
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.forest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppSvg.raw(AppSvg.plus, size: 16, color: AppColors.acid),
                          const SizedBox(width: 8),
                          const Text(
                            'Iniciar Nueva Conversación',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // LISTA DE SESIONES ACTIVAS
                  Expanded(
                    child: sessions.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay conversaciones registradas',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: sessions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final session = sessions[idx];
                              final isCurrent = session.id == ai.currentSession.id;

                              final timeAgo = DateTime.now().difference(session.updatedAt);
                              final timeStr = timeAgo.inMinutes < 60
                                  ? 'Hace ${timeAgo.inMinutes} min'
                                  : 'Hace ${timeAgo.inHours} h';

                              return Container(
                                decoration: BoxDecoration(
                                  color: isCurrent ? AppColors.white : AppColors.paperLight,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isCurrent ? AppColors.forest : AppColors.lineStrong,
                                    width: isCurrent ? 1.5 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  title: Text(
                                    session.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                                      color: isCurrent ? AppColors.forest : AppColors.textMain,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${session.messages.length} mensajes · $timeStr',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                  trailing: IconButton(
                                    icon: AppSvg.raw(AppSvg.trash, size: 16, color: AppColors.danger),
                                    onPressed: () {
                                      ai.deleteSession(session.id);
                                      setModalState(() {});
                                      if (sessions.length <= 1) {
                                        Navigator.pop(context);
                                      }
                                    },
                                  ),
                                  onTap: () {
                                    ai.switchSession(session.id);
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- MODAL DE CUESTIONARIO DE MEDIDAS ---
  void _showQuestionnaireModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            AppSvg.raw(AppSvg.sparkle, size: 18, color: AppColors.forest),
                            const SizedBox(width: 8),
                            const Text(
                              'CUESTIONARIO DE MEDIDAS & OUTFIT',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: AppColors.forest,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: AppSvg.raw(AppSvg.close, size: 18, color: AppColors.textMuted),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Configura tus preferencias para que Altair diseñe un look exacto.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),

                    // OCASIÓN
                    const Text('OCASIÓN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: ['cena', 'fiesta', 'casual', 'trabajo', 'boda'].map((occ) {
                        final isSel = _selectedOccasion == occ;
                        return ChoiceChip(
                          label: Text(occ.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSel ? AppColors.white : AppColors.forest)),
                          selected: isSel,
                          selectedColor: AppColors.forest,
                          backgroundColor: AppColors.white,
                          side: const BorderSide(color: AppColors.lineStrong),
                          onSelected: (val) {
                            if (val) setModalState(() => _selectedOccasion = occ);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // PARTE SUPERIOR (TIPO Y TALLA)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PRENDA SUPERIOR', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _selectedTopType,
                                isExpanded: true,
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                items: ['polera', 'camisa', 'blusa', 'polo'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (v) => setModalState(() => _selectedTopType = v!),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TALLA SUPERIOR', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _selectedTopSize,
                                isExpanded: true,
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                items: ['XS', 'S', 'M', 'L', 'XL', 'XXL'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (v) => setModalState(() => _selectedTopSize = v!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // PARTE INFERIOR (TIPO Y TALLA)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PRENDA INFERIOR', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _selectedBottomType,
                                isExpanded: true,
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                items: ['pantalon', 'jean', 'falda'].map((b) => DropdownMenuItem(value: b, child: Text(b.toUpperCase(), style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (v) => setModalState(() => _selectedBottomType = v!),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TALLA INFERIOR', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _selectedBottomSize,
                                isExpanded: true,
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                items: ['28', '30', '32', '34', '36', '38', 'S', 'M', 'L'].map((sz) => DropdownMenuItem(value: sz, child: Text(sz, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (v) => setModalState(() => _selectedBottomSize = v!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // CALZADO
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TALLA CALZADO', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _selectedShoeSize,
                          isExpanded: true,
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                          items: ['38', '39', '40', '41', '42', '43', '44', '45'].map((sz) => DropdownMenuItem(value: sz, child: Text(sz, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (v) => setModalState(() => _selectedShoeSize = v!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // PRESUPUESTO
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('PRESUPUESTO MÁXIMO', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        Text('Bs ${_budget.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.forest)),
                      ],
                    ),
                    Slider(
                      value: _budget,
                      min: 300,
                      max: 2500,
                      divisions: 44,
                      activeColor: AppColors.forest,
                      onChanged: (val) => setModalState(() => _budget = val),
                    ),
                    const SizedBox(height: 16),

                    // BOTÓN GENERAR
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          final prompt = 'Arma un outfit para ocasión $_selectedOccasion, '
                              'busco $_selectedTopType en talla $_selectedTopSize, '
                              '$_selectedBottomType en talla $_selectedBottomSize, '
                              'calzado talla $_selectedShoeSize y presupuesto de Bs ${_budget.toInt()}';
                          _sendMessage(prompt);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppSvg.raw(AppSvg.sparkle, size: 16, color: AppColors.acid),
                            const SizedBox(width: 8),
                            const Text(
                              'DISEÑAR OUTFIT A MEDIDA',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiSocketService>();
    final messages = ai.messages;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        titleSpacing: 10,
        title: InkWell(
          onTap: _showSessionsBottomSheet,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSvg.raw(AppSvg.sparkle, size: 18, color: AppColors.acid),
                const SizedBox(width: 6),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ALTAIR · STYLIST IA',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                      Text(
                        ai.currentSession.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Historial de Chats (24h)
          IconButton(
            icon: AppSvg.raw(AppSvg.clock, size: 18, color: AppColors.white),
            tooltip: 'Historial 24h',
            onPressed: _showSessionsBottomSheet,
          ),
          // Nueva Conversación (+)
          IconButton(
            icon: AppSvg.raw(AppSvg.plus, size: 18, color: AppColors.acid),
            tooltip: 'Nueva Conversación',
            onPressed: () => ai.createNewSession(),
          ),
        ],
      ),
      body: Column(
        children: [
          // FLOATING SLIM TOOLBAR (Cuestionario & Estado)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(bottom: BorderSide(color: AppColors.lineStrong)),
            ),
            child: Row(
              children: [
                // Live Stopwatch / Status indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: ai.isBusy
                            ? AppColors.acid
                            : (ai.status == AiSocketStatus.ready || ai.status == AiSocketStatus.connected
                                ? AppColors.forest
                                : AppColors.danger),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ai.isBusy ? 'Razonando · ${ai.thinkingElapsedFormatted}' : ai.status.displayName,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: ai.isBusy ? AppColors.forest : AppColors.textMutedStrong,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Questionnaire button
                InkWell(
                  onTap: _showQuestionnaireModal,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.forestDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppSvg.raw(AppSvg.sparkle, size: 12, color: AppColors.acid),
                        const SizedBox(width: 5),
                        const Text(
                          'Cuestionario a Medida',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // CHAT MESSAGE STREAM
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return _buildMessageBubble(message, ai);
              },
            ),
          ),

          // DOCKED BOTTOM COMPOSER
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: AppColors.paper,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Consulta a Altair sobre looks o percheros...',
                        hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: AppColors.lineStrong),
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      backgroundColor: AppColors.forest,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: ai.isBusy ? null : () => _sendMessage(),
                    child: ai.isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.acid,
                            ),
                          )
                        : AppSvg.raw(AppSvg.send, size: 18, color: AppColors.acid),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, AiSocketService ai) {
    final isUser = msg.isUser;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // SENDER BADGE
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSvg.raw(
                isUser ? AppSvg.user : AppSvg.sparkle,
                size: 13,
                color: isUser ? AppColors.textMuted : AppColors.forest,
              ),
              const SizedBox(width: 5),
              Text(
                isUser ? 'TÚ' : 'ALTAIR · STYLIST IA',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: isUser ? AppColors.textMuted : AppColors.forest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // LIVE THINKING CARD DURANTE RAZONAMIENTO (SI PENDING)
          if (msg.pending)
            _buildLiveThinkingCard(ai)
          else
            // BUBBLE CONTENT COMPLETED
            Container(
              padding: const EdgeInsets.all(14),
              constraints: const BoxConstraints(maxWidth: 580),
              decoration: BoxDecoration(
                color: isUser ? AppColors.forest : AppColors.white,
                border: Border.all(
                  color: isUser ? AppColors.forest : AppColors.lineStrong,
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TEXT CONTENT
                  if (msg.content.isNotEmpty)
                    Text(
                      msg.content,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: isUser ? AppColors.white : AppColors.textMain,
                      ),
                    ),

                  // NOTICES
                  if (msg.notices.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...msg.notices.map((n) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.paperLight,
                          border: Border.all(color: AppColors.forest.withAlpha(50)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${n.title}: ${n.message}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.forest),
                        ),
                      );
                    }),
                  ],

                  // OUTFIT RECEIPT SUMMARY
                  if (msg.responseMeta != null && msg.responseMeta?.kind == 'outfit') ...[
                    const SizedBox(height: 12),
                    _buildOutfitReceipt(msg),
                  ],

                  // ACTION CARDS (PRODUCTS / ORDERS / RESERVATIONS)
                  if (msg.actionItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      msg.responseTitle ?? 'Prendas Sugeridas del Atelier',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: AppColors.textMutedStrong,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...msg.actionItems.map((item) => _buildActionCard(item)),
                  ],

                  // AUDIT TRACE SUMMARY
                  if (msg.trace.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildAuditTrace(msg.trace, msg.durationMs),
                  ],

                  // DYNAMIC SUGGESTED ACTION CHIPS (GENERADOS POR ALTAIR SIN EMOJIS)
                  if (msg.suggestedActions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: msg.suggestedActions.map((s) {
                        return InkWell(
                          onTap: () => _sendMessage(s.prompt),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.paperLight,
                              border: Border.all(color: AppColors.forest.withAlpha(80)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppSvg.raw(AppSvg.sparkle, size: 12, color: AppColors.forest),
                                const SizedBox(width: 5),
                                Text(
                                  s.label,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.forest,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- LIVE THINKING CARD CON TIMELINE Y CRONÓMETRO ---
  Widget _buildLiveThinkingCard(AiSocketService ai) {
    final steps = ai.liveThoughtSteps;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 580),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.forest.withAlpha(80), width: 1.5),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con Cronómetro en vivo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.forest,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Altair Razonando en Vivo',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.forest,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.forestDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ai.thinkingElapsedFormatted,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.acid,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),

          // Timeline de pasos en tiempo real
          ...steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final stepText = entry.value;
            final isLast = idx == steps.length - 1;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: isLast
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.forest,
                            ),
                          )
                        : AppSvg.raw(AppSvg.check, size: 14, color: AppColors.forest),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stepText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isLast ? FontWeight.w800 : FontWeight.w500,
                        color: isLast ? AppColors.textMain : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOutfitReceipt(ChatMessage msg) {
    final meta = msg.responseMeta;
    final total = meta?.totalBob ?? 0.0;
    final budget = meta?.budgetBob;
    final available = meta?.budgetRemainingBob;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.forestDark,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'SELECCIÓN ${meta?.occasion?.toUpperCase() ?? "ATELIER"}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Bs ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.acid,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${meta?.itemCount ?? 0} piezas con stock y talla verificados',
            style: const TextStyle(color: AppColors.paper, fontSize: 11),
          ),
          if (budget != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Presupuesto: Bs ${budget.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.paper, fontSize: 11)),
                if (available != null)
                  Text('Disponible: Bs ${available.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.acid, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
          if (meta?.canAddAll == true && msg.actionItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.acid,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: () => _replaceAllWithOutfit(msg.actionItems),
                child: const Text(
                  'Usar esta selección en mi perchero',
                  style: TextStyle(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showGarmentDetailModal(AiActionItem item) async {
    final catalogService = CatalogService();
    Product? fullProduct;
    try {
      fullProduct = await catalogService.getProductDetail(item.id);
    } catch (_) {}

    final productToUse = fullProduct ??
        Product(
          id: item.id,
          categoriaId: 1,
          nombre: item.nombre,
          descripcion: item.motivo ?? 'Prenda curada por Altair Stylist IA.',
          precio: item.precio,
          material: 'Tejido Atelier',
          calidadNivel: 5,
          activo: true,
          createdAt: DateTime.now(),
          imagenes: item.imagen != null ? [item.imagen!] : [],
          variantes: [
            ProductVariant(
              id: item.varianteId ?? 1,
              productoId: item.id,
              sku: item.sku ?? 'DRP-${item.id}',
              color: item.color ?? 'Tono Único',
              talla: item.talla ?? 'M',
              stockTotal: 10,
              stockReservado: 0,
              stockDisponible: 10,
              activo: true,
              imagen: item.imagen,
            ),
          ],
        );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final isRemove = item.accion == AiActionType.quitar;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagen de la prenda
                  Container(
                    width: 90,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.lineStrong),
                    ),
                    child: item.imagen != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.fullImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: AppSvg.raw(AppSvg.tshirt, size: 28, color: AppColors.forest),
                              ),
                            ),
                          )
                        : Center(
                            child: AppSvg.raw(AppSvg.tshirt, size: 28, color: AppColors.forest),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.forestDark,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'ATELIER CURATED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: AppColors.acid,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.nombre,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.forestDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bs ${item.precio.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.forest),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (item.talla != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.paperLight,
                                  border: Border.all(color: AppColors.lineStrong),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text('Talla: ${item.talla}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            if (item.color != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.paperLight,
                                  border: Border.all(color: AppColors.lineStrong),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(item.color!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (item.motivo != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.paperLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.forest.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      AppSvg.raw(AppSvg.sparkle, size: 14, color: AppColors.forest),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.motivo!,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.forest),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // BOTONES DE ACCIÓN RICA (AR / PERCHERO / CATÁLOGO)
              Column(
                children: [
                  // Botón Probador AR
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forestDark,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ArFittingScreen(product: productToUse),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppSvg.raw(AppSvg.sparkle, size: 16, color: AppColors.acid),
                          const SizedBox(width: 8),
                          const Text(
                            'PROBAR EN ESPEJO VIRTUAL AR',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: AppColors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Botón Agregar / Quitar Carrito
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isRemove ? AppColors.danger : AppColors.forest,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleAction(item);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppSvg.raw(isRemove ? AppSvg.trash : AppSvg.plus, size: 14, color: AppColors.white),
                              const SizedBox(width: 6),
                              Text(
                                isRemove ? 'Quitar del Perchero' : 'Añadir al Perchero',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botón Ver Ficha Catálogo
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          side: const BorderSide(color: AppColors.lineStrong),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(productId: productToUse.id),
                            ),
                          );
                        },
                        child: AppSvg.raw(AppSvg.store, size: 16, color: AppColors.forest),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionCard(AiActionItem item) {
    final isRemove = item.accion == AiActionType.quitar;

    return InkWell(
      onTap: () => _showGarmentDetailModal(item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isRemove ? AppColors.danger.withAlpha(12) : AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isRemove ? AppColors.danger.withAlpha(60) : AppColors.lineStrong,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // THUMBNAIL
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.paperLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.line),
              ),
              child: item.imagen != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        item.fullImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: AppSvg.raw(AppSvg.tshirt, size: 22, color: AppColors.forest),
                        ),
                      ),
                    )
                  : Center(
                      child: AppSvg.raw(AppSvg.tshirt, size: 22, color: AppColors.forest),
                    ),
            ),
            const SizedBox(width: 10),

            // INFO
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    button: true,
                    label: 'Ver detalles de ${item.nombre}',
                    child: InkWell(
                      onTap: () => _showGarmentDetailModal(item),
                      borderRadius: BorderRadius.circular(3),
                      child: Text(
                        item.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: AppColors.forest,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.acid,
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        'Bs ${item.precio.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.forest),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· ${item.talla ?? "M"} · ${item.color ?? "Tono Único"}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  if (item.motivo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.motivo!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: isRemove ? AppColors.danger : AppColors.textMutedStrong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // BOTÓN RÁPIDO PROBAR EN AR
            IconButton(
              icon: AppSvg.raw(AppSvg.sparkle, size: 16, color: AppColors.acid),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.forestDark,
                padding: const EdgeInsets.all(6),
                minimumSize: const Size(32, 32),
              ),
              tooltip: 'Probar en AR',
              onPressed: () => _showGarmentDetailModal(item),
            ),
            const SizedBox(width: 4),

            // BOTÓN AGREGAR/QUITAR
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                backgroundColor: isRemove ? AppColors.danger : AppColors.forest,
                minimumSize: const Size(40, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () => _handleAction(item),
              child: AppSvg.raw(
                isRemove ? AppSvg.trash : AppSvg.plus,
                size: 13,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditTrace(List<AgentTraceStep> trace, int? durationMs) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 6),
      title: Row(
        children: [
          AppSvg.raw(AppSvg.shield, size: 13, color: AppColors.forest),
          const SizedBox(width: 6),
          Text(
            'Auditoría: ${trace.length} pasos verificados${durationMs != null ? ' (${(durationMs / 1000).toStringAsFixed(1)}s)' : ''}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMutedStrong,
            ),
          ),
        ],
      ),
      children: trace.map((step) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              AppSvg.raw(AppSvg.check, size: 12, color: AppColors.forest),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${step.name}: ${step.summary ?? "Completado"}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMain),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
