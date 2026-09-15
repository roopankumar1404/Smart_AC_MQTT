// lib/screens/energy/energy_screen.dart
//
// SmartThings-style monitoring layout: Day/Week/Month/Year tabs,
// prev/next date navigation, cumulative usage + operation time, bar
// chart, tappable detail card.
//
// All chart data and summaries are 100% REAL from Firestore energy_logs
// and live PZEM-004T readings from DeviceModel. Zero dummy/random data.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../core/colors.dart';
import '../../core/responsive.dart';
import '../../providers/device_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/device_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/desktop_nav_bar.dart';

enum EnergyPeriod { day, week, month, year }

class EnergyScreen extends StatefulWidget {
  const EnergyScreen({super.key});

  @override
  State<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends State<EnergyScreen> {
  EnergyPeriod _selectedPeriod = EnergyPeriod.day;

  DateTime _selectedDate = DateTime.now();
  int _selectedYear = DateTime.now().year;
  DateTime get _weekStart =>
      _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
  DateTime get _monthStart =>
      DateTime(_selectedDate.year, _selectedDate.month, 1);

  int? _selectedBarIndex;

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final device = context.watch<DeviceProvider>().device;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirestoreService().dailyLogsStream(),
          builder: (context, snapshot) {
            final logs = snapshot.data ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const Gap(20),
                  _buildLiveMeterGrid(context, device),
                  const Gap(20),
                  _buildPeriodTabs(context),
                  const Gap(16),
                  _buildDateNavigator(context),
                  const Gap(16),
                  _buildMonitoringCard(context, device, logs),
                  const Gap(8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

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
          'Energy Monitoring',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (Responsive.isDesktop(context) || Responsive.isTablet(context))
          const DesktopNavPills(currentTab: NavTab.energy),
      ],
    );
  }

  Widget _buildLiveMeterGrid(BuildContext context, DeviceModel device) {
    final isOnline = context.watch<DeviceProvider>().isEsp32ActuallyOnline;

    final items = [
      _MetricData('Current Power', isOnline ? '${device.powerWatts.toStringAsFixed(0)} W' : '0 W',
          Icons.bolt_rounded, AppColors.yellow),
      _MetricData('Voltage', isOnline ? '${device.voltage.toStringAsFixed(0)} V' : '0 V',
          Icons.flash_on_rounded, AppColors.primary),
      _MetricData('Current', isOnline ? '${device.current.toStringAsFixed(2)} A' : '0.00 A',
          Icons.electrical_services_rounded, AppColors.purple),
      _MetricData('Power Factor', isOnline ? device.powerFactor.toStringAsFixed(2) : '0.00',
          Icons.speed_rounded, AppColors.orange),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemBuilder: (context, i) => _GlassMetricCard(data: items[i]),
    );
  }

