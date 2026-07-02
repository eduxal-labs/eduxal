import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A single stat item displayed within a [QuickStatRow].
class QuickStat {
  const QuickStat({
    required this.label,
    required this.value,
    this.icon,
    this.trend,
    this.onTap,
    this.suffix,
  });

  /// Short label shown below the value (e.g. "Students", "Absent").
  final String label;

  /// The main display value (e.g. "42", "98").
  final String value;

  /// Optional leading icon displayed above the value.
  final IconData? icon;

  /// Trend indicator. `null` = no trend arrow.
  /// Positive = green up arrow, negative = red down arrow.
  final double? trend;

  /// Called when the stat card is tapped.
  final VoidCallback? onTap;

  /// Optional suffix shown after the value (e.g. "%", "KES").
  final String? suffix;
}

/// A compact row of stat mini-cards.
///
/// On desktop (≥ 600 px) the cards wrap. On mobile (< 600 px) they scroll
/// horizontally in a [ListView].
class QuickStatRow extends StatelessWidget {
  const QuickStatRow({super.key, required this.stats});

  final List<QuickStat> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= AppTheme.kMobileBreakpoint;

        if (isDesktop) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final stat in stats) _StatCard(stat: stat)],
          );
        }

        // Mobile: horizontal scrolling list.
        return SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: stats.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) => _StatCard(stat: stats[index]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private stat card
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatefulWidget {
  const _StatCard({required this.stat});

  final QuickStat stat;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.stat.onTap != null) _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.stat.onTap != null) _scaleController.reverse();
  }

  void _handleTapCancel() {
    if (widget.stat.onTap != null) _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stat = widget.stat;
    final hasTap = stat.onTap != null;

    final card = Container(
      constraints: const BoxConstraints(minWidth: 80, maxWidth: 100),
      height: 64,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.kChipRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Value row (value + suffix + trend) ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (stat.icon != null) ...[
                Icon(stat.icon, size: 12, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  stat.suffix != null
                      ? '${stat.value}${stat.suffix}'
                      : stat.value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (stat.trend != null) ...[
                const SizedBox(width: 2),
                _TrendArrow(trend: stat.trend!),
              ],
            ],
          ),
          const SizedBox(height: 2),
          // ── Label ──
          Text(
            stat.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w300,
              color: cs.onSurfaceVariant,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (!hasTap) return card;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: stat.onTap,
      child: ScaleTransition(scale: _scaleAnim, child: card),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trend arrow
// ─────────────────────────────────────────────────────────────────────────────

class _TrendArrow extends StatelessWidget {
  const _TrendArrow({required this.trend});

  final double trend;

  @override
  Widget build(BuildContext context) {
    final isUp = trend > 0;
    final color = isUp ? Colors.green[600]! : Colors.red[600]!;
    final icon = isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return Icon(icon, size: 10, color: color);
  }
}
