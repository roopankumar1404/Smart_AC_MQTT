// lib/screens/remote/remote_screen.dart
//
// ALL AC controls live here. Dashboard is monitoring-only.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../../core/colors.dart';
import '../../core/constants.dart';
import '../../core/responsive.dart';
import '../../providers/device_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/device_model.dart';
import '../../models/schedule_model.dart';
import '../../widgets/common/desktop_nav_bar.dart';

class RemoteScreen extends StatelessWidget {
  const RemoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final provider = context.watch<DeviceProvider>();
    final device = provider.device;
    final schedule = provider.schedule;
    final esp32Online = provider.isEsp32ActuallyOnline;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const Gap(20),
              if (!esp32Online) ...[
                _buildOfflineBanner(context),
                const Gap(16),
              ],
              _buildPowerCard(context, device, provider),
              const Gap(16),
              Opacity(
                opacity: device.acOn ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !device.acOn,
                  child: Column(
                    children: [
                      _buildTemperatureCard(context, device, provider),
                      const Gap(16),
                      _buildModeCard(context, device, provider),
                      const Gap(16),
                      _buildFanSpeedCard(context, device, provider),
                      const Gap(16),
                      _buildSwingCard(context, device, provider),
                      const Gap(16),
                      _buildQuickControlsCard(context, device, provider),
                      const Gap(16),
                      const SleepCard(),
                    ],
                  ),
                ),
              ),
              const Gap(16),
              _buildSchedulerCard(context, schedule, provider),
              const Gap(16),
              _buildCurrentConfigCard(context, device),
              const Gap(8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 20),
          const Gap(10),
          Expanded(
            child: Text(
              'ESP32 is offline — controls are disabled until it reconnects.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: AppColors.cardShadow,
            ),
            child: Icon(Icons.arrow_back_rounded,
                color: AppColors.primary, size: 20),
          ),
        ),
        const Gap(14),
        Text(
          'Remote Control',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (Responsive.isDesktop(context) || Responsive.isTablet(context))
          const DesktopNavPills(currentTab: NavTab.remote),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // POWER
  // ---------------------------------------------------------------------
  Widget _buildPowerCard(
      BuildContext context, DeviceModel device, DeviceProvider provider) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (device.acOn ? AppColors.green : AppColors.textDisabled)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.power_settings_new_rounded,
                    color: device.acOn ? AppColors.green : AppColors.textDisabled,
                  ),
                ),
                const Gap(14),
                Text(
                  device.acOn ? 'AC is ON' : 'AC is OFF',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            _powerSwitch(device.acOn, () {
              HapticFeedback.mediumImpact();
              provider.togglePower();
            }),
          ],
        ),
      ),
    );
  }

  Widget _powerSwitch(bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 56,
        height: 32,
        padding: const EdgeInsets.all(3),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: on
              ? AppColors.green.withValues(alpha: 0.25)
              : AppColors.cardElevated,
          border: Border.all(color: on ? AppColors.green : AppColors.glassBorder),
        ),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? AppColors.green : AppColors.textDisabled,
            boxShadow: on
                ? [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.6),
                      blurRadius: 8,
                    )
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // TEMPERATURE
  // ---------------------------------------------------------------------
  Widget _buildTemperatureCard(
      BuildContext context, DeviceModel device, DeviceProvider provider) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Temperature',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const Gap(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dialButton(Icons.remove_rounded, () {
                  HapticFeedback.selectionClick();
                  provider.decrementTemp();
                }),
                const Gap(32),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    '${device.targetTemp}°',
                    key: ValueKey(device.targetTemp),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 64,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      shadows: [
                        Shadow(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          blurRadius: 26,
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(32),
                _dialButton(Icons.add_rounded, () {
                  HapticFeedback.selectionClick();
                  provider.incrementTemp();
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.cardElevated,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          boxShadow: AppColors.cardShadow,
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // MODE — Cool / Dry / Fan
  // ---------------------------------------------------------------------
  Widget _buildModeCard(
      BuildContext context, DeviceModel device, DeviceProvider provider) {
    final icons = {
      'Cool': Icons.ac_unit_rounded,
      'Dry': Icons.water_drop_rounded,
      'Fan': Icons.air_rounded,
    };

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mode',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const Gap(14),
            Row(
              children: AppConstants.acModes.map((m) {
                final selected = device.currentMode == m;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      provider.setMode(m);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : AppColors.cardElevated,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.glassBorder,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icons[m],
                            size: 20,
                            color:
                                selected ? AppColors.primary : AppColors.textSecondary,
                          ),
                          const Gap(6),
                          Text(
                            m,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // FAN SPEED — Auto, F1, F2, F3, F4, F5
  // ---------------------------------------------------------------------
  Widget _buildFanSpeedCard(
      BuildContext context, DeviceModel device, DeviceProvider provider) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fan Speed',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Current: ${device.fanSpeed}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const Gap(14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.fanSpeeds.map((s) {
                final selected = device.fanSpeed == s;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    provider.setFanSpeed(s);
                  },
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 32 - 40 - 16) / 3,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : AppColors.cardElevated,
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.glassBorder,
                      ),
                    ),
                    child: Text(
                      s,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // VERTICAL SWING — Off / Auto (continuous) / 6 fixed positions
  // ---------------------------------------------------------------------
  Widget _buildSwingCard(
      BuildContext context, DeviceModel device, DeviceProvider provider) {
    final mode = device.swingMode;
    final position = device.swingPosition;

    String statusLabel;
    if (mode == 'off') {
      statusLabel = 'Off';
    } else if (mode == 'auto') {
      statusLabel = 'Auto Sweep';
    } else {
      statusLabel = AppConstants.swingPositionLabels[position - 1];
    }

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_vert_rounded,
                    color: mode != 'off' ? AppColors.primary : AppColors.textDisabled,
                    size: 18),
                const Gap(8),
                Text(
                  'Vertical Swing',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mode != 'off' ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const Gap(18),
            Center(
              child: _SwingFlapIndicatorVertical(
                mode: mode,
                position: position,
                positionCount: AppConstants.swingPositionCount,
              ),
            ),
            const Gap(20),
            Row(
              children: [
                Expanded(
                  child: _swingModeButton(
                    label: 'Off',
                    icon: Icons.stop_circle_outlined,
                    selected: mode == 'off',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      provider.setSwingOff();
                    },
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: _swingModeButton(
                    label: 'Auto Sweep',
                    icon: Icons.autorenew_rounded,
                    selected: mode == 'auto',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      provider.setSwingAuto();
                    },
                  ),
                ),
              ],
            ),
            const Gap(10),
            Text(
              'Fixed Position',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const Gap(8),
            _swingPositionButtons(mode, position, provider),
          ],
        ),
      ),
    );
  }

  Widget _swingModeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.cardElevated,
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.glassBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const Gap(6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swingPositionButtons(
      String mode, int position, DeviceProvider provider) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(AppConstants.swingPositionCount, (i) {
        final step = i + 1;
        final selected = mode == 'fixed' && position == step;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            provider.setSwingPosition(step);
          },
          child: Container(
            width: 96,
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : AppColors.cardElevated,
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : AppColors.glassBorder,
              ),
            ),
            child: Text(
              AppConstants.swingPositionLabels[i],
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------
  // QUICK ACTIONS (LIGHT, MUTE, HC, DC)
  // ---------------------------------------------------------------------
  Widget _buildQuickControlsCard(
      BuildContext context, DeviceModel device, DeviceProvider provider) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
                const Gap(8),
                Text(
                  'Quick Actions',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Gap(16),
            // Row 1: Light & Mute
            Row(
              children: [
                // Light Off / On Button
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      provider.toggleLight();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: device.lightOn
                            ? AppColors.primary.withValues(alpha: 0.16)
                            : AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: device.lightOn
                              ? AppColors.primary
                              : AppColors.glassBorder,
                          width: device.lightOn ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            device.lightOn
                                ? Icons.lightbulb_rounded
                                : Icons.lightbulb_outline_rounded,
                            size: 18,
                            color: device.lightOn
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          const Gap(8),
                          Text(
                            device.lightOn ? 'Light ON' : 'Light OFF',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: device.lightOn
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Gap(12),
                // Mute Button
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      provider.toggleMute();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: !device.mute
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.16)
                            : AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !device.mute
                              ? const Color(0xFFF59E0B)
                              : AppColors.glassBorder,
                          width: !device.mute ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            !device.mute
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            size: 18,
                            color: !device.mute
                                ? const Color(0xFFF59E0B)
                                : AppColors.textSecondary,
                          ),
                          const Gap(8),
                          Text(
                            !device.mute ? 'Muted' : 'Beep ON',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: !device.mute
                                  ? const Color(0xFFF59E0B)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Gap(12),
            // Row 2: HC Mode (Himalayan Cool / Turbo) & DC Mode (Diet Mode / Energy Saver)
            Row(
              children: [
                // HC Mode Button
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      provider.toggleHcMode();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: device.hcMode
                            ? const Color(0xFF06B6D4).withValues(alpha: 0.18)
                            : AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: device.hcMode
                              ? const Color(0xFF06B6D4)
                              : AppColors.glassBorder,
                          width: device.hcMode ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.ac_unit_rounded,
                            size: 18,
                            color: device.hcMode
                                ? const Color(0xFF06B6D4)
                                : AppColors.textSecondary,
                          ),
                          const Gap(8),
                          Text(
                            'HC Mode',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: device.hcMode
                                  ? const Color(0xFF06B6D4)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Gap(12),
                // DC Mode Button
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      provider.toggleDcMode();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: device.dcMode
                            ? const Color(0xFF10B981).withValues(alpha: 0.18)
                            : AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: device.dcMode
                              ? const Color(0xFF10B981)
                              : AppColors.glassBorder,
                          width: device.dcMode ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.eco_rounded,
                            size: 18,
                            color: device.dcMode
                                ? const Color(0xFF10B981)
                                : AppColors.textSecondary,
                          ),
                          const Gap(8),
                          Text(
                            'DC Mode',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: device.dcMode
                                  ? const Color(0xFF10B981)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // SMART SCHEDULER
  // ---------------------------------------------------------------------
  Widget _buildSchedulerCard(BuildContext context, ScheduleModel schedule,
      DeviceProvider provider) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    color: AppColors.purple, size: 18),
                const Gap(8),
                Text(
                  'Smart Scheduler',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Gap(4),
            Text(
              'Custom feature — not on the original remote',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const Gap(18),
            _scheduleRow(
              context,
              label: 'Turn ON at',
              time: schedule.onTime,
              enabled: schedule.onEnabled,
              onToggle: (v) => provider.setScheduleOnEnabled(v),
              onTimeTap: () async {
                final picked = await _pickTime(context, schedule.onTime);
                if (picked != null) provider.setScheduleOnTime(picked);
              },
            ),
            const Gap(14),
            _scheduleRow(
              context,
              label: 'Turn OFF at',
              time: schedule.offTime,
              enabled: schedule.offEnabled,
              onToggle: (v) => provider.setScheduleOffEnabled(v),
              onTimeTap: () async {
                final picked = await _pickTime(context, schedule.offTime);
                if (picked != null) provider.setScheduleOffTime(picked);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleRow(
    BuildContext context, {
    required String label,
    required String time,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required VoidCallback onTimeTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const Gap(4),
              GestureDetector(
                onTap: onTimeTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cardElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 14, color: AppColors.primary),
                      const Gap(8),
                      Text(
                        time,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: enabled,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            onToggle(v);
          },
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }

  Future<String?> _pickTime(BuildContext context, String currentTime) async {
    final parts = currentTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 6,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  surface: AppColors.card,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return null;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // ---------------------------------------------------------------------
  // CURRENT AC CONFIGURATION
  // ---------------------------------------------------------------------
  Widget _buildCurrentConfigCard(BuildContext context, DeviceModel device) {
    String swingLabel;
    if (device.swingMode == 'off') {
      swingLabel = 'Off';
    } else if (device.swingMode == 'auto') {
      swingLabel = 'Auto Sweep';
    } else {
      swingLabel = AppConstants.swingPositionLabels[device.swingPosition - 1];
    }

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current AC Configuration',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const Gap(14),
            _configRow('Power', device.acOn ? 'ON' : 'OFF'),
            _configRow('Mode', device.currentMode),
            _configRow('Target Temperature', '${device.targetTemp}°C'),
            _configRow('Fan Speed', device.fanSpeed),
            _configRow('Vertical Swing', swingLabel),
            _configRow('Sleep Timer', device.sleepLabel()),
          ],
        ),
      ),
    );
  }

  Widget _configRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// VERTICAL SWING FAN INDICATOR
//
// Shows all positions as a fan of lines from one pivot (like the AC's
// louver bracket), with the CURRENT position highlighted in primary
// color and a dot at its tip. Other positions shown as dim gray guide
// lines. Lowest = steepest line (closest to straight down). Highest =
// shallowest line (closest to horizontal, nearest the body).
//
// Off: all lines dim, nothing highlighted.
// Fixed: the matching line lights up.
// Auto: the highlighted line animates sweeping between all positions.
// ---------------------------------------------------------------------
class _SwingFlapIndicatorVertical extends StatefulWidget {
  final String mode; // 'off' | 'auto' | 'fixed'
  final int position; // 1..positionCount, only used when mode == 'fixed'
  final int positionCount;

  const _SwingFlapIndicatorVertical({
    required this.mode,
    required this.position,
    required this.positionCount,
  });

  @override
  State<_SwingFlapIndicatorVertical> createState() =>
      _SwingFlapIndicatorVerticalState();
}

class _SwingFlapIndicatorVerticalState
    extends State<_SwingFlapIndicatorVertical>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Angle range measured from straight-down (0deg).
  // 0deg = Lowest (steepest, pointing straight down).
  // kMaxAngleDeg = Highest (shallowest, closest to horizontal).
  static const double kMinAngleDeg = 8.0;
  static const double kMaxAngleDeg = 78.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _SwingFlapIndicatorVertical oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.mode == 'auto') {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<double> get _allPositionAngles {
    final n = widget.positionCount;
    return List.generate(n, (i) {
      final t = n == 1 ? 0.0 : i / (n - 1);
      return kMinAngleDeg + t * (kMaxAngleDeg - kMinAngleDeg);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 150,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          double? highlightAngleDeg;
          if (widget.mode == 'fixed') {
            final angles = _allPositionAngles;
            highlightAngleDeg = angles[widget.position - 1];
          } else if (widget.mode == 'auto') {
            final t = _controller.value;
            highlightAngleDeg =
                kMinAngleDeg + t * (kMaxAngleDeg - kMinAngleDeg);
          }
          return CustomPaint(
            painter: _SwingFanPainter(
              allAngles: _allPositionAngles,
              highlightAngleDeg: highlightAngleDeg,
              highlightColor: AppColors.primary,
            ),
          );
        },
      ),
    );
  }
}

class _SwingFanPainter extends CustomPainter {
  final List<double> allAngles; // degrees from straight-down, one per position
  final double? highlightAngleDeg; // null when swing is fully off
  final Color highlightColor;

  _SwingFanPainter({
    required this.allAngles,
    required this.highlightAngleDeg,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Pivot sits at the top-right area, matching a wall-mounted AC
    // unit with the louver bracket visible in that corner.
    final pivot = Offset(size.width - 34, 22);
    const lineLength = 92.0;

    // L-shaped bracket representing the AC unit body, drawn around the
    // pivot corner.
    final bracketPaint = Paint()
      ..color = Colors.white.withValues(alpha:0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final bracketPath = Path()
      ..moveTo(pivot.dx - 40, pivot.dy - 14)
      ..lineTo(pivot.dx + 14, pivot.dy - 14)
      ..lineTo(pivot.dx + 14, pivot.dy + 4)
      ..quadraticBezierTo(
          pivot.dx + 14, pivot.dy + 14, pivot.dx + 4, pivot.dy + 14)
      ..lineTo(pivot.dx - 6, pivot.dy + 14);
    canvas.drawPath(bracketPath, bracketPaint);

    // All available positions, drawn as thin dim guide lines.
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha:0.18)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (final angleDeg in allAngles) {
      final isHighlighted = highlightAngleDeg != null &&
          (angleDeg - highlightAngleDeg!).abs() < 0.01;
      if (isHighlighted) continue; // drawn separately, on top, below
      _drawLineAtAngle(canvas, pivot, angleDeg, lineLength * 0.72, guidePaint);
    }

    // The highlighted (current) position, drawn longer, thicker, in
    // primary color, with a small glowing dot at its tip.
    if (highlightAngleDeg != null) {
      final highlightPaint = Paint()
        ..color = highlightColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      final tip =
          _drawLineAtAngle(canvas, pivot, highlightAngleDeg!, lineLength, highlightPaint);

      final glowPaint = Paint()
        ..color = highlightColor.withValues(alpha:0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(tip, 5, glowPaint);
      canvas.drawCircle(tip, 3.5, Paint()..color = highlightColor);
    }

    // Small dot at the pivot itself.
    canvas.drawCircle(
      pivot,
      3,
      Paint()..color = Colors.white.withValues(alpha:0.35),
    );
  }

  /// Draws a line from [pivot] at [angleDeg] from straight-down,
  /// sweeping toward the lower-left (matching the fan orientation in
  /// the reference design). Returns the endpoint (tip) of the line.
  Offset _drawLineAtAngle(
      Canvas canvas, Offset pivot, double angleDeg, double length, Paint paint) {
    final angleRad = angleDeg * math.pi / 180;
    // 0deg = straight down; increasing angle rotates counter-clockwise
    // (tip moves toward the lower-left, then left, as angle grows).
    final dx = -math.sin(angleRad) * length;
    final dy = math.cos(angleRad) * length;
    final tip = Offset(pivot.dx + dx, pivot.dy + dy);
    canvas.drawLine(pivot, tip, paint);
    return tip;
  }

  @override
  bool shouldRepaint(covariant _SwingFanPainter oldDelegate) {
    return oldDelegate.highlightAngleDeg != highlightAngleDeg ||
        oldDelegate.highlightColor != highlightColor;
  }
}

// ---------------------------------------------------------------------
// SHARED GLASS CARD
// ---------------------------------------------------------------------
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------
// SLEEP TIMER CARD
//
// 4 controls, matching the physical remote:
//  - Sleep: main on/off toggle, highlights when active (live from
//    Firestore, so physical-remote presses reflect here too)
//  - minus/plus: adjust a locally-pending hour count (1-7)
//  - Set: sends the pending hour count and arms sleep
// ---------------------------------------------------------------------
class SleepCard extends StatefulWidget {
  const SleepCard({super.key});

  @override
  State<SleepCard> createState() => _SleepCardState();
}

class _SleepCardState extends State<SleepCard> {
  int _pendingHours = 1;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final device = provider.device;
    final isSleepOn = device.sleepActive;

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bedtime_rounded,
                    color: isSleepOn ? AppColors.primary : Colors.white38,
                    size: 18),
                const Gap(8),
                Text(
                  'Sleep Timer',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  device.sleepLabel(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSleepOn ? AppColors.primary : Colors.white38,
                  ),
                ),
              ],
            ),
            const Gap(18),
            Row(
              children: [
                // 1. Main Sleep toggle - highlights when active
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      if (isSleepOn) {
                        provider.cancelSleep();
                      } else {
                        provider.setSleepHours(_pendingHours);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSleepOn
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: isSleepOn
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        'Sleep',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSleepOn ? AppColors.primary : Colors.white60,
                        ),
                      ),
                    ),
                  ),
                ),
                const Gap(10),

                // 2. Minus button
                _dialButton(Icons.remove_rounded, _pendingHours > 1
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _pendingHours--);
                      }
                    : () {}),

                // Pending hour count
                SizedBox(
                  width: 44,
                  child: Text(
                    '${_pendingHours}h',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),

                // 3. Plus button
                _dialButton(Icons.add_rounded, _pendingHours < 7
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _pendingHours++);
                      }
                    : () {}),

                const Gap(10),

                // 4. Set button
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      provider.setSleepHours(_pendingHours);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.primary.withValues(alpha: 0.18),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Text(
                        'Set',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.card,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: AppColors.primary, size: 16),
      ),
    );
  }
}