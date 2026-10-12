import 'package:flutter/material.dart';

class AppShimmer extends StatefulWidget {
  const AppShimmer({required this.child, super.key});

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final position = (_controller.value * 3) - 1.5;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(position - 1, 0),
            end: Alignment(position + 1, 0),
            colors: const [
              Color(0xffe8e2dd),
              Color(0xfff8f5f2),
              Color(0xffe8e2dd),
            ],
            stops: const [.2, .5, .8],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    this.width,
    this.height,
    this.borderRadius = 12,
    super.key,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xffe8e2dd),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class ShimmerNetworkImage extends StatelessWidget {
  const ShimmerNetworkImage({
    required this.url,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    super.key,
  });

  final String url;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const AppShimmer(child: ShimmerBox(borderRadius: 0));
      },
      errorBuilder: errorBuilder,
    );
  }
}
