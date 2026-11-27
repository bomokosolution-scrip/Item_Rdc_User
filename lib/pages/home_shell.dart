import 'package:item_rdc/pages/chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:item_rdc/core/app_theme.dart';
import 'package:item_rdc/core/user_session.dart';
import 'package:item_rdc/pages/documents_tab.dart';
import 'package:item_rdc/pages/library_page.dart';
import 'package:item_rdc/pages/premium_tab.dart';
import 'package:item_rdc/pages/videos_tab.dart';
import 'package:item_rdc/widgets/app_dialog.dart';
import 'package:item_rdc/widgets/app_drawer.dart';
import 'package:item_rdc/widgets/bottom_nav.dart';
import 'package:item_rdc/widgets/theme_toggle.dart';
import 'package:item_rdc/widgets/ui.dart';
import 'package:item_rdc/widgets/user_avatar.dart';
import 'package:provider/provider.dart';

/// Écran principal : menu latéral + barre de navigation + 4 onglets.
///
/// Les onglets sont créés à la première visite puis conservés (état, défilement
/// et flux de données gardés) : le changement d'onglet est instantané.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  static const _items = [
    NavItem(Icons.folder_copy_outlined, Icons.folder_copy_rounded, "Documents"),
    NavItem(Icons.play_circle_outline_rounded, Icons.play_circle_fill_rounded, "Vidéos"),
    NavItem(Icons.local_library_outlined, Icons.local_library_rounded, "Bibliothèque"),
    NavItem(Icons.workspace_premium_outlined, Icons.workspace_premium_rounded, "Premium"),
    NavItem(Icons.forum_outlined, Icons.forum_rounded, "Discussion"),
  ];

  static const _titles = ["Documents", "Vidéos", "Bibliothèque", "Mon abonnement", "Discussion"];

  int _index = 0;
  int _generation = 0;
  final List<bool> _visited = [true, false, false, false, false];

  @override
  void initState() {
    super.initState();
    // Préchauffage : une fois l'accueil affiché, les autres onglets se
    // préparent en arrière-plan (un par un) => changement d'onglet instantané,
    // icônes déjà chargées.
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmUp());
  }

  Future<void> _warmUp() async {
    for (int i = 1; i < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      if (!_visited[i]) setState(() => _visited[i] = true);
    }
  }

  /// Permet aux onglets (ex. bannière Premium) de changer d'onglet.
  void goTo(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      _visited[index] = true;
    });
  }

  /// Recrée les flux de données de tous les onglets (bouton "Synchroniser").
  void refresh() {
    setState(() => _generation++);
    showToast(context, "Données synchronisées");
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _tab(int i) {
    switch (i) {
      case 0:
        return const DocumentsTab();
      case 1:
        return const VideosTab();
      case 2:
        return const LibraryTab();
      case 4:
        return const ChatPage();
      default:
        return const PremiumTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.select<UserSession, bool>((s) => s.isPremium);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_index != 0) {
          goTo(0);
          return;
        }
        // Onglet principal : on demande confirmation avant de quitter.
        final quit = await confirmExit(context);
        if (quit) SystemNavigator.pop();
      },
      child: Scaffold(
        extendBody: true,
        drawer: AppDrawer(
          currentTab: _index,
          onSelectTab: goTo,
          onRefresh: refresh,
        ),
        appBar: AppBar(
          // Menu (3 barres) + bouton clair/sombre, juste avant le titre.
          leadingWidth: 100,
          titleSpacing: 4,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(
                builder: (ctx) => IconButton(
                  tooltip: "Menu",
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              const ThemeToggleButton(),
            ],
          ),
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(_titles[_index], key: ValueKey(_index)),
          ),
          actions: [
            if (premium)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.workspace_premium_rounded, color: AppColors.gold),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => goTo(3),
                child: const UserAvatar(radius: 15),
              ),
            ),
          ],
        ),
        body: IndexedStack(
            index: _index,
            children: [
              for (int i = 0; i < 5; i++)
                TickerMode(
                  enabled: i == _index,
                  child: _visited[i]
                      ? KeyedSubtree(
                          key: ValueKey('tab_${i}_$_generation'),
                          child: _tab(i),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
        ),
        bottomNavigationBar: AnimatedBottomNav(
          currentIndex: _index,
          items: _items,
          onTap: goTo,
        ),
      ),
    );
  }
}
