import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x47000000), blurRadius: 30, offset: Offset(0, 8)),
  ];

  static final bottomPanel = [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: 0.34),
      blurRadius: 26,
      offset: const Offset(0, -8),
    ),
  ];

  const AppShadows._();
}
