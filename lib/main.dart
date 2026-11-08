import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'device.dart';
import 'storage.dart';
import 'ui/home_page.dart';
import 'ui/login_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await Storage.init();
  await Device.init();
  // Sur Android, Flutter suppose un écran tactile et masque le surlignage de l'élément choisi :
  // à la télécommande, il doit toujours être visible.
  if (Device.isTv) FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  final state = AppState();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: state.player),
      ],
      child: const ElioApp(),
    ),
  );
}

class ElioApp extends StatelessWidget {
  const ElioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ElioTV',
      debugShowCheckedModeBanner: false,
      theme: elioTheme(),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatelessWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final error = state.error;
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || state.error == null) return;
        state.clearError();
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Oups'),
            content: Text(error),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }
    if (state.active == null) return const LoginPage();
    if (state.catalog.items.isEmpty && state.isLoading)
      return LoadingPage(message: state.loadingMessage);
    return const HomePage();
  }
}
