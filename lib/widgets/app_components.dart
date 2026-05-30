import 'package:flutter/material.dart';
import '../app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ExpandableCard
// Base para RecipeCard y WorkoutCard. Maneja expand/collapse, animación y
// scroll automático al contenido cuando se abre.
//
// Uso:
//   ExpandableCard(accent: Colors.orange, headerIcon: Icons.restaurant_menu, ...)
//   ExpandableCard(accent: Colors.blue,   headerIcon: Icons.fitness_center,  ...)
// ─────────────────────────────────────────────────────────────────────────────
class ExpandableCard extends StatefulWidget {
  final MaterialColor accent;
  final IconData headerIcon;
  final String title;

  /// Subtítulo bajo el título (ej. MacroChipsRow o texto de calorías quemadas).
  final Widget? subtitle;

  /// Acción alineada a la derecha del subtítulo (ej. CardSaveButton).
  final Widget? action;

  /// Motivo de recomendación (1 frase). Se muestra debajo del subtítulo en cursiva.
  final String? justificacion;

  /// Contenido visible al expandir. Se renderiza después del Divider interno.
  final List<Widget> expandedContent;

  const ExpandableCard({
    Key? key,
    required this.accent,
    required this.headerIcon,
    required this.title,
    required this.expandedContent,
    this.subtitle,
    this.action,
    this.justificacion,
  }) : super(key: key);

  @override
  State<ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<ExpandableCard> {
  bool _expanded = false;
  final GlobalKey _dividerKey = GlobalKey();

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (!_expanded) return;
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      final ctx = _dividerKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx, // ignore: use_build_context_synchronously
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.shade100),
        boxShadow: [
          BoxShadow(
            color: accent.shade900.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleIconBadge(icon: widget.headerIcon, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 6),
                          widget.subtitle!,
                        ],
                        if (widget.justificacion != null && widget.justificacion!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.justificacion!,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey.shade600,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (widget.action != null) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: widget.action!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: accent.shade400,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(key: _dividerKey, height: 1),
                        const SizedBox(height: 12),
                        ...widget.expandedContent,
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CircleIconBadge — ícono dentro de un círculo de color suave
// ─────────────────────────────────────────────────────────────────────────────
class CircleIconBadge extends StatelessWidget {
  final IconData icon;
  final MaterialColor color;
  final double iconSize;

  const CircleIconBadge({
    Key? key,
    required this.icon,
    required this.color,
    this.iconSize = 20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.shade50, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CardSectionHeader — título de sección dentro de una card expandida
// Ej: "INGREDIENTES", "TÉCNICA Y PASOS", "MÚSCULO, EQUIPO Y VOLUMEN"
// ─────────────────────────────────────────────────────────────────────────────
class CardSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const CardSectionHeader({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade800,
          letterSpacing: 0.6,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CardStepRow — fila numerada para pasos de preparación o instrucciones
// ─────────────────────────────────────────────────────────────────────────────
class CardStepRow extends StatelessWidget {
  final int index;
  final String text;
  final Color color;

  const CardStepRow(this.index, this.text, this.color, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$index',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 11),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Text(text, style: const TextStyle(fontSize: 13.5, height: 1.45)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CardNoteBox — caja con bombilla al pie de una card expandida
// ─────────────────────────────────────────────────────────────────────────────
class CardNoteBox extends StatelessWidget {
  final String nota;
  final MaterialColor accent;

  const CardNoteBox({Key? key, required this.nota, required this.accent})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.shade50.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: accent.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nota,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: accent.shade900,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CardSaveButton — botón "Guardar" estándar para cards del asistente
// ─────────────────────────────────────────────────────────────────────────────
class CardSaveButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CardSaveButton({Key? key, required this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(Icons.bookmark_add, size: 18, color: Colors.blue),
      label: const Text(
        'Guardar',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      onPressed: onPressed,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MiniChip — etiqueta pequeña de color con ícono opcional
// Usada en listas de alimentos, ejercicios y favoritos (macros, kcal, intensidad)
// ─────────────────────────────────────────────────────────────────────────────
class MiniChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;

  const MiniChip({
    Key? key,
    this.icon,
    required this.label,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.1), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EmptyStateView — estado vacío centrado con ícono, mensaje y acción opcional
// Usada en tabs sin datos dentro de MiBalanceScreen
// ─────────────────────────────────────────────────────────────────────────────
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyStateView({
    Key? key,
    required this.icon,
    required this.message,
    this.onAction,
    this.actionLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(icon, size: 64, color: Colors.blue.withOpacity(0.3)),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, color: Colors.grey, height: 1.5),
              ),
              if (onAction != null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(actionLabel ?? 'Recargar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AnimatedListEntry — wrapper de slide+fade escalonado para items de lista
// Pasar el AnimationController de la pantalla padre e index del item.
// Delay máximo: 0.5s (a partir del item 5 todos entran al mismo tiempo)
// ─────────────────────────────────────────────────────────────────────────────
class AnimatedListEntry extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final Widget child;

  const AnimatedListEntry({
    Key? key,
    required this.controller,
    required this.index,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, ch) {
        final delay = (index * 0.1).clamp(0.0, 0.5);
        final anim = CurvedAnimation(
          parent: controller,
          curve: Interval(
            delay,
            (delay + 0.4).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        );
        return Transform.translate(
          offset: Offset(0, 20 * (1 - anim.value)),
          child: Opacity(opacity: anim.value, child: ch),
        );
      },
      child: child,
    );
  }
}
