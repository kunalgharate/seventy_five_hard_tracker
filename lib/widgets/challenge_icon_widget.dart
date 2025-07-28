import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/challenge.dart';
import '../services/challenge_icon_service.dart';
import '../services/dynamic_color_service.dart';

class ChallengeIconWidget extends StatelessWidget {
  final Challenge challenge;
  final double size;
  final bool showAnimation;
  final VoidCallback? onTap;

  const ChallengeIconWidget({
    super.key,
    required this.challenge,
    this.size = 48.0,
    this.showAnimation = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = _buildIconContent();

    if (showAnimation) {
      iconWidget = iconWidget
          .animate()
          .scale(
            duration: 300.ms,
            curve: Curves.elasticOut,
          )
          .fadeIn(duration: 200.ms);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.2),
          gradient: _getGradient(),
          boxShadow: [
            BoxShadow(
              color: _getIconColor().withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: iconWidget,
      ),
    );
  }

  Widget _buildIconContent() {
    // Custom image takes priority
    if (challenge.imagePath != null && challenge.imagePath!.isNotEmpty) {
      return _buildCustomImage();
    }

    // Use predefined icon
    if (challenge.iconName != null && challenge.iconName!.isNotEmpty) {
      return _buildPredefinedIcon();
    }

    // Auto-detect icon based on title
    return _buildAutoDetectedIcon();
  }

  Widget _buildCustomImage() {
    final imagePath = challenge.imagePath!;
    
    if (imagePath.startsWith('http')) {
      // Network image
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: CachedNetworkImage(
          imageUrl: imagePath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildLoadingPlaceholder(),
          errorWidget: (context, url, error) => _buildAutoDetectedIcon(),
        ),
      );
    } else {
      // Local file
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.file(
          File(imagePath),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildAutoDetectedIcon(),
        ),
      );
    }
  }

  Widget _buildPredefinedIcon() {
    final iconData = ChallengeIconService.getAllIcons()
        .firstWhere(
          (icon) => icon.name == challenge.iconName,
          orElse: () => ChallengeIconService.getAllIcons().first,
        );

    return Center(
      child: FaIcon(
        iconData.icon,
        size: size * 0.5,
        color: Colors.white,
      ),
    );
  }

  Widget _buildAutoDetectedIcon() {
    final iconData = ChallengeIconService.findBestIcon(challenge.title);
    
    return Center(
      child: FaIcon(
        iconData?.icon ?? FontAwesomeIcons.star,
        size: size * 0.5,
        color: Colors.white,
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        color: Colors.grey[300],
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.3,
          height: size * 0.3,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Color _getIconColor() {
    if (challenge.iconColor != null) {
      return Color(challenge.iconColor!);
    }

    // Use dynamic color service for better colors
    if (challenge.title.isNotEmpty) {
      return DynamicColorService.getColorForText(challenge.title);
    }

    if (challenge.iconName != null) {
      final iconData = ChallengeIconService.getAllIcons()
          .firstWhere(
            (icon) => icon.name == challenge.iconName,
            orElse: () => ChallengeIconService.getAllIcons().first,
          );
      return iconData.color;
    }

    final autoIcon = ChallengeIconService.findBestIcon(challenge.title);
    return autoIcon?.color ?? DynamicColorService.getRandomColor();
  }

  LinearGradient _getGradient() {
    // Use dynamic gradient service for better gradients
    if (challenge.title.isNotEmpty) {
      return DynamicColorService.getGradientForText(challenge.title);
    }
    
    final baseColor = _getIconColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        DynamicColorService.getLighterShade(baseColor, 0.2),
        baseColor,
        DynamicColorService.getDarkerShade(baseColor, 0.1),
      ],
    );
  }
}

class AnimatedChallengeIcon extends StatefulWidget {
  final Challenge challenge;
  final double size;
  final VoidCallback? onTap;

  const AnimatedChallengeIcon({
    super.key,
    required this.challenge,
    this.size = 48.0,
    this.onTap,
  });

  @override
  State<AnimatedChallengeIcon> createState() => _AnimatedChallengeIconState();
}

class _AnimatedChallengeIconState extends State<AnimatedChallengeIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _controller.forward(from: 0);
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value,
              child: ChallengeIconWidget(
                challenge: widget.challenge,
                size: widget.size,
                showAnimation: false,
              ),
            ),
          );
        },
      ),
    );
  }
}
