import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_colors.dart';

/// Custom network image widget with caching and placeholder
class CustomNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool isSvg;

  const CustomNetworkImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 8,
    this.placeholder,
    this.errorWidget,
    this.isSvg = false,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    if (isSvg || imageUrl!.endsWith('.svg')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SvgPicture.network(
          imageUrl!,
          width: width,
          height: height,
          fit: fit,
          placeholderBuilder: (context) => placeholder ?? _buildPlaceholder(),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
        errorWidget: (context, url, error) =>
            errorWidget ?? _buildErrorWidget(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.textSecondary,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.textSecondary,
          size: 32,
        ),
      ),
    );
  }
}

/// Channel artwork widget
class ChannelArtwork extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final bool isLive;
  final bool showLiveBadge;
  final VoidCallback? onTap;

  const ChannelArtwork({
    super.key,
    this.imageUrl,
    this.size = 80,
    this.isLive = false,
    this.showLiveBadge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          CustomNetworkImage(
            imageUrl: imageUrl,
            width: size,
            height: size,
            borderRadius: 12,
          ),
          if (isLive && showLiveBadge)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.live,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Avatar widget
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? initials;
  final double size;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = 40,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? CustomNetworkImage(
              imageUrl: imageUrl,
              width: size,
              height: size,
              borderRadius: size / 2,
              fit: BoxFit.cover,
            )
          : Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials ?? '?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: size / 2.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
    );
  }
}