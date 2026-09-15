// lib/screens/dashboard/dashboard_screen.dart
//
// DASHBOARD = MONITORING ONLY (plus Room Name and Filter reminder
// editing, since there's no separate Settings screen in this app).
// All AC controls live on the Remote screen.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import '../../core/colors.dart';
import '../../core/responsive.dart';
import '../../providers/device_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/weather_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/mqtt_service.dart';
import '../../models/device_model.dart';
import '../remote/remote_screen.dart';
import '../energy/energy_screen.dart';
import '../status/status_screen.dart';
import '../../widgets/common/desktop_nav_bar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isTablet = Responsive.isTablet(context);

    context.watch<ThemeProvider>();
    final deviceProvider = context.watch<DeviceProvider>();
    final device = deviceProvider.device;
    final settings = context.watch<SettingsProvider>();
    final weather = context.watch<WeatherProvider>();

    // Periodically verify filter notification state against user setting
    WidgetsBinding.instance.addPostFrameCallback((_) {
      deviceProvider.checkFilterNotifications(settings.filterIntervalDays);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            _buildBackgroundGlow(),
            RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.card,
              onRefresh: () async {
                HapticFeedback.lightImpact();
                final deviceProvider = context.read<DeviceProvider>();
                final weatherProvider = context.read<WeatherProvider>();
                await deviceProvider.refresh();
                await weatherProvider.refresh();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 40 : (isTablet ? 28 : 16),
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 1440 : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(
                          context, settings, deviceProvider, weather),
                      const Gap(16),
                      _buildAlertBanners(context, deviceProvider, settings),
                      const Gap(16),
                      _buildQuickStatus(context, device, deviceProvider),
                      const Gap(20),
                      _buildStatusCardsGrid(context, device, weather),
                      const Gap(16),
                      _buildTodaySummary(context, device),
                      const Gap(16),
                      _buildFilterCard(context, deviceProvider, settings),
                      const Gap(20),
                      _buildFooter(device),
                      const Gap(8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBackgroundGlow() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, _) {
        final t = _glowController.value;
        return IgnorePointer(
          child: Stack(
            children: [
              Positioned(
                top: -120 + (t * 20),
                right: -100,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -140,
                left: -80,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.purple.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // ALERT BANNERS — Safety warnings for filter overdue & 8+ hr continuous run
  // ---------------------------------------------------------------------
  Widget _buildAlertBanners(BuildContext context, DeviceProvider provider,
      SettingsProvider settings) {
    final isFilterOverdue = provider.isFilterOverdue(settings.filterIntervalDays);
    final isLongRun = provider.isLongRunAlert;

    if (!isFilterOverdue && !isLongRun) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (isFilterOverdue) ...[
          _alertBanner(
            icon: Icons.filter_alt_rounded,
            color: Colors.redAccent,
            title: 'Filter Overdue Alert',
            subtitle:
                'AC filter cleaning is due today. Please clean filter and reset timer.',
            actionLabel: 'Reset Filter',
            onAction: () {
              HapticFeedback.mediumImpact();
              _confirmResetFilter(context, provider);
            },
          ),
          const Gap(10),
        ],
        if (isLongRun) ...[
          _alertBanner(
            icon: Icons.timer_rounded,
            color: AppColors.orange,
            title: 'Continuous Run Warning',
            subtitle: 'AC has been running continuously for over 8 hours straight today.',
            actionLabel: 'Turn Off AC',
            onAction: () {
              HapticFeedback.heavyImpact();
              provider.togglePower();
            },
          ),
          const Gap(10),
        ],
      ],
    );
  }

  Widget _alertBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Gap(2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Gap(8),
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                actionLabel,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }

  // ---------------------------------------------------------------------
  // HEADER — room name is editable: tap it to rename.
  // ---------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, SettingsProvider settings,
      DeviceProvider provider, WeatherProvider weather) {
    final dateStr =
        '${_weekday(_now.weekday)}, ${_now.day} ${_month(_now.month)}';
    final timeStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showEditRoomNameDialog(context, settings);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          settings.roomName,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Gap(6),
                        Icon(Icons.edit_rounded,
                            size: 15,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                  const Gap(10),
                  _buildOnlineDot(provider.isEsp32ActuallyOnline),
                ],
              ),
              const Gap(4),
              Text(
                '$dateStr  •  $timeStr',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (Responsive.isDesktop(context) || Responsive.isTablet(context)) ...[
          const DesktopNavPills(currentTab: NavTab.dashboard),
          const Gap(16),
        ],
        _buildWeatherChip(weather),
      ],
    );
  }

  void _showEditRoomNameDialog(
      BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.roomName);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Room Name',
            style: GoogleFonts.spaceGrotesk(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.inter(color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.cardElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.glassBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                settings.setRoomName(newName);
              }
              Navigator.of(dialogContext).pop();
            },
            child: Text('Save',
                style: GoogleFonts.inter(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineDot(bool esp32Online) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final glow = 4 + (_pulseController.value * 6);
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: esp32Online ? AppColors.green : AppColors.orange,
            boxShadow: [
              BoxShadow(
                color: (esp32Online ? AppColors.green : AppColors.orange)
                    .withValues(alpha: 0.7),
                blurRadius: glow,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeatherChip(WeatherProvider weather) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Icon(Icons.wb_cloudy_rounded, color: AppColors.primary, size: 18),
          const Gap(8),
          if (weather.isLoading && weather.temperature == null)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            )
          else
            Text(
              weather.temperature != null
                  ? '${weather.temperature!.toStringAsFixed(0)}°C'
                  : '—',
              style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          const Gap(6),
          Text(
            weather.condition ?? 'Unavailable',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // QUICK STATUS PILLS
  // ---------------------------------------------------------------------
  Widget _buildQuickStatus(
      BuildContext context, DeviceModel device, DeviceProvider provider) {
    final mqtt = context.watch<MqttService>();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _statusPill('Firebase', Icons.local_fire_department_rounded, true),
          _statusPill('MQTT', Icons.hub_rounded, mqtt.isConnected),
          _statusPill('ESP32', Icons.memory_rounded,
              provider.isEsp32ActuallyOnline),
        ],
      ),
    );
  }

  Widget _statusPill(String label, IconData icon, bool online) {
    final color = online ? AppColors.green : Colors.redAccent;
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const Gap(6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
  }

  // ---------------------------------------------------------------------
  // STATUS METRIC CARDS
  // ---------------------------------------------------------------------
  Widget _buildStatusCardsGrid(
      BuildContext context, DeviceModel device, WeatherProvider weather) {
    final isOnline = context.watch<DeviceProvider>().isEsp32ActuallyOnline;
    final crossAxisCount = Responsive.value<int>(
      context: context,
      mobile: 2,
      tablet: 3,
      desktop: 3,
    );

    final outdoorValue = weather.temperature != null
        ? '${weather.temperature!.toStringAsFixed(0)}°C  •  ${weather.condition ?? ''}'
        : '—';

    final items = <Widget>[
      _GlassMetricCard(
        data: _MetricData(
            'Room Temperature',
            isOnline && device.tempSensorOnline && device.temperature > 0
                ? '${device.temperature.toStringAsFixed(1)}°C'
                : '—',
            Icons.thermostat_rounded,
            AppColors.primary),
      ),
      _GlassMetricCard(
        data: _MetricData('Outdoor Temperature', outdoorValue,
            Icons.wb_sunny_rounded, AppColors.orange),
      ),
      _GlassMetricCard(
        data: _MetricData('Set Temperature', '${device.targetTemp}°C',
            Icons.tune_rounded, AppColors.purple),
      ),
      _GlassMetricCard(
        data: _MetricData(
            'Room Humidity',
            isOnline && device.humiditySensorOnline && device.humidity > 0
                ? '${device.humidity.toStringAsFixed(0)}%'
                : '—',
            Icons.water_drop_rounded,
            AppColors.primary),
      ),
      _GlassMetricCard(
        data: _MetricData(
            'Current Power',
            isOnline && device.energyMeterOnline
                ? '${device.powerWatts.toStringAsFixed(0)} W'
                : '0 W',
            Icons.bolt_rounded,
            AppColors.yellow),
      ),
      _AcStatusCard(device: device),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: crossAxisCount == 3 ? 1.15 : 1.4,
      ),
      itemBuilder: (context, i) {
        return items[i]
            .animate()
            .fadeIn(delay: (60 * i).ms, duration: 350.ms)
            .slideY(begin: 0.08, end: 0);
      },
    );
  }

  // ---------------------------------------------------------------------
  // TODAY'S SUMMARY
  // ---------------------------------------------------------------------
  Widget _buildTodaySummary(BuildContext context, DeviceModel device) {
    final hours = (device.todayRunningMinutes / 60).floor();
    final mins = (device.todayRunningMinutes % 60).round();
    final runningLabel = device.todayRunningMinutes <= 0
        ? '0m'
        : (hours > 0 ? '${hours}h ${mins}m' : '${mins}m');

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's Summary",
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Gap(18),
            Row(
              children: [
                Expanded(
                  child: _summaryItem(
                    'Today\'s Energy',
                    '${device.todayEnergyKwh.toStringAsFixed(2)} kWh',
                    Icons.eco_rounded,
                    AppColors.green,
                  ),
                ),
                Expanded(
                  child: _summaryItem(
                    'Running Time',
                    runningLabel,
                    Icons.timer_rounded,
                    AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const Gap(8),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Gap(2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // FILTER CARD — full control lives here: shows status, lets the user
  // edit the reminder interval (in days), and reset after cleaning.
  // ---------------------------------------------------------------------
  Widget _buildFilterCard(BuildContext context, DeviceProvider provider,
      SettingsProvider settings) {
    final intervalDays = settings.filterIntervalDays;
    final remaining = provider.filterDaysRemaining(intervalDays);
    final lastReset = provider.filterLastReset;
    final nextDue = provider.filterNextDueDate(intervalDays);

    final lastResetLabel = lastReset == null
        ? 'Never'
        : '${lastReset.day} ${_month(lastReset.month)} ${lastReset.year}';
    final nextDueLabel = nextDue == null
        ? '—'
        : '${nextDue.day} ${_month(nextDue.month)} ${nextDue.year}';

    final isOverdue = lastReset != null && remaining <= 0;

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isOverdue ? Colors.redAccent : AppColors.yellow)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.filter_alt_rounded,
                    color: isOverdue ? Colors.redAccent : AppColors.yellow,
                    size: 22,
                  ),
                ),
                const Gap(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOverdue
                            ? 'Filter cleaning overdue'
                            : '$remaining days until filter clean',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Gap(4),
                      Text(
                        'Last cleaned: $lastResetLabel  •  Next: $nextDueLabel',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(16),
            _buildFilterProgressBar(intervalDays, remaining),
            const Gap(16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showEditFilterIntervalDialog(context, settings);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.cardElevated,
                        border: Border.all(
                            color: AppColors.glassBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_calendar_rounded,
                              size: 15,
                              color: AppColors.textSecondary),
                          const Gap(6),
                          Text(
                            'Reminder: every $intervalDays days',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Gap(10),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _confirmResetFilter(context, provider);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.primary.withValues(alpha: 0.18),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Text(
                      'Reset',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
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

  Widget _buildFilterProgressBar(int intervalDays, int remainingDays) {
    final daysUsed = (intervalDays - remainingDays).clamp(0, intervalDays);
    final fraction = intervalDays == 0 ? 0.0 : daysUsed / intervalDays;

    Color barColor;
    if (fraction < 0.6) {
      barColor = AppColors.green;
    } else if (fraction < 0.85) {
      barColor = AppColors.yellow;
    } else {
      barColor = Colors.redAccent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                height: 10,
                color: AppColors.cardElevated,
              ),
              FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [barColor.withValues(alpha: 0.6), barColor],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: barColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Gap(6),
        Text(
          '$daysUsed of $intervalDays days used',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showEditFilterIntervalDialog(
      BuildContext context, SettingsProvider settings) {
    final controller =
        TextEditingController(text: settings.filterIntervalDays.toString());
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Filter Reminder',
            style: GoogleFonts.spaceGrotesk(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: GoogleFonts.inter(color: AppColors.textPrimary),
          decoration: InputDecoration(
            suffixText: 'days',
            suffixStyle: GoogleFonts.inter(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.cardElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.glassBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final days = int.tryParse(controller.text.trim());
              if (days != null && days > 0) {
                settings.setFilterIntervalDays(days);
              }
              Navigator.of(dialogContext).pop();
            },
            child: Text('Save',
                style: GoogleFonts.inter(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmResetFilter(
      BuildContext context, DeviceProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Reset filter counter?',
            style: GoogleFonts.spaceGrotesk(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Marks the filter as cleaned today. Only do this after '
          'physically cleaning the filter.',
          style: GoogleFonts.inter(
              color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Reset',
                style: GoogleFonts.inter(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.resetFilter();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Filter counter reset',
              style: TextStyle(color: AppColors.textPrimary)),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildFooter(DeviceModel device) {
    return Center(
      child: Text(
        device.lastUpdatedLabel(),
        style: GoogleFonts.inter(
          fontSize: 11,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // BOTTOM NAV — 4 tabs: Home, Energy, Remote, Status (no Settings)
  // ---------------------------------------------------------------------
  Widget _buildBottomNav(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.dashboard_rounded, 'Home', true),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EnergyScreen()),
              );
            },
            child: _navItem(Icons.bolt_rounded, 'Energy', false),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RemoteScreen()),
              );
            },
            child: _navItem(Icons.settings_remote_rounded, 'Remote', false),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StatusScreen()),
              );
            },
            child: _navItem(Icons.tune_rounded, 'System', false),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active) {
    final color = active ? AppColors.primary : AppColors.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const Gap(4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _weekday(int d) => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ][d - 1];

  String _month(int m) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m - 1];
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricData(this.label, this.value, this.icon, this.color);
}

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

class _GlassMetricCard extends StatelessWidget {
  final _MetricData data;
  const _GlassMetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, color: data.color, size: 18),
            ),
            const Gap(10),
            Text(
              data.value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(2),
            Text(
              data.label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _AcStatusCard extends StatefulWidget {
  final DeviceModel device;
  const _AcStatusCard({required this.device});

  @override
  State<_AcStatusCard> createState() => _AcStatusCardState();
}

class _AcStatusCardState extends State<_AcStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: _getDuration(widget.device.fanSpeed),
    );
    if (widget.device.acOn) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _AcStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.fanSpeed != widget.device.fanSpeed ||
        oldWidget.device.acOn != widget.device.acOn) {
      _glowController.duration = _getDuration(widget.device.fanSpeed);
      if (widget.device.acOn) {
        if (!_glowController.isAnimating) {
          _glowController.repeat(reverse: true);
        }
      } else {
        _glowController.stop();
        _glowController.reset();
      }
    }
  }

  Duration _getDuration(String fanSpeed) {
    switch (fanSpeed) {
      case 'F1':
        return const Duration(milliseconds: 2500);
      case 'F2':
        return const Duration(milliseconds: 2000);
      case 'F3':
        return const Duration(milliseconds: 1500);
      case 'F4':
        return const Duration(milliseconds: 1000);
      case 'F5':
        return const Duration(milliseconds: 600);
      default: // Auto
        return const Duration(milliseconds: 1500);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final acOn = widget.device.acOn;
    final color = acOn ? AppColors.green : AppColors.textDisabled;

    return _GlassCard(
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          final t = acOn ? _glowController.value : 0.0;
          final blurRadius = 6.0 + (t * 12.0);
          final spreadRadius = 1.0 + (t * 2.5);

          return Container(
            decoration: acOn
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.primary
                          .withValues(alpha: 0.2 + (t * 0.4)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary
                            .withValues(alpha: 0.12 + (t * 0.22)),
                        blurRadius: blurRadius,
                        spreadRadius: spreadRadius,
                      ),
                    ],
                  )
                : null,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: acOn
                        ? [
                            BoxShadow(
                              color: AppColors.green
                                  .withValues(alpha: 0.3 + (t * 0.4)),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(Icons.ac_unit_rounded, color: color, size: 18),
                ),
                const Gap(10),
                Text(
                  acOn ? 'ON' : 'OFF',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Gap(2),
                Text(
                  acOn
                      ? '${widget.device.currentMode} (${widget.device.fanSpeed})'
                      : 'AC Status',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}