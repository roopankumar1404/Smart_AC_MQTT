// lib/widgets/common/desktop_nav_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

import '../../core/colors.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/energy/energy_screen.dart';
import '../../screens/remote/remote_screen.dart';
import '../../screens/status/status_screen.dart';

enum NavTab { dashboard, energy, remote, system }

class DesktopNavPills extends StatelessWidget {
  final NavTab currentTab;

  const DesktopNavPills({super.key, required this.currentTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _navItem(
            context: context,
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            active: currentTab == NavTab.dashboard,
            target: NavTab.dashboard,
          ),
          _navItem(
            context: context,
            icon: Icons.bolt_rounded,
            label: 'Energy',
            active: currentTab == NavTab.energy,
            target: NavTab.energy,
          ),
          _navItem(
            context: context,
            icon: Icons.settings_remote_rounded,
            label: 'Remote',
            active: currentTab == NavTab.remote,
            target: NavTab.remote,
          ),
          _navItem(
            context: context,
            icon: Icons.tune_rounded,
            label: 'System',
            active: currentTab == NavTab.system,
            target: NavTab.system,
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool active,
    required NavTab target,
  }) {
    return GestureDetector(
      onTap: () {
        if (active) return;
        HapticFeedback.selectionClick();
        if (target == NavTab.dashboard) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          Widget nextScreen;
          switch (target) {
            case NavTab.energy:
              nextScreen = const EnergyScreen();
              break;
            case NavTab.remote:
              nextScreen = const RemoteScreen();
              break;
            case NavTab.system:
              nextScreen = const StatusScreen();
              break;
            case NavTab.dashboard:
              nextScreen = const DashboardScreen();
              break;
          }
          if (currentTab == NavTab.dashboard) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => nextScreen),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => nextScreen),
            );
          }
        }
      },
      child: MouseRegion(
        cursor: active ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: active
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
              const Gap(6),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
