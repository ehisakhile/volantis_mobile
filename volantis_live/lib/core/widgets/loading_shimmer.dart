import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';

/// Custom loading shimmer widget for skeleton loading states
class LoadingShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const LoadingShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Channel card shimmer for loading state
class ChannelCardShimmer extends StatelessWidget {
  const ChannelCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LoadingShimmer(
            width: 160,
            height: 160,
            borderRadius: 12,
          ),
          const SizedBox(height: 8),
          const LoadingShimmer(
            width: 120,
            height: 16,
            borderRadius: 4,
          ),
          const SizedBox(height: 4),
          LoadingShimmer(
            width: 80,
            height: 12,
            borderRadius: 4,
            margin: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// List item shimmer for loading state
class ListItemShimmer extends StatelessWidget {
  const ListItemShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const LoadingShimmer(
            width: 60,
            height: 60,
            borderRadius: 8,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                LoadingShimmer(
                  width: 150,
                  height: 16,
                  borderRadius: 4,
                ),
                SizedBox(height: 8),
                LoadingShimmer(
                  width: 100,
                  height: 12,
                  borderRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full screen shimmer loading
class FullScreenShimmer extends StatelessWidget {
  const FullScreenShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LoadingShimmer(
              width: 200,
              height: 24,
              borderRadius: 4,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                itemBuilder: (context, index) => const ChannelCardShimmer(),
              ),
            ),
            const SizedBox(height: 24),
            const LoadingShimmer(
              width: 200,
              height: 24,
              borderRadius: 4,
            ),
            const SizedBox(height: 16),
            ...List.generate(
              4,
              (index) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ListItemShimmer(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini player shimmer
class MiniPlayerShimmer extends StatelessWidget {
  const MiniPlayerShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const LoadingShimmer(
            width: 56,
            height: 56,
            borderRadius: 8,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                LoadingShimmer(
                  width: 120,
                  height: 14,
                  borderRadius: 4,
                ),
                SizedBox(height: 6),
                LoadingShimmer(
                  width: 80,
                  height: 12,
                  borderRadius: 4,
                ),
              ],
            ),
          ),
          const LoadingShimmer(
            width: 40,
            height: 40,
            borderRadius: 20,
          ),
        ],
      ),
    );
  }
}