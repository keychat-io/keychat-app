import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff8700ED),
      surfaceTint: Color(0xff695392),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff634d8c),
      onPrimaryContainer: Color(0xfffffeff),
      secondary: Color(0xff783776),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffa15c9d),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff962712),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffc84b33),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff410002),
      surface: Color(0xfffef7fe),
      onSurface: Color(0xff1d1b1f),
      onSurfaceVariant: Color(0xff49454f),
      outline: Color(0xff7b7580),
      outlineVariant: Color(0xffcbc4d0),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff322f34),
      inversePrimary: Color(0xffd4bbff),
      primaryFixed: Color(0xffebdcff),
      onPrimaryFixed: Color(0xff240b4b),
      primaryFixedDim: Color(0xffd4bbff),
      onPrimaryFixedVariant: Color(0xff513b79),
      secondaryFixed: Color(0xffffd6f7),
      onSecondaryFixed: Color(0xff380039),
      secondaryFixedDim: Color(0xfffcacf3),
      onSecondaryFixedVariant: Color(0xff6d2d6c),
      tertiaryFixed: Color(0xffffdad3),
      onTertiaryFixed: Color(0xff3e0400),
      tertiaryFixedDim: Color(0xffffb4a5),
      onTertiaryFixedVariant: Color(0xff891d09),
      surfaceDim: Color(0xffded8de),
      surfaceBright: Color(0xfffef7fe),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff8f2f8),
      surfaceContainer: Color(0xfff2ecf2),
      surfaceContainerHigh: Color(0xffece6ec),
      surfaceContainerHighest: Color(0xffe7e1e7),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff3f2966),
      surfaceTint: Color(0xff695392),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff634d8c),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff692967),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffa15c9d),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff831906),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffc84b33),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff8c0009),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffda342e),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffef7fe),
      onSurface: Color(0xff1d1b1f),
      onSurfaceVariant: Color(0xff45414b),
      outline: Color(0xff625d68),
      outlineVariant: Color(0xff7e7884),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff322f34),
      inversePrimary: Color(0xffd4bbff),
      primaryFixed: Color(0xff8069aa),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff675090),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xffa15c9d),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff854382),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xffc84b33),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xffa7331d),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffded8de),
      surfaceBright: Color(0xfffef7fe),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff8f2f8),
      surfaceContainer: Color(0xfff2ecf2),
      surfaceContainerHigh: Color(0xffece6ec),
      surfaceContainerHighest: Color(0xffe7e1e7),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff2b1451),
      surfaceTint: Color(0xff695392),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff4d3775),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff420244),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff692967),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff4b0600),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff831906),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff4e0002),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff8c0009),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffef7fe),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff26222b),
      outline: Color(0xff45414b),
      outlineVariant: Color(0xff45414b),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff322f34),
      inversePrimary: Color(0xfff3e8ff),
      primaryFixed: Color(0xff4d3775),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff36205d),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff692967),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff4e104f),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff831906),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff5e0a00),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffded8de),
      surfaceBright: Color(0xfffef7fe),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff8f2f8),
      surfaceContainer: Color(0xfff2ecf2),
      surfaceContainerHigh: Color(0xffece6ec),
      surfaceContainerHighest: Color(0xffe7e1e7),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffd4bbff),
      surfaceTint: Color(0xffd4bbff),
      onPrimary: Color(0xff3a2461),
      primaryContainer: Color(0xff493471),
      onPrimaryContainer: Color(0xffdfccff),
      secondary: Color(0xfffcacf3),
      onSecondary: Color(0xff531553),
      secondaryContainer: Color(0xffa15c9d),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xffffb4a5),
      onTertiary: Color(0xff650b00),
      tertiaryContainer: Color(0xffc84b33),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff141317),
      onSurface: Color(0xffe7e1e7),
      onSurfaceVariant: Color(0xffcbc4d0),
      outline: Color(0xff958e9a),
      outlineVariant: Color(0xff49454f),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe7e1e7),
      inversePrimary: Color(0xff695392),
      primaryFixed: Color(0xffebdcff),
      onPrimaryFixed: Color(0xff240b4b),
      primaryFixedDim: Color(0xffd4bbff),
      onPrimaryFixedVariant: Color(0xff513b79),
      secondaryFixed: Color(0xffffd6f7),
      onSecondaryFixed: Color(0xff380039),
      secondaryFixedDim: Color(0xfffcacf3),
      onSecondaryFixedVariant: Color(0xff6d2d6c),
      tertiaryFixed: Color(0xffffdad3),
      onTertiaryFixed: Color(0xff3e0400),
      tertiaryFixedDim: Color(0xffffb4a5),
      onTertiaryFixedVariant: Color(0xff891d09),
      surfaceDim: Color(0xff141317),
      surfaceBright: Color(0xff3b383d),
      surfaceContainerLowest: Color(0xff0f0d12),
      surfaceContainerLow: Color(0xff1d1b1f),
      surfaceContainer: Color(0xff211f23),
      surfaceContainerHigh: Color(0xff2b292e),
      surfaceContainerHighest: Color(0xff363439),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffd7c0ff),
      surfaceTint: Color(0xffd4bbff),
      onPrimary: Color(0xff1f0445),
      primaryContainer: Color(0xff9d85c9),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xffffb1f6),
      onSecondary: Color(0xff2f0030),
      secondaryContainer: Color(0xffc177bb),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xffffbaac),
      onTertiary: Color(0xff350300),
      tertiaryContainer: Color(0xffee664b),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffbab1),
      onError: Color(0xff370001),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff141317),
      onSurface: Color(0xfffff9fe),
      onSurfaceVariant: Color(0xffd0c8d5),
      outline: Color(0xffa7a0ac),
      outlineVariant: Color(0xff87818c),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe7e1e7),
      inversePrimary: Color(0xff523c7a),
      primaryFixed: Color(0xffebdcff),
      onPrimaryFixed: Color(0xff19003f),
      primaryFixedDim: Color(0xffd4bbff),
      onPrimaryFixedVariant: Color(0xff402a67),
      secondaryFixed: Color(0xffffd6f7),
      onSecondaryFixed: Color(0xff260027),
      secondaryFixedDim: Color(0xfffcacf3),
      onSecondaryFixedVariant: Color(0xff5a1c5a),
      tertiaryFixed: Color(0xffffdad3),
      onTertiaryFixed: Color(0xff2b0200),
      tertiaryFixedDim: Color(0xffffb4a5),
      onTertiaryFixedVariant: Color(0xff6f0e00),
      surfaceDim: Color(0xff141317),
      surfaceBright: Color(0xff3b383d),
      surfaceContainerLowest: Color(0xff0f0d12),
      surfaceContainerLow: Color(0xff1d1b1f),
      surfaceContainer: Color(0xff211f23),
      surfaceContainerHigh: Color(0xff2b292e),
      surfaceContainerHighest: Color(0xff363439),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xfffff9fe),
      surfaceTint: Color(0xffd4bbff),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xffd7c0ff),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xfffff9fa),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffffb1f6),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xfffff9f8),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffffbaac),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xfffff9f9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffbab1),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff141317),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xfffff9fe),
      outline: Color(0xffd0c8d5),
      outlineVariant: Color(0xffd0c8d5),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe7e1e7),
      inversePrimary: Color(0xff331d5a),
      primaryFixed: Color(0xffefe2ff),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xffd7c0ff),
      onPrimaryFixedVariant: Color(0xff1f0445),
      secondaryFixed: Color(0xffffddf7),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffffb1f6),
      onSecondaryFixedVariant: Color(0xff2f0030),
      tertiaryFixed: Color(0xffffe0da),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xffffbaac),
      onTertiaryFixedVariant: Color(0xff350300),
      surfaceDim: Color(0xff141317),
      surfaceBright: Color(0xff3b383d),
      surfaceContainerLowest: Color(0xff0f0d12),
      surfaceContainerLow: Color(0xff1d1b1f),
      surfaceContainer: Color(0xff211f23),
      surfaceContainerHigh: Color(0xff2b292e),
      surfaceContainerHighest: Color(0xff363439),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }

  ThemeData theme(ColorScheme colorScheme) => ThemeData(
        useMaterial3: true,
        brightness: colorScheme.brightness,
        colorScheme: colorScheme,
        textTheme: textTheme.apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        ),
        scaffoldBackgroundColor: colorScheme.surface,
        canvasColor: colorScheme.surface,
      );

  List<ExtendedColor> get extendedColors => [];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
