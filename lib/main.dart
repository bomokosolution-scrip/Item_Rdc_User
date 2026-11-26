import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/catalog_store.dart';
import 'package:item_rdc/core/user_session.dart';
import 'package:item_rdc/core/view_mode.dart';
import 'package:item_rdc/firebase_config.dart';
import 'package:item_rdc/pages/app_root.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initFirebase();

  await initializeDateFormatting('fr_FR');

  final themeManager = ThemeManager();
  await themeManager.load();
  await ViewModeStore.instance.load();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeManager>.value(value: themeManager),
        // `lazy: false` : la session (et le préchargement des documents) démarre
        // dès l'ouverture, pendant l'écran Lottie, et non après lui.
        ChangeNotifierProvider<UserSession>(
          lazy: false,
          create: (_) {
            final session = UserSession();
            CatalogStore.instance.bind(session);
            return session;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<ThemeManager, ThemeMode>((t) => t.themeMode);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Item RDC',
      debugShowCheckedModeBanner: false,
      theme: ThemeManager.lightTheme,
      darkTheme: ThemeManager.darkTheme,
      themeMode: mode,
      // Adapté à chaque téléphone : l'échelle du texte reste dans une plage
      // raisonnable pour éviter les débordements.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child!,
        );
      },
      home: const AppRoot(),
    );
  }
}
