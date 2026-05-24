import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../services/theme_provider.dart';
import '../archive/archive_page.dart';
import '../note/notes_page.dart';
import '../settings/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  static const double _minLayoutWidth = 320;

  late final List<Widget> pages = [
    _buildNotesPage(),
    _buildArchivePage(),
    _buildSettingsPage(),
  ];

  /// 底部胶囊宽度、内边距与图标尺寸随屏宽插值（窄屏紧凑、宽屏舒展）。
  _GlassBarMetrics _glassMetrics(double screenWidth) {
    const swMin = 320.0;
    const swMax = 900.0;
    final t = ((screenWidth - swMin) / (swMax - swMin)).clamp(0.0, 1.0);
    double lerp(double a, double b) => a + (b - a) * t;
    const sideInset = 16.0;
    // 总宽：尽量贴齐左右边距，上下限防止过扁或过宽
    final barW = (screenWidth - sideInset * 2).clamp(272.0, 620.0);
    final padH = lerp(10, 16);
    final padV = lerp(8, 11);
    final iconSize = lerp(20, 24);
    final labelFontSize = lerp(10, 11.5);
    final pillRadius = lerp(14, 18);
    // 与 _buildNavItem 内边距一致：vertical 6*2 + 图标 + 间距 + 文字行高
    final innerNavH = 12 + iconSize + 4 + labelFontSize * 1.15;
    final barH = padV * 2 + innerNavH + 4;
    return _GlassBarMetrics(
      barWidth: barW,
      barHeight: barH,
      horizontalPadding: padH,
      verticalPadding: padV,
      iconSize: iconSize,
      labelFontSize: labelFontSize,
      pillRadius: pillRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = AppGlassNavBarTheme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final glassBottomReserve = 84.0 + bottomInset;

    final scaffold = Scaffold(
      extendBody: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: EdgeInsets.only(bottom: glassBottomReserve),
        child: IndexedStack(
          index: _currentIndex.clamp(0, pages.length - 1),
          sizing: StackFit.expand,
          children: pages,
        ),
      ),
      bottomNavigationBar: _buildLiquidGlassBottomBar(context, glass),
    );
    // 左右滑动
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _minLayoutWidth) {
          return scaffold;
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: _minLayoutWidth, child: scaffold),
        );
      },
    );
  }

  Widget _buildLiquidGlassBottomBar(BuildContext context, AppGlassNavBarTheme glass) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final sw = MediaQuery.sizeOf(context).width;
    final m = _glassMetrics(sw);
    final page = _currentIndex.toDouble();

    // bottomNavigationBar 在竖直方向往往约束很「高」；用 Center 会把胶囊垂直居中，看起来像漂在中间。
    // 固定槽位高度 + Align(bottomCenter)，保证贴在窗口下沿（再留出 bottomMargin）。
    final bottomMargin = 10.0 + bottomSafe;
    return SizedBox(
      width: double.infinity,
      height: m.barHeight + bottomMargin,
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomMargin),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: m.barWidth,
            height: m.barHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: glass.barShadow,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        width: 0.5,
                        color: glass.barBorder,
                      ),
                      color: glass.barFill,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: m.horizontalPadding,
                        vertical: m.verticalPadding,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final trackW = constraints.maxWidth;
                          final segment = trackW / 3;
                          return Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.centerLeft,
                            children: [
                              Positioned(
                                left: page * segment,
                                top: 0,
                                bottom: 0,
                                width: segment,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      m.pillRadius,
                                    ),
                                    color: glass.selectionPill,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildNavItem(
                                      0,
                                      Icons.description_outlined,
                                      '笔记',
                                      glass,
                                      m,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildNavItem(
                                      1,
                                      Icons.archive_outlined,
                                      '归档',
                                      glass,
                                      m,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildNavItem(
                                      2,
                                      Icons.settings_outlined,
                                      '设置',
                                      glass,
                                      m,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    AppGlassNavBarTheme glass,
    _GlassBarMetrics m,
  ) {
    final isSelected = index == _currentIndex;
    final unselectedColor = glass.navUnselected;
    final selectedColor = glass.navSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() => _currentIndex = index);
        },
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: m.iconSize,
                  color: isSelected ? selectedColor : unselectedColor,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: m.labelFontSize,
                    height: 1.1,
                    letterSpacing: -0.12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? selectedColor : unselectedColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildNotesPage() {
    return const NotePages();
  }

  static Widget _buildArchivePage() {
    return const ArchivePage();
  }

  static Widget _buildSettingsPage() {
    return const SettingsPage();
  }
}

class _GlassBarMetrics {
  const _GlassBarMetrics({
    required this.barWidth,
    required this.barHeight,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.iconSize,
    required this.labelFontSize,
    required this.pillRadius,
  });

  final double barWidth;
  final double barHeight;
  final double horizontalPadding;
  final double verticalPadding;
  final double iconSize;
  final double labelFontSize;
  final double pillRadius;
}
