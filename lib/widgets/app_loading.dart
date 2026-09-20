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
  static Widget _card({required double radius, required double padding, required Widget child, double gap = 12}) =>
      Container(
        margin: EdgeInsets.only(bottom: gap),
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
        child: child,
      );

  static Widget _scroll(EdgeInsets padding, List<Widget> children) => SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: AppSkeleton(loading: true, child: Column(children: children)),
      );

  static Widget patientList({int count = 5}) => _scroll(
        const EdgeInsets.all(16),
        [
          for (var i = 0; i < count; i++)
            _card(
              radius: 20,
              padding: 16,
              gap: 16,
              child: Column(
                children: [
                  Align(alignment: Alignment.centerRight, child: _block(width: 110, height: 24, radius: 10)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Bone.circle(size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Bone.text(words: 2, fontSize: 16),
                            const SizedBox(height: 4),
                            const Bone.text(words: 2, fontSize: 12),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _block(width: 64, height: 34, radius: 10),
                                const SizedBox(width: 12),
                                Expanded(child: _block(height: 34, radius: 10)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );

  static Widget clientList({int count = 7}) => _scroll(
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        [
          for (var i = 0; i < count; i++)
            _card(
              radius: 24,
              padding: 20,
              child: Row(
                children: [
                  const Bone.circle(size: 56),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Bone.text(words: 2, fontSize: 16),
                        SizedBox(height: 2),
                        Bone.text(words: 3, fontSize: 12)
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _block(width: 14, height: 14, radius: 4),
                ],
              ),
            ),
        ],
      );

  static Widget teamList({int count = 6}) => _scroll(
        const EdgeInsets.fromLTRB(20, 10, 20, 30),
        [
          for (var i = 0; i < count; i++)
            _card(
              radius: 20,
              padding: 16,
              child: Row(
                children: [
                  const Bone.circle(size: 56),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Bone.text(words: 2, fontSize: 16),
                        const Bone.text(words: 3, fontSize: 13),
                        const SizedBox(height: 8),
                        Row(children: [
                          _block(width: 90, height: 22, radius: 8),
                          const SizedBox(width: 8),
                          _block(width: 70, height: 22, radius: 8)
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );

  static Widget auditList({int count = 4}) => _scroll(
        const EdgeInsets.fromLTRB(20, 8, 20, 20),
        [
          for (var i = 0; i < count; i++)
            _card(
              radius: 28,
              padding: 20,
              gap: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [_block(width: 90, height: 26, radius: 12), const Bone.text(words: 1, fontSize: 12)],
                  ),
                  const SizedBox(height: 15),
                  const Bone.text(words: 3, fontSize: 16),
                  const SizedBox(height: 6),
                  const Bone.text(words: 8, fontSize: 13),
                  const SizedBox(height: 20),
                  Row(children: [
                    const Bone.circle(size: 28),
                    const SizedBox(width: 8),
                    const Bone.text(words: 3, fontSize: 12)
                  ]),
                ],
              ),
            ),
        ],
      );

  static Widget coachDashboard() => AppSkeleton(
        loading: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: _block(height: 98, radius: 20)),
              const SizedBox(width: 12),
              Expanded(child: _block(height: 98, radius: 20))
            ]),
            const SizedBox(height: 24),
            const Bone.text(words: 3, fontSize: 13),
            const SizedBox(height: 12),
            _block(height: 70, radius: 20),
            const SizedBox(height: 8),
            _block(height: 70, radius: 20),
            const SizedBox(height: 24),
            _block(height: 230, radius: 24),
            const SizedBox(height: 24),
            _block(height: 96, radius: 24),
            const SizedBox(height: 40),
          ],
        ),
      );
  static Widget staffDashboard({bool admin = false}) => AppSkeleton(
        loading: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!admin) ...[
              const Bone.text(words: 4, fontSize: 14),
              const SizedBox(height: 15),
              _block(height: 64, radius: 20),
              const SizedBox(height: 35),
            ],
            const Bone.text(words: 3, fontSize: 14),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _block(height: 128, radius: 24)),
              const SizedBox(width: 15),
              Expanded(child: _block(height: 128, radius: 24))
            ]),
            const SizedBox(height: 20),
            _block(height: admin ? 180 : 190, radius: 24),
            const SizedBox(height: 35),
            const Bone.text(words: 3, fontSize: 14),
            const SizedBox(height: 15),
            _block(height: 90, radius: 24),
            const SizedBox(height: 40),
          ],
        ),
      );
  static Widget expediente() => SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: AppSkeleton(
          loading: true,
          child: Column(
            children: [
              _block(height: 118, radius: 24),
              const SizedBox(height: 24),
              _block(height: 210, radius: 24),
              const SizedBox(height: 24),
              _block(height: 190, radius: 24),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _block(height: 96, radius: 20)),
                const SizedBox(width: 12),
                Expanded(child: _block(height: 96, radius: 20))
              ]),
              const SizedBox(height: 24),
              _block(height: 130, radius: 24),
              const SizedBox(height: 24),
              _block(height: 220, radius: 24),
            ],
          ),
        ),
      );

  static Widget registroDia() => AppSkeleton(
        loading: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Bone.text(words: 2, fontSize: 13),
            const SizedBox(height: 10),
            _block(height: 52, radius: 14),
            const SizedBox(height: 16),
            const Bone.text(words: 2, fontSize: 13),
            const SizedBox(height: 10),
            _block(height: 52, radius: 14),
          ],
        ),
      );
  static Widget _campoPerfil() => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Row(children: [Bone.circle(size: 22), SizedBox(width: 12), Bone.text(words: 2, fontSize: 16)]),
      );

  static Widget perfilCliente() => SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: AppSkeleton(
                        loading: true,
                        child: const CircleAvatar(
                            radius: 50, backgroundColor: Colors.white, child: Bone.circle(size: 100)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))
                  ],
                  border: Border.all(color: Colors.blue.shade50),
                ),
                child: AppSkeleton(
                  loading: true,
                  child: Column(
                    children: [
                      const Bone.text(words: 2, fontSize: 24),
                      const SizedBox(height: 6),
                      const Bone.text(words: 3, fontSize: 14),
                      const SizedBox(height: 16),
                      _block(width: 150, height: 34, radius: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppSkeleton(
                loading: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                        padding: EdgeInsets.only(bottom: 16, top: 8), child: Bone.text(words: 2, fontSize: 18)),
                    for (var i = 0; i < 4; i++) _campoPerfil(),
                    Row(children: [
                      Expanded(child: _campoPerfil()),
                      const SizedBox(width: 16),
                      Expanded(child: _campoPerfil())
                    ]),
                    const SizedBox(height: 8),
                    const Padding(
                        padding: EdgeInsets.only(bottom: 16, top: 8), child: Bone.text(words: 3, fontSize: 18)),
                    for (var i = 0; i < 3; i++) _campoPerfil(),
                  ],
                ),
              ),
            ),
          ],
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
