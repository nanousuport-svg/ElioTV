import 'package:flutter/material.dart';

import '../net.dart';

class Brand {
  static const violet = Color(0xFF5C45FA);
  static const pink = Color(0xFFED409E);
  static const background = Color(0xFF0D0D17);
  static const surface = Color(0xFF16162A);

  /// Fond de l'élément sélectionné à la télécommande ou au clavier : bien visible de loin.
  static const focus = Color(0xAA5C45FA);
  static const gradient = LinearGradient(
    colors: [violet, pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData elioTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Brand.violet,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF8F7DFF),
        secondary: Brand.pink,
        surface: Brand.surface,
      );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Brand.background,
    useMaterial3: true,
    // Halo bien visible sur l'élément sélectionné : indispensable à la télécommande.
    focusColor: Brand.violet.withValues(alpha: 0.45),
    listTileTheme: ListTileThemeData(
      selectedTileColor: Brand.violet.withValues(alpha: 0.25),
      selectedColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Brand.violet, width: 2),
      ),
    ),
  );
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: Brand.gradient,
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(
            color: Brand.violet.withValues(alpha: 0.5),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: size * 0.62,
      ),
    );
  }
}

class BrandBackground extends StatelessWidget {
  const BrandBackground({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-1, -1),
          radius: 1.6,
          colors: [Color(0x595C45FA), Brand.background],
        ),
      ),
      child: child,
    );
  }
}

/// Logo de chaîne ou affiche, avec un pictogramme tant qu'il n'est pas chargé.
class RemoteImage extends StatelessWidget {
  const RemoteImage(
    this.url, {
    super.key,
    required this.icon,
    this.fit = BoxFit.contain,
    this.cacheWidth = 160,
  });
  final String? url;
  final IconData icon;
  final BoxFit fit;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final placeholder = Center(
      child: Icon(icon, color: Colors.white24, size: 18),
    );
    if (url == null) return placeholder;
    return Image.network(
      url!,
      headers: httpHeaders,
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => placeholder,
      frameBuilder: (_, child, frame, sync) =>
          frame == null && !sync ? placeholder : child,
    );
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BrandBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(size: 72),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 17),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
