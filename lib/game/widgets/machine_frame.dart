import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Decorative rounded frame around the pixel canvas — the "machine window".
class MachineFrame extends StatelessWidget {
  const MachineFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.frameLight, AppColors.frame],
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.frameShadow,
            offset: Offset(0, 6),
            blurRadius: 14,
          ),
          BoxShadow(
            color: Color(0x22FFFFFF),
            offset: Offset(0, -1),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppColors.panelDeep,
          border: Border.all(color: const Color(0xFF0B0718), width: 3),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
