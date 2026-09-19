import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../app_theme.dart';

class AppLoading extends StatelessWidget {
  final double size;
  final String? message;

  const AppLoading({super.key, this.size = 36, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class AppButtonLoader extends StatelessWidget {
  final double size;
  final Color color;

  const AppButtonLoader({super.key, this.size = 22, this.color = Colors.white});

  const AppButtonLoader.primary({super.key, this.size = 22}) : color = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
    );
  }
}

class AppSkeleton extends StatelessWidget {
  final bool loading;
  final bool onDark;
  final Widget child;

  const AppSkeleton({super.key, required this.loading, required this.child, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: loading,
      effect: ShimmerEffect(
        baseColor: onDark ? const Color(0x38FFFFFF) : const Color(0xFFD8E1EC),
        highlightColor: onDark ? const Color(0x73FFFFFF) : const Color(0xFFF1F5F9),
        duration: const Duration(milliseconds: 1300),
      ),
      enableSwitchAnimation: true,
      child: child,
    );
  }
}

class SkeletonBlocks {
  const SkeletonBlocks._();

  static Widget _block({double? width, required double height, double radius = 16}) =>
      Bone(width: width ?? double.infinity, height: height, borderRadius: BorderRadius.circular(radius));

  static Widget _macroRow({required double height, required double gap, required double radius}) => Row(
        children: [
          Expanded(child: _block(height: height, radius: radius)),
          SizedBox(width: gap),
          Expanded(child: _block(height: height, radius: radius)),
          SizedBox(width: gap),
          Expanded(child: _block(height: height, radius: radius)),
        ],
      );

  static Widget dashboard({bool padded = true}) => AppSkeleton(
        loading: true,
        child: Padding(
          padding: padded ? const EdgeInsets.all(20) : EdgeInsets.zero,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  child: _block(width: 230, height: 34, radius: 20),
                ),
              ),
              const SizedBox(height: 4),
              _block(height: 375, radius: 32),
              const SizedBox(height: 20),
              _macroRow(height: 129, gap: 15, radius: 20),
              const SizedBox(height: 20),
              _block(height: 120, radius: 24),
              const SizedBox(height: 20),
              _block(height: 150, radius: 24),
            ],
          ),
        ),
      );

  static Widget racha() => AppSkeleton(loading: true, onDark: true, child: _block(height: 114, radius: 16));

  static Widget weekTab() => AppSkeleton(
        loading: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Row(
                  children: [
                    Bone.circle(size: 28),
                    Expanded(child: Center(child: Bone.text(words: 3))),
                    Bone.circle(size: 28),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _block(height: 150, radius: 20),
              const SizedBox(height: 16),
              _block(height: 290, radius: 20),
              const SizedBox(height: 16),
              const Bone.text(words: 3),
              const SizedBox(height: 10),
              for (var i = 0; i < 7; i++) ...[
                _block(height: 70, radius: 16),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      );

  static Widget historico() => AppSkeleton(
        loading: true,
        child: Column(
          children: [
            _block(height: 260, radius: 20),
            const SizedBox(height: 16),
            _block(height: 260, radius: 20),
            const SizedBox(height: 16),
            _block(height: 140, radius: 20),
          ],
        ),
      );

  static Widget heroData() => AppSkeleton(
        loading: true,
        onDark: true,
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone.text(words: 1, fontSize: 26),
                    SizedBox(height: 4),
                    Bone.text(words: 2, fontSize: 13),
                  ],
                ),
                Bone.text(words: 1, fontSize: 18),
              ],
            ),
            const SizedBox(height: 10),
            _block(height: 8, radius: 8),
            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [_HeroStatBone(), _HeroStatBone(), _HeroStatBone()],
            ),
          ],
        ),
      );

  static Widget macroPills() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: AppSkeleton(loading: true, child: _macroRow(height: 100, gap: 12, radius: 18)),
      );

  static Widget cards({int count = 4}) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: AppSkeleton(
          loading: true,
          child: Column(
            children: [
              for (var i = 0; i < count; i++) ...[
                _block(height: 74, radius: 16),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      );
}

class _HeroStatBone extends StatelessWidget {
  const _HeroStatBone();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Bone.circle(size: 16),
        SizedBox(height: 4),
        Bone.text(words: 1, fontSize: 17),
        Bone.text(words: 1, fontSize: 11),
      ],
    );
  }
}
