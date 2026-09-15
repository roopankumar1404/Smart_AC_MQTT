// lib/screens/status/status_screen.dart
//
// System Diagnostics & Theme Customization screen.
// Sections: Status (Health, Connectivity, Sensors) & System (Theme Switcher).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../../core/colors.dart';
import '../../core/responsive.dart';
import '../../providers/device_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/mqtt_service.dart';
import '../../models/device_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/desktop_nav_bar.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final device = provider.device;
    final connectivity = context.watch<ConnectivityProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: themeProvider.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, themeProvider),
              const Gap(20),

              // -------------------------------------------------------------------
              // SUB-HEADING 1: STATUS
              // -------------------------------------------------------------------
              _buildSectionTitle('STATUS', Icons.analytics_rounded, themeProvider),
              const Gap(12),
              _buildOverallHealthCard(context, provider, connectivity, themeProvider),
              const Gap(14),
              _buildConnectivityCard(context, device, provider, connectivity, themeProvider),
              const Gap(14),
              _buildSensorsCard(context, device, provider, themeProvider),
              const Gap(24),

              // -------------------------------------------------------------------
              // SUB-HEADING 2: SYSTEM
              // -------------------------------------------------------------------
              _buildSectionTitle('SYSTEM', Icons.tune_rounded, themeProvider),
              const Gap(12),
              _buildThemeCard(context, themeProvider),
              const Gap(14),
              _buildAccountCard(context, themeProvider),
              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, ThemeProvider theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: theme.primary),
        ),
        const Gap(10),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: theme.primary.withValues(alpha: 0.9),
            letterSpacing: 2.0,
          ),
        ),
        const Gap(12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primary.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, ThemeProvider theme) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
              boxShadow: theme.cardShadow,
            ),
            child: Icon(Icons.arrow_back_rounded,
                color: theme.primary, size: 20),
          ),
        ),
        const Gap(14),
        Text(
          'System Status',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        if (Responsive.isDesktop(context) || Responsive.isTablet(context))
          const DesktopNavPills(currentTab: NavTab.system),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // OVERALL HEALTH
  // ---------------------------------------------------------------------
  Widget _buildOverallHealthCard(
      BuildContext context,
      DeviceProvider provider,
      ConnectivityProvider connectivity,
      ThemeProvider theme) {
    final mqtt = context.watch<MqttService>();
    final hasFirebase = true;
    final hasMqtt = mqtt.isConnected;
    final hasEsp32 = provider.isEsp32ActuallyOnline;
    final hasInternet = connectivity.hasInternet;

    int activeCount = 0;
    if (hasFirebase) activeCount++;
    if (hasMqtt) activeCount++;
    if (hasEsp32) activeCount++;
    if (hasInternet) activeCount++;

    const totalCount = 4;
    final progress = activeCount / totalCount;

    final color = activeCount == 4
        ? theme.green
        : activeCount >= 2
            ? theme.yellow
            : AppColors.red;

    final statusSubtitle = activeCount == totalCount
        ? 'All systems nominal'
        : '$activeCount of $totalCount components active';

    return _GlassCard(
      theme: theme,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.isLight
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFF131722),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 4.5,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(
                      theme.isLight
                          ? const Color(0xFFCBD5E1)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return CircularProgressIndicator(
                        value: value,
                        strokeWidth: 4.5,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation(color),
                        strokeCap: StrokeCap.round,
                      );
                    },
                  ),
                  Text(
                    '$activeCount/$totalCount',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall System Health',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    statusSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // CONNECTIVITY
  // ---------------------------------------------------------------------
  Widget _buildConnectivityCard(
      BuildContext context,
      DeviceModel device,
      DeviceProvider provider,
      ConnectivityProvider connectivity,
      ThemeProvider theme) {
    final mqtt = context.watch<MqttService>();
    final isOnline = provider.isEsp32ActuallyOnline;

    return _GlassCard(
      theme: theme,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Connectivity', Icons.wifi_rounded, theme),
            const Gap(16),
            _statusRow('Firebase', true, theme),
            _statusRow('MQTT Server', mqtt.isConnected, theme),
            _statusRow('ESP32', isOnline, theme),
            _statusRow('Internet', connectivity.hasInternet, theme),
            const Gap(14),
            Divider(
              color: theme.isLight
                  ? Colors.black.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.06),
              height: 1,
            ),
            const Gap(14),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: theme.textSecondary.withValues(alpha: 0.8),
                          ),
                          const Gap(8),
                          Text(
                            'System Uptime',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: theme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (device.bootReason.isNotEmpty) ...[
                        const Gap(2),
                        Padding(
                          padding: const EdgeInsets.only(left: 24),
                          child: Text(
                            'Boot: ${device.bootReason}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: theme.textSecondary.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? theme.primary.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOnline
                            ? theme.primary.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      isOnline ? device.uptimeLabel() : 'Offline' ,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isOnline ? theme.primary : theme.textSecondary,
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
  // SENSORS
  // ---------------------------------------------------------------------
  Widget _buildSensorsCard(BuildContext context, DeviceModel device,
      DeviceProvider provider, ThemeProvider theme) {
    final isOnline = provider.isEsp32ActuallyOnline;

    return _GlassCard(
      theme: theme,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle('Sensors', Icons.sensors_rounded, theme),
            const Gap(16),
            _statusRow('Temperature Sensor', isOnline && device.tempSensorOnline, theme),
            _statusRow('Humidity Sensor', isOnline && device.humiditySensorOnline, theme),
            _statusRow('Energy Meter', isOnline && device.energyMeterOnline, theme),
          ],
        ),
      ),
    );
  }

  Widget _cardTitle(String label, IconData icon, ThemeProvider theme) {
    return Row(
      children: [
        Icon(icon, size: 15, color: theme.primary.withValues(alpha: 0.9)),
        const Gap(8),
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _statusRow(String label, bool ok, ThemeProvider theme) {
    final color = ok ? theme.green : AppColors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 20,
            color: color,
          ),
          const Gap(12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            ok ? 'Online' : 'Offline',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // SYSTEM OPTIONS â€” THEME SWITCHER
  // ---------------------------------------------------------------------
  Widget _buildThemeCard(BuildContext context, ThemeProvider theme) {
    String themeLabel = theme.isCyberLight ? 'Cyber Light' : 'Cyber Dark';

    return _GlassCard(
      theme: theme,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _cardTitle('Appearance', Icons.palette_rounded, theme),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: theme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    themeLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(18),
            Row(
              children: [
                Expanded(
                  child: _themeOptionChip(
                    context: context,
                    theme: theme,
                    mode: AppThemeMode.cyberDark,
                    title: 'Cyber Dark',
                    subtitle: 'Cyber Midnight',
                    primaryColor: const Color(0xFF00E5FF),
                    bgColor: const Color(0xFF0A0E17),
                    accentColor: const Color(0xFF8B5CF6),
                    isSelected: theme.isCyberDark,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: _themeOptionChip(
                    context: context,
                    theme: theme,
                    mode: AppThemeMode.cyberLight,
                    title: 'Cyber Light',
                    subtitle: 'Tech Titanium',
                    primaryColor: const Color(0xFF0066FF),
                    bgColor: const Color(0xFFF0F4F8),
                    accentColor: const Color(0xFF00C8FF),
                    isSelected: theme.isCyberLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeOptionChip({
    required BuildContext context,
    required ThemeProvider theme,
    required AppThemeMode mode,
    required String title,
    required String subtitle,
    required Color primaryColor,
    required Color bgColor,
    required Color accentColor,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        theme.setThemeMode(mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.12)
              : theme.cardElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.7)
                : theme.glassBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // Mini palette preview
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _paletteCircle(bgColor, size: 24, border: primaryColor),
                const Gap(4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _paletteChip(primaryColor),
                    const Gap(3),
                    _paletteChip(accentColor),
                  ],
                ),
              ],
            ),
            const Gap(10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? primaryColor : theme.textPrimary,
              ),
            ),
            const Gap(2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.8)
                    : theme.textSecondary,
              ),
            ),
            if (isSelected) ...[
              const Gap(8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 9, color: primaryColor),
                    const Gap(3),
                    Text(
                      'Active',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, ThemeProvider theme) {
    final authService = AuthService();
    final user = authService.currentUser;
    final email = user?.email ?? 'Anonymous Session';

    return _GlassCard(
      theme: theme,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_circle_rounded,
                    color: theme.primary,
                    size: 24,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account & Security',
                        style: GoogleFonts.outfit(
                          color: theme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        email,
                        style: GoogleFonts.outfit(
                          color: theme.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Active',
                    style: GoogleFonts.outfit(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(16),
            Divider(
              color: theme.isLight
                  ? Colors.black.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.06),
              height: 1,
            ),
            const Gap(14),
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: theme.textSecondary.withValues(alpha: 0.7),
                ),
                const Gap(6),
                Expanded(
                  child: Text(
                    'Synced with Google Cloud Firestore',
                    style: GoogleFonts.outfit(
                      color: theme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _confirmSignOut(context, theme, authService),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: AppColors.error.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: Text(
                    'Log Out',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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

  void _confirmSignOut(BuildContext context, ThemeProvider theme, AuthService authService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: theme.isLight
                ? theme.primary.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.error, size: 24),
            const Gap(10),
            Text(
              'Sign Out',
              style: GoogleFonts.outfit(
                color: theme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out from this device?',
          style: GoogleFonts.outfit(
            color: theme.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: theme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await authService.signOut();
            },
            child: Text(
              'Log Out',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paletteCircle(Color color, {double size = 24, Color? border}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: border != null
            ? Border.all(color: border, width: 1.5)
            : null,
      ),
    );
  }

  Widget _paletteChip(Color color) {
    return Container(
      width: 22,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// SHARED GLASS CARD
// ---------------------------------------------------------------------
class _GlassCard extends StatelessWidget {
  final Widget child;
  final ThemeProvider? theme;
  const _GlassCard({required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final cardColor = theme?.card ?? AppColors.card;
    final accentColor = theme?.primary ?? AppColors.primary;
    final isLight = theme?.isLight ?? AppColors.isLight;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLight
              ? accentColor.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: theme?.cardShadow ?? AppColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}
