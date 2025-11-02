import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key, required this.firestore});
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('items').snapshots(),
      builder: (context, itemsSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('users').snapshots(),
          builder: (context, usersSnap) {
            if (!itemsSnap.hasData || !usersSnap.hasData) {
              return Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              );
            }

            final items =
                itemsSnap.data?.docs.map((e) => e.data()).toList() ?? [];
            final users = usersSnap.data?.docs ?? [];
            final lostCount = items
                .where((e) => (e['type'] ?? 'lost') == 'lost')
                .length;
            final foundCount =
                items.where((e) => (e['type'] ?? '') == 'found').length;
            final claimed =
                items.where((e) => (e['status'] ?? '') == 'claimed').length;

            // Calculate items posted in last 7 days
            final now = DateTime.now();
            final sevenDaysAgo = now.subtract(const Duration(days: 7));
            final itemsInLast7Days = items.where((item) {
              final createdAt = item['createdAt'];
              if (createdAt is Timestamp) {
                return createdAt.toDate().isAfter(sevenDaysAgo);
              }
              return false;
            }).length;

            // Calculate daily posts for last 7 days
            final dailyPosts = List.generate(7, (index) {
              final date = now.subtract(Duration(days: 6 - index));
              final startOfDay = DateTime(date.year, date.month, date.day);
              final endOfDay = startOfDay.add(const Duration(days: 1));
              return items.where((item) {
                final createdAt = item['createdAt'];
                if (createdAt is Timestamp) {
                  final itemDate = createdAt.toDate();
                  return itemDate.isAfter(startOfDay) &&
                      itemDate.isBefore(endOfDay);
                }
                return false;
              }).length;
            });

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          theme.scaffoldBackgroundColor,
                          theme.scaffoldBackgroundColor.withOpacity(0.95),
                        ]
                      : [
                          Colors.grey.shade50,
                          Colors.white,
                        ],
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 20,
                        top: 20,
                        right: 20,
                        bottom: MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight - 32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    // Header
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Welcome back, Admin',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Main Stat Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 3 : 2;
                        // More generous aspect ratio to prevent overflow
                        final aspectRatio = constraints.maxWidth > 900 
                            ? 1.5 
                            : constraints.maxWidth > 600 
                                ? 1.7 
                                : 2.0;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: constraints.maxWidth > 600 ? 16 : 12,
                          crossAxisSpacing: constraints.maxWidth > 600 ? 16 : 12,
                          childAspectRatio: aspectRatio,
                          children: [
                            _ModernStatCard(
                              title: 'Lost Items',
                              value: lostCount.toString(),
                              icon: Icons.report_gmailerrorred,
                              gradient: [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)],
                              subtitle: 'Need to be found',
                            ),
                            _ModernStatCard(
                              title: 'Found Items',
                      value: foundCount.toString(),
                      icon: Icons.inventory_2,
                              gradient: [const Color(0xFF4ECDC4), const Color(0xFF44A08D)],
                              subtitle: 'Waiting for owners',
                    ),
                            _ModernStatCard(
                      title: 'Claimed',
                      value: claimed.toString(),
                      icon: Icons.verified,
                              gradient: [const Color(0xFF11998E), const Color(0xFF38EF7D)],
                              subtitle: 'Successfully returned',
                            ),
                            _ModernStatCard(
                              title: 'Total Users',
                              value: users.length.toString(),
                              icon: Icons.people,
                              gradient: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                              subtitle: 'Registered users',
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Charts Row
                    _ModernPieChartCard(
                      title: 'Lost vs Found',
                      lostCount: lostCount,
                      foundCount: foundCount,
                    ),
                    const SizedBox(height: 32),

                    // Line Chart
                    _ModernLineChartCard(
                      title: 'Activity Overview',
                      subtitle: 'Items posted in the last 7 days',
                      dailyPosts: dailyPosts,
                      itemsInLast7Days: itemsInLast7Days,
                      bottomPadding: 0,
                    ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ModernStatCard extends StatelessWidget {
  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.subtitle,
  });
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Aggressive responsive sizing based on available space
        final cardHeight = constraints.maxHeight;
        final isVerySmall = cardHeight < 100;
        final isSmall = cardHeight < 130;
        final isMedium = cardHeight < 150;
        
        // Calculate sizes based on available space - make text bigger and more visible
        final iconSize = isVerySmall ? 24.0 : isSmall ? 28.0 : isMedium ? 32.0 : 36.0;
        final valueFontSize = isVerySmall ? 32.0 : isSmall ? 38.0 : isMedium ? 44.0 : 48.0;
        final titleFontSize = isVerySmall ? 12.0 : isSmall ? 14.0 : 16.0;
        final subtitleFontSize = isVerySmall ? 9.0 : isSmall ? 10.0 : 11.0;
        final padding = isVerySmall ? 8.0 : isSmall ? 10.0 : isMedium ? 12.0 : 14.0;
        final iconPadding = isVerySmall ? 8.0 : isSmall ? 10.0 : isMedium ? 12.0 : 14.0;
        final textSpacing = isVerySmall ? 2.0 : isSmall ? 3.0 : 4.0;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Stack(
              children: [
                // Icon positioned at top right
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(iconPadding),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: iconSize),
                  ),
                ),
                // Value and text positioned on the left
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Value text - big and prominent
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: valueFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: textSpacing),
                      // Title text - bigger and visible
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Subtitle text - only show if there's enough space
                      if (!isVerySmall && cardHeight > 100) ...[
                        SizedBox(height: textSpacing / 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: subtitleFontSize,
                            color: Colors.white.withOpacity(0.8),
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModernPieChartCard extends StatelessWidget {
  const _ModernPieChartCard({
    required this.title,
    required this.lostCount,
    required this.foundCount,
  });
  final String title;
  final int lostCount;
  final int foundCount;

  @override
  Widget build(BuildContext context) {
    final total = lostCount + foundCount;
    if (total == 0) {
      return _ModernEmptyChartCard(title: title);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 160,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          value: lostCount.toDouble(),
                          title: '${((lostCount / total) * 100).toStringAsFixed(1)}%',
                          color: const Color(0xFFFF6B6B),
                          radius: 55,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          value: foundCount.toDouble(),
                          title: '${((foundCount / total) * 100).toStringAsFixed(1)}%',
                          color: const Color(0xFF4ECDC4),
                          radius: 55,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ModernLegendItem(
                      color: const Color(0xFFFF6B6B),
                      label: 'Lost',
                      value: lostCount.toString(),
                    ),
                    const SizedBox(height: 16),
                    _ModernLegendItem(
                      color: const Color(0xFF4ECDC4),
                      label: 'Found',
                      value: foundCount.toString(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModernLineChartCard extends StatelessWidget {
  const _ModernLineChartCard({
    required this.title,
    required this.subtitle,
    required this.dailyPosts,
    required this.itemsInLast7Days,
    this.bottomPadding = 16,
  });
  final String title;
  final String subtitle;
  final List<int> dailyPosts;
  final int itemsInLast7Days;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = dailyPosts.isEmpty
        ? 1
        : dailyPosts.reduce(math.max) == 0
            ? 1
            : dailyPosts.reduce(math.max);

    final spots = dailyPosts.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.toDouble());
    }).toList();

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: EdgeInsets.only(left: 20, right: 20, bottom: bottomPadding),
          child: SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              days[value.toInt()],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.max) {
                          return const Text('');
                        }
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    left: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                ),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxValue.toDouble() * 1.3,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(
                      show: true,
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.3),
                          theme.colorScheme.primary.withOpacity(0.05),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModernChartCard extends StatelessWidget {
  const _ModernChartCard({
    required this.title,
    this.subtitle,
    required this.child,
    this.bottomPadding = 16,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark 
            ? theme.cardColor 
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

class _ModernLegendItem extends StatelessWidget {
  const _ModernLegendItem({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$value items',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModernEmptyChartCard extends StatelessWidget {
  const _ModernEmptyChartCard({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark 
            ? theme.cardColor 
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bar_chart_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No data available',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