  Widget _buildPeriodTabs(BuildContext context) {
    final labels = {
      EnergyPeriod.day: 'Day',
      EnergyPeriod.week: 'Week',
      EnergyPeriod.month: 'Month',
      EnergyPeriod.year: 'Year',
    };

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: EnergyPeriod.values.map((p) {
          final selected = _selectedPeriod == p;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedPeriod = p;
                _selectedBarIndex = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: selected
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.5))
                      : null,
                ),
                child: Text(
                  labels[p]!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateNavigator(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _navArrow(Icons.chevron_left_rounded, () => setState(() {
              _shiftPeriod(-1);
              _selectedBarIndex = null;
            })),
        GestureDetector(
          onTap: () => _openPicker(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _navigatorLabel(),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Gap(4),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary, size: 18),
            ],
          ),
        ),
        _navArrow(Icons.chevron_right_rounded, () => setState(() {
              _shiftPeriod(1);
              _selectedBarIndex = null;
            })),
      ],
    );
  }

  Widget _navArrow(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder),
          boxShadow: AppColors.cardShadow,
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }

  void _shiftPeriod(int direction) {
    switch (_selectedPeriod) {
      case EnergyPeriod.day:
        _selectedDate = _selectedDate.add(Duration(days: direction));
        break;
      case EnergyPeriod.week:
        _selectedDate = _selectedDate.add(Duration(days: 7 * direction));
        break;
      case EnergyPeriod.month:
        _selectedDate = DateTime(
            _selectedDate.year, _selectedDate.month + direction, 1);
        break;
      case EnergyPeriod.year:
        _selectedYear += direction;
        break;
    }
  }

  String _navigatorLabel() {
    switch (_selectedPeriod) {
      case EnergyPeriod.day:
        return '${_weekday(_selectedDate.weekday)}, ${_month(_selectedDate.month)} ${_selectedDate.day}, ${_selectedDate.year}';
      case EnergyPeriod.week:
        final end = _weekStart.add(const Duration(days: 6));
        return '${_month(_weekStart.month)} ${_weekStart.day}, ${_weekStart.year}-${_month(end.month)} ${end.day}, ${end.year}';
      case EnergyPeriod.month:
        return '${_month(_monthStart.month)} ${_monthStart.year}';
      case EnergyPeriod.year:
        return '$_selectedYear';
    }
  }

  Future<void> _openPicker(BuildContext context) async {
    if (_selectedPeriod == EnergyPeriod.day ||
        _selectedPeriod == EnergyPeriod.week) {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2024),
        lastDate: DateTime(2030),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  surface: AppColors.card,
                ),
          ),
          child: child!,
        ),
      );
      if (picked != null) {
        setState(() {
          _selectedDate = picked;
          _selectedBarIndex = null;
        });
      }
    } else if (_selectedPeriod == EnergyPeriod.month) {
      final picked = await showDatePicker(
        context: context,
        initialDate: _monthStart,
        firstDate: DateTime(2024),
        lastDate: DateTime(2030),
        initialDatePickerMode: DatePickerMode.year,
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  surface: AppColors.card,
                ),
          ),
          child: child!,
        ),
      );
      if (picked != null) {
        setState(() {
          _selectedDate = DateTime(picked.year, picked.month, 1);
          _selectedBarIndex = null;
        });
      }
    } else {
      final picked = await showDialog<int>(
        context: context,
        builder: (context) => _YearPickerDialog(initialYear: _selectedYear),
      );
      if (picked != null) {
        setState(() {
          _selectedYear = picked;
          _selectedBarIndex = null;
        });
      }
    }
  }

  Widget _buildMonitoringCard(
      BuildContext context, DeviceModel device, List<Map<String, dynamic>> logs) {
    final periodData = _extractRealData(logs, device);
    final barData = periodData.bars;
    final total = periodData.totalKwh;
    final opMinutes = periodData.operationMinutes;

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedPeriod == EnergyPeriod.day) ...[
              Text(
                'Current Power Consumption (${_isSameDay(_selectedDate, DateTime.now()) ? "Live" : "Historic"})',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                _isSameDay(_selectedDate, DateTime.now())
                    ? '${(device.powerWatts / 1000).toStringAsFixed(3)} kW'
                    : '${total.toStringAsFixed(2)} kWh Total',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Gap(14),
            ],
            _summaryRow(
                '${_periodLabel()} Cumulative Usage',
                '${total.toStringAsFixed(2)} kWh'),
            const Gap(6),
            _summaryRow('Operation Time', _formatOperationTime(opMinutes)),
            const Gap(20),
            SizedBox(
              height: 200,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildBarChart(barData),
              ),
            ),
            const Gap(16),
            _buildDetailCard(barData),
            const Gap(10),
            Text(
              'Real energy readings recorded via PZEM-004T power sensor.',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _periodLabel() {
    switch (_selectedPeriod) {
      case EnergyPeriod.day:
        return 'Daily';
      case EnergyPeriod.week:
        return 'Weekly';
      case EnergyPeriod.month:
        return 'Monthly';
      case EnergyPeriod.year:
        return 'Yearly';
    }
  }

  String _formatOperationTime(double minutes) {
    final totalMin = minutes.round();
    final days = totalMin ~/ 1440;
    final hours = (totalMin % 1440) ~/ 60;
    final mins = totalMin % 60;
    if (days > 0) return '${days}d ${hours}h ${mins}m';
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  Widget _buildBarChart(Map<String, double> barData) {
    final entries = barData.entries.toList();
    final maxY = (entries.map((e) => e.value).fold<double>(0, max)) * 1.3;

    return BarChart(
      key: ValueKey('$_selectedPeriod-${_navigatorLabel()}'),
      BarChartData(
        maxY: maxY <= 0 ? 1.0 : maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.glassBorder,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= entries.length) {
                  return const SizedBox.shrink();
                }
                final shouldShow = _shouldShowLabel(idx, entries.length);
                if (!shouldShow) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    entries[idx].key,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.card,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(2)} kWh',
                GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              );
            },
          ),
          touchCallback: (event, response) {
            if (event.isInterestedForInteractions &&
                response?.spot != null) {
              setState(() {
                _selectedBarIndex = response!.spot!.touchedBarGroupIndex;
              });
            }
          },
        ),
        barGroups: List.generate(entries.length, (i) {
          final selected = _selectedBarIndex == i ||
              (_selectedBarIndex == null && i == entries.length - 1);
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value,
                width: entries.length > 15 ? 5 : 14,
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: selected
                      ? [AppColors.primary, AppColors.purple]
                      : [
                          AppColors.primary.withValues(alpha: 0.35),
                          AppColors.purple.withValues(alpha: 0.35),
                        ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  bool _shouldShowLabel(int idx, int total) {
    if (total <= 8) return true;
    final step = (total / 6).ceil();
    return idx % step == 0;
  }

  Widget _buildDetailCard(Map<String, double> barData) {
    final entries = barData.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    final idx = _selectedBarIndex ?? (entries.length - 1);
    final safeIdx = idx.clamp(0, entries.length - 1);
    final entry = entries[safeIdx];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _detailLabel(entry.key, safeIdx),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '${entry.value.toStringAsFixed(2)} kWh',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _detailLabel(String key, int idx) {
    switch (_selectedPeriod) {
      case EnergyPeriod.day:
        final hour = idx;
        String fmt(int h) {
          final period = h >= 12 ? 'PM' : 'AM';
          final h12 = h % 12 == 0 ? 12 : h % 12;
          return '$h12:00 $period';
        }
        final nextHour = (hour + 1) % 24;
        return '${fmt(hour)}-${fmt(nextHour)}';
      case EnergyPeriod.week:
        final date = _weekStart.add(Duration(days: idx));
        return '${_weekday(date.weekday)}, ${_month(date.month)} ${date.day}, ${date.year}';
      case EnergyPeriod.month:
        final date = DateTime(_monthStart.year, _monthStart.month, idx + 1);
        return '${_weekday(date.weekday)}, ${_month(date.month)} ${date.day}';
      case EnergyPeriod.year:
        return key;
    }
  }

  // =========================================================================
  // REAL DATA EXTRACTION (NO DUMMY / RANDOM NUMBERS)
  // =========================================================================

  _PeriodData _extractRealData(
      List<Map<String, dynamic>> logs, DeviceModel device) {
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case EnergyPeriod.day: {
        final isToday = _isSameDay(_selectedDate, now);
        final log = _findLog(logs, _selectedDate);

        double totalKwh = 0.0;
        double opMinutes = 0.0;
        final Map<String, double> bars = {};

        if (isToday) {
          totalKwh = device.todayEnergyKwh;
          opMinutes = device.todayRunningMinutes;
          if (log != null) {
            final logKwh = _toDouble(log['totalKwh']);
            final logMins = _toDouble(log['totalRunningMinutes']);
            if (logKwh > totalKwh) totalKwh = logKwh;
            if (logMins > opMinutes) opMinutes = logMins;
          }
        } else if (log != null) {
          totalKwh = _toDouble(log['totalKwh']);
          opMinutes = _toDouble(log['totalRunningMinutes']);
        }

        // Build 24 hours
        for (int h = 0; h < 24; h++) {
          final period = h >= 12 ? 'pm' : 'am';
          final h12 = h % 12 == 0 ? 12 : h % 12;
          final label = '$h12$period';

          double hourVal = 0.0;
          final hourKey = 'h${h.toString().padLeft(2, '0')}';

          if (log != null && log.containsKey(hourKey)) {
            hourVal = _toDouble(log[hourKey]);
          } else if (isToday && h == now.hour) {
            hourVal = device.todayEnergyKwh;
          }

          bars[label] = hourVal;
        }

        return _PeriodData(bars: bars, totalKwh: totalKwh, operationMinutes: opMinutes);
      }

      case EnergyPeriod.week: {
        final Map<String, double> bars = {};
        double totalKwh = 0.0;
        double totalOpMins = 0.0;
        final labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

        for (int i = 0; i < 7; i++) {
          final d = _weekStart.add(Duration(days: i));
          final isToday = _isSameDay(d, now);
          final isFuture = d.isAfter(now) && !isToday;

          double dayKwh = 0.0;
          double dayMins = 0.0;

          if (!isFuture) {
            if (isToday) {
              dayKwh = device.todayEnergyKwh;
              dayMins = device.todayRunningMinutes;
              final log = _findLog(logs, d);
              if (log != null) {
                final logKwh = _toDouble(log['totalKwh']);
                final logMins = _toDouble(log['totalRunningMinutes']);
                if (logKwh > dayKwh) dayKwh = logKwh;
                if (logMins > dayMins) dayMins = logMins;
              }
            } else {
              final log = _findLog(logs, d);
              if (log != null) {
                dayKwh = _toDouble(log['totalKwh']);
                dayMins = _toDouble(log['totalRunningMinutes']);
              }
            }
          }

          bars[labels[i]] = dayKwh;
          totalKwh += dayKwh;
          totalOpMins += dayMins;
        }

        return _PeriodData(bars: bars, totalKwh: totalKwh, operationMinutes: totalOpMins);
      }

      case EnergyPeriod.month: {
        final Map<String, double> bars = {};
        double totalKwh = 0.0;
        double totalOpMins = 0.0;
        final daysInMonth =
            DateTime(_monthStart.year, _monthStart.month + 1, 0).day;

        for (int i = 1; i <= daysInMonth; i++) {
          final d = DateTime(_monthStart.year, _monthStart.month, i);
          final isToday = _isSameDay(d, now);
          final isFuture = d.isAfter(now) && !isToday;

          double dayKwh = 0.0;
          double dayMins = 0.0;

          if (!isFuture) {
            if (isToday) {
              dayKwh = device.todayEnergyKwh;
              dayMins = device.todayRunningMinutes;
              final log = _findLog(logs, d);
              if (log != null) {
                final logKwh = _toDouble(log['totalKwh']);
                final logMins = _toDouble(log['totalRunningMinutes']);
                if (logKwh > dayKwh) dayKwh = logKwh;
                if (logMins > dayMins) dayMins = logMins;
              }
            } else {
              final log = _findLog(logs, d);
              if (log != null) {
                dayKwh = _toDouble(log['totalKwh']);
                dayMins = _toDouble(log['totalRunningMinutes']);
              }
            }
          }

          bars['$i'] = dayKwh;
          totalKwh += dayKwh;
          totalOpMins += dayMins;
        }

        return _PeriodData(bars: bars, totalKwh: totalKwh, operationMinutes: totalOpMins);
      }

      case EnergyPeriod.year: {
        final Map<String, double> bars = {};
        double totalKwh = 0.0;
        double totalOpMins = 0.0;

        for (int m = 1; m <= 12; m++) {
          final label = _monthName(m);
          double monthKwh = 0.0;
          double monthMins = 0.0;

          for (final log in logs) {
            final logYear = _toInt(log['year']);
            final logMonth = _toInt(log['month']);
            if (logYear == _selectedYear && logMonth == m) {
              monthKwh += _toDouble(log['totalKwh']);
              monthMins += _toDouble(log['totalRunningMinutes']);
            }
          }

          // If current year & current month, include live device readings
          if (_selectedYear == now.year && m == now.month) {
            final todayLog = _findLog(logs, now);
            if (todayLog == null) {
              monthKwh += device.todayEnergyKwh;
              monthMins += device.todayRunningMinutes;
            }
          }

          bars[label] = monthKwh;
          totalKwh += monthKwh;
          totalOpMins += monthMins;
        }

        return _PeriodData(bars: bars, totalKwh: totalKwh, operationMinutes: totalOpMins);
      }
    }
  }

  Map<String, dynamic>? _findLog(
      List<Map<String, dynamic>> logs, DateTime date) {
    final key = _dateKey(date);
    for (final log in logs) {
      if (log['date'] == key ||
          (log['id'] != null && (log['id'] as String).endsWith(key))) {
        return log;
      }
    }
    return null;
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is int) return val.toDouble();
    if (val is double) return val;
    return double.tryParse(val.toString()) ?? 0.0;
  }

  int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  String _weekday(int d) => const [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday'
      ][d - 1];

  String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];

  String _monthName(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}

class _PeriodData {
  final Map<String, double> bars;
  final double totalKwh;
  final double operationMinutes;

  _PeriodData({
    required this.bars,
    required this.totalKwh,
    required this.operationMinutes,
  });
}

class _YearPickerDialog extends StatelessWidget {
  final int initialYear;
  const _YearPickerDialog({required this.initialYear});

  @override
  Widget build(BuildContext context) {
    final years = List.generate(10, (i) => initialYear - 5 + i);
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('Select Year',
          style: GoogleFonts.spaceGrotesk(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: double.maxFinite,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: years.map((y) {
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(y),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: y == initialYear
                      ? AppColors.primary.withValues(alpha: 0.18)
                      : AppColors.cardElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: y == initialYear
                        ? AppColors.primary
                        : AppColors.glassBorder,
                  ),
                ),
                child: Text(
                  '$y',
                  style: GoogleFonts.inter(
                    color: y == initialYear ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, color: data.color, size: 16),
            ),
            const Gap(8),
            Text(
              data.value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
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
                fontSize: 10,
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