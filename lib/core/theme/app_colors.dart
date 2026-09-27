import 'package:flutter/material.dart';

/// SaveWise palette.
///
/// Dark is the default because this is a one-handed, end-of-day app: people
/// check their money on the sofa, not at a desk. The greens read as "money in
/// motion" against near-black; brass is reserved for earned things (rewards,
/// milestones, grade markers) so gold always means *you achieved something*.
///
/// Chrome only ever uses ink / slate / hairline / emerald / brass / clay.
/// The two cool accents at the bottom exist solely for data visualisation,
/// where seven categories must stay tellable apart. Never use them in chrome.
abstract final class AppColors {
  // Surfaces
  static const Color ink = Color(0xFF070B0E);
  static const Color inkLift = Color(0xFF0A1014);
  static const Color slate = Color(0xFF0E1519);
  static const Color slateHigh = Color(0xFF141D22);
  static const Color hairline = Color(0xFF1E2A2F);
  static const Color hairlineSoft = Color(0xFF172126);

  // Brand
  static const Color emerald = Color(0xFF18C07A);
  static const Color emeraldSoft = Color(0xFF4BD79C);
  static const Color emeraldDeep = Color(0xFF0B6B4A);
  static const Color brass = Color(0xFFE8B84B);
  static const Color brassDeep = Color(0xFF8A6A1E);
  static const Color clay = Color(0xFFE5674E);
  static const Color clayDeep = Color(0xFF7E3628);

  // Type
  static const Color textPrimary = Color(0xFFEAF2EE);
  static const Color textSecondary = Color(0xFF9DB0A8);
  static const Color textMuted = Color(0xFF6B7C76);
  static const Color textOnAccent = Color(0xFF04140D);

  // Data-viz only
  static const Color vizTeal = Color(0xFF2E9E8F);
  static const Color vizSteel = Color(0xFF4A8CB8);
  static const Color vizMauve = Color(0xFF8B72C4);
  static const Color vizGrey = Color(0xFF5E7079);

  /// Glass card fill. Two stops, both translucent, so whatever sits behind
  /// (the ambient glow on the dashboard) shows through faintly.
  static const LinearGradient glassFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0x14FFFFFF), Color(0x08FFFFFF)],
  );

  static const LinearGradient glassStroke = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0x26FFFFFF), Color(0x0AFFFFFF)],
  );

  static const LinearGradient emeraldSweep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[emerald, emeraldDeep],
  );

  static const LinearGradient brassSweep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[brass, brassDeep],
  );

  /// Colour for a health grade band.
  static Color forScore(int score) {
    if (score >= 90) return emerald;
    if (score >= 75) return emeraldSoft;
    if (score >= 50) return brass;
    return clay;
  }
}
