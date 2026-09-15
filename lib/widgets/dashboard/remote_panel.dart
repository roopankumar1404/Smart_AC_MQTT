import 'package:flutter/material.dart';
import '../../core/colors.dart';
import 'glass_card.dart';

class RemotePanel extends StatelessWidget {
  const RemotePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: AppColors.primary,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.ac_unit_rounded,
            color: AppColors.primary,
            size: 60,
          ),

          const SizedBox(height: 18),

          Text(
            "Cooling",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 25),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circleButton(Icons.remove),

              const SizedBox(width: 30),

              Text(
                "24°",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(width: 30),

              _circleButton(Icons.add),
            ],
          ),

          const SizedBox(height: 30),

          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.power_settings_new),
            label: const Text("Power"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.isLight ? Colors.white : Colors.black,
              minimumSize: const Size(180, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _circleButton(IconData icon) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Icon(
        icon,
        color: AppColors.textPrimary,
      ),
    );
  }
}