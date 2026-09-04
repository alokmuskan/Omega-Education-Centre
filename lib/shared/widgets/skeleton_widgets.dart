import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable skeleton loading widgets for placeholder content.
///
/// Usage:
///   if (isLoading) const SkeletonListTile()
///   else ...actualContent
///
/// All skeleton widgets respect the current theme brightness for dark mode.
class SkeletonWidgets {
  SkeletonWidgets._();

  // ── Base Colors ─────────────────────────────────────────────────

  static Color _baseColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade300;
  }

  static Color _highlightColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade700
        : Colors.grey.shade200;
  }

  // ── Full Page Skeletons ─────────────────────────────────────────

  /// A full-page skeleton with multiple card placeholders.
  /// Use as a replacement for centered CircularProgressIndicator.
  static Widget pageSkeleton({int cardCount = 5, bool hasHeader = true}) {
    return Builder(
      builder: (context) => Shimmer.fromColors(
        baseColor: _baseColor(context),
        highlightColor: _highlightColor(context),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (hasHeader) ...[
              // Header skeleton
              _buildBox(context, height: 28, width: 200),
              const SizedBox(height: 12),
              _buildBox(context, height: 16, width: 140),
              const SizedBox(height: 20),
            ],
            // Card skeletons
            for (int i = 0; i < cardCount; i++) ...[
              _buildCardSkeleton(context),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  /// A grid skeleton for dashboard-style layouts.
  static Widget gridSkeleton({int itemCount = 6}) {
    return Builder(
      builder: (context) => Shimmer.fromColors(
        baseColor: _baseColor(context),
        highlightColor: _highlightColor(context),
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) => _buildStatCardSkeleton(context),
        ),
      ),
    );
  }

  // ── Individual Skeleton Widgets ─────────────────────────────────

  /// A list tile skeleton (avatar + two text lines).
  static Widget listTileSkeleton({bool hasTrailing = true}) {
    return Builder(
      builder: (context) => Shimmer.fromColors(
        baseColor: _baseColor(context),
        highlightColor: _highlightColor(context),
        child: ListTile(
          leading: _buildCircle(context, 40),
          title: _buildBox(context, height: 14, width: double.infinity),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _buildBox(context, height: 12, width: 120),
          ),
          trailing: hasTrailing ? _buildBox(context, height: 24, width: 24) : null,
        ),
      ),
    );
  }

  /// A card skeleton with title, subtitle, and content lines.
  static Widget cardSkeleton({int contentLines = 3}) {
    return Builder(
      builder: (context) => Shimmer.fromColors(
        baseColor: _baseColor(context),
        highlightColor: _highlightColor(context),
        child: _buildCardSkeleton(context, contentLines: contentLines),
      ),
    );
  }

  /// A stat/metric card skeleton (for dashboard metrics).
  static Widget statCardSkeleton() {
    return Builder(
      builder: (context) => Shimmer.fromColors(
        baseColor: _baseColor(context),
        highlightColor: _highlightColor(context),
        child: _buildStatCardSkeleton(context),
      ),
    );
  }

  /// A simple text line skeleton.
  static Widget textSkeleton({double? width, double height = 14}) {
    return Builder(
      builder: (context) => Shimmer.fromColors(
        baseColor: _baseColor(context),
        highlightColor: _highlightColor(context),
        child: _buildBox(context, height: height, width: width ?? double.infinity),
      ),
    );
  }

  /// A row of skeleton chips (for filter bars).
  static Widget chipRowSkeleton({int count = 4}) {
    return Builder(
      builder: (context) => Shimmer.fromColors(
        baseColor: _baseColor(context),
        highlightColor: _highlightColor(context),
        child: SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: count,
            separatorBuilder: (ctx, index) => const SizedBox(width: 8),
            itemBuilder: (ctx, index) {
              final widths = [60.0, 80.0, 70.0, 90.0, 65.0, 75.0];
              return _buildBox(
                context,
                height: 32,
                width: widths[index % widths.length],
              );
            },
          ),
        ),
      ),
    );
  }

  /// A table row skeleton (for data tables).
  static Widget tableRowSkeleton({int columns = 4}) {
    return Builder(
      builder: (context) => Shimmer.fromColors(
        baseColor: _baseColor(context),
        highlightColor: _highlightColor(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: List.generate(
              columns,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < columns - 1 ? 12 : 0),
                  child: _buildBox(context, height: 14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Internal Helpers ────────────────────────────────────────────

  static Widget _buildBox(BuildContext context, {
    required double height,
    double? width,
    double borderRadius = 8,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: _baseColor(context),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  static Widget _buildCircle(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _baseColor(context),
        shape: BoxShape.circle,
      ),
    );
  }

  static Widget _buildCardSkeleton(BuildContext context, {int contentLines = 3}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBox(context, height: 16, width: 160),
            const SizedBox(height: 12),
            for (int i = 0; i < contentLines; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildBox(
                  context,
                  height: 12,
                  width: i == contentLines - 1 ? 120 : double.infinity,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _buildStatCardSkeleton(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCircle(context, 32),
            const SizedBox(height: 12),
            _buildBox(context, height: 20, width: 60),
            const SizedBox(height: 8),
            _buildBox(context, height: 12, width: 100),
          ],
        ),
      ),
    );
  }
}
