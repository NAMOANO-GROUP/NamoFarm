import 'package:flutter/material.dart';
import '../../utils/crm_labels.dart';

/// Pastille ronde avec initiales et couleur stable par personne.
class ClientAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const ClientAvatar({super.key, required this.name, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final color = avatarColor(name);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CircleAvatar(
      radius: radius,
      backgroundColor: isDark ? color.shade700 : color.shade100,
      child: Text(
        initials(name),
        style: TextStyle(
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : color.shade800,
        ),
      ),
    );
  }
}

/// Puce colorée à partir d'une [CrmOption] (statut, étape, priorité...).
class CrmPill extends StatelessWidget {
  final CrmOption option;
  final bool dense;
  final bool showIcon;

  const CrmPill(this.option, {super.key, this.dense = false, this.showIcon = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = option.color;
    final fg = isDark ? c.shade100 : c.shade800;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 10, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: isDark ? c.shade900.withValues(alpha: 0.45) : c.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? c.shade400 : c.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(option.icon, size: dense ? 11 : 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: dense ? 11 : 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'indicateur premium (icône, valeur, libellé, tendance optionnelle).
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  final double? trend;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
    this.trend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const Spacer(),
                  if (trend != null) _Trend(trend!),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              if (caption != null)
                Text(caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withValues(alpha: 0.8))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Trend extends StatelessWidget {
  final double value;
  const _Trend(this.value);

  @override
  Widget build(BuildContext context) {
    final up = value >= 0;
    final color = up ? Colors.green : Colors.red;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(up ? Icons.trending_up : Icons.trending_down, size: 16, color: color),
        const SizedBox(width: 2),
        Text('${up ? '+' : ''}${value.toStringAsFixed(0)} %',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

/// Titre de section avec action optionnelle à droite.
class CrmSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const CrmSectionHeader(this.title, {super.key, required this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          ?trailing,
        ],
      ),
    );
  }
}

/// Carte de section arrondie et légère, utilisée dans la fiche client et le tableau de bord.
class CrmCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CrmCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}
