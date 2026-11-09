import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Paleta dos stories da Retrospectiva (protótipo aprovado em 02/11/2026).
/// É a mesma imagem no app e no site, então as cores são fixas, sem tema claro/escuro.
class RetroColors {
  RetroColors._();

  static const ink = AppColors.darkApp;
  static const white = Color(0xFFFFFFFF);

  static const greenA = AppColors.accentBackground;
  static const greenB = AppColors.accent;
  static const darkA = AppColors.darkApp;
  static const darkB = AppColors.darkCard;
  static const blueA = Color(0xFF1D4FB8);
  static const blueB = AppColors.info;
  static const yellowA = AppColors.warning;
  static const yellowB = Color(0xFFFFD34D);
  static const redA = Color(0xFF9F2A2A);
  static const redB = AppColors.prototypeDanger;

  static const win = AppColors.accent;
  static const draw = AppColors.warning;
  static const loss = AppColors.prototypeDanger;

  // Sobreposições usadas no cartão (anéis, pílulas, linhas).
  static const white07 = Color(0x12FFFFFF);
  static const white06 = Color(0x0FFFFFFF);
  static const white15 = Color(0x26FFFFFF);
  static const white18 = Color(0x2EFFFFFF);
  static const white22 = Color(0x38FFFFFF);
  static const white30 = Color(0x4DFFFFFF);
  static const white90 = Color(0xE6FFFFFF);
  static const black06 = Color(0x0F000000);
  static const black07 = Color(0x12000000);
  static const black14 = Color(0x24000000);
  static const black20 = Color(0x33000000);
  static const black22 = Color(0x38000000);
  static const black25 = Color(0x40000000);
  static const black28 = Color(0x47000000);
  static const ink22 = Color(0x380D0D0F);
  static const scrim = Color(0x8C000000);
}
