import 'package:flutter/material.dart';
import '../../core/colors.dart';

class InfoCard extends StatelessWidget {
  final IconData icon;
  final Color glowColor;
  final String title;
  final String value;
  final String? subtitle;

  const InfoCard({
    super.key,
    required this.icon,
    required this.glowColor,
    required this.title,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: glowColor.withValues(alpha: AppColors.isLight ? 0.35 : 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: AppColors.isLight ? 0.10 : 0.15),
            blurRadius: 25,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: glowColor,
            size: 42,
          ),

          const Spacer(),

          Text(
            title,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(
                color: glowColor,
                fontSize: 15,
              ),
            ),
          ],
        ],
      ),
    );
  }
}