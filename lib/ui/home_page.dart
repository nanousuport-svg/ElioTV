import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../country.dart';
import '../device.dart';
import '../models.dart';
import '../player.dart';
import 'player_view.dart';
import 'theme.dart';

/// Écran principal. Large (ordinateur, tablette, TV) : catégories | liste | lecteur.
/// Étroit (téléphone) : liste avec filtres en haut et onglets TV / Films / Séries en bas.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) return const _WideLayout();
        return const _NarrowLayout();
      },
    );
  }
}

/// Que faire quand on choisit un élément : sur ordinateur la vidéo se lance à droite,
/// sur téléphone et TV elle s'ouvre directement en plein écran.
void activateItem(BuildContext context, MediaItem item) {
  final state = context.read<AppState>();
  final inline =
      Device.isDesktop ||
      (MediaQuery.sizeOf(context).width >= 900 && !Device.isTv);
  final alreadyPlaying =
      state.selectedItem?.id == item.id && item.streamUrl != null;
  if (!alreadyPlaying) state.select(item);
  if (item.streamUrl == null) {
    if (!inline)
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const SeriesPage()));
  } else if (!inline || alreadyPlaying) {
    openFullscreen(context);
  }
}

// MARK: - Grand écran

class _WideLayout extends StatelessWidget {
  const _WideLayout();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 270,
              child: FocusTraversalGroup(child: const _Sidebar()),
            ),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 380,
              child: FocusTraversalGroup(child: const _ItemList()),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: FocusTraversalGroup(child: _Detail())),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Column(
      children: [
        if (state.availableKinds.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SegmentedButton<ContentKind>(
              segments: [
                for (final k in state.availableKinds)
                  ButtonSegment(value: k, label: Text(k.shortTitle)),
              ],
              selected: {state.kind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => state.kind = s.first,
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: FilterMenus(vertical: true),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              _CategoryTile(
                id: AppState.allId,
                icon: Icons.grid_view_rounded,
                title: 'Tout',
                count: state.totalCount,
              ),
              const _CategoryTile(
                id: AppState.favoritesId,
                icon: Icons.star_rounded,
                title: 'Favoris',
              ),
              const _CategoryTile(
                id: AppState.recentsId,
                icon: Icons.history_rounded,
                title: 'Récents',
              ),
              if (state.categories.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 14, 0, 6),
                  child: Text(
                    'CATÉGORIES',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              for (final c in state.categories)
                _CategoryTile(
                  id: c.id,
                  title: state.displayName(c),
                  count: state.counts[c.id],
                ),
            ],
          ),
        ),
        const _ProfileFooter(),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.id,
    required this.title,
    this.icon,
    this.count,
  });
  final String id;
  final String title;
  final IconData? icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListTile(
      focusColor: Brand.focus,
      dense: true,
      selected: state.category == id,
      leading: icon == null ? null : Icon(icon, size: 20),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: count == null
          ? null
          : Text(
              '$count',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
      onTap: () => state.category = id,
    );
  }
}

class _ProfileFooter extends StatelessWidget {
  const _ProfileFooter();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final expires = state.account?.expires;
    return Container(
      color: Colors.white.withValues(alpha: 0.04),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          const BrandLogo(size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.active?.name ?? '',
                  maxLines: 1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  expires != null
                      ? "Abonnement jusqu'au ${expires.day}/${expires.month}/${expires.year}"
                      : '${state.catalog.items.length} contenus',
                  maxLines: 1,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const _ProviderMenu(),
        ],
      ),
    );
  }
}

class _ProviderMenu extends StatelessWidget {
  const _ProviderMenu();

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return PopupMenuButton<int>(
      tooltip: 'Options',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (v) => v == 0 ? state.refresh() : state.signOut(),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 0, child: Text('Actualiser la liste')),
        PopupMenuItem(value: 1, child: Text('Changer de fournisseur')),
      ],
    );
  }
}

/// Menus Pays / Genre / Année / Tri, partagés par les deux mises en page.
class FilterMenus extends StatelessWidget {
  const FilterMenus({super.key, required this.vertical});
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final menus = <Widget>[
      if (state.countries.isNotEmpty)
        _Dropdown<String?>(
          value: state.country,
          items: [
            (null, '🌐 Tous les pays'),
            for (final (code, count) in state.countries)
              (code, '${Country.label(code)}  ($count)'),
          ],
          onChanged: (v) => state.country = v,
        ),
      if (state.genreOptions.isNotEmpty)
        _Dropdown<String?>(
          value: state.genre,
          items: [
            (null, '🎭 Tous les genres'),
            for (final (g, count) in state.genreOptions) (g, '$g  ($count)'),
          ],
          onChanged: (v) => state.genre = v,
        ),
      if (state.yearOptions.isNotEmpty)
        _Dropdown<YearFilter?>(
          value: state.yearFilter,
          items: [
            (null, '📅 Toutes les années'),
            for (final y in state.yearOptions) (y, y.label),
          ],
          onChanged: (v) => state.yearFilter = v,
        ),
      if (state.kind != ContentKind.live)
        _Dropdown<SortOrder>(
          value: state.sortOrder,
          items: [for (final s in SortOrder.values) (s, '⇅ ${s.title}')],
          onChanged: (v) => state.sortOrder = v ?? SortOrder.yearDesc,
        ),
    ];
    if (vertical) {
      return Column(
        children: [
          for (final m in menus)
            Padding(padding: const EdgeInsets.only(top: 6), child: m),
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final m in menus)
            Padding(padding: const EdgeInsets.only(right: 8), child: m),
        ],
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        isExpanded: false,
        underline: const SizedBox(),
        borderRadius: BorderRadius.circular(12),
        menuMaxHeight: 480,
        padding: const EdgeInsets.symmetric(vertical: 8),
        items: [
          for (final (v, label) in items)
            DropdownMenuItem<T>(
              value: v,
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _ItemList extends StatefulWidget {
  const _ItemList();

  @override
  State<_ItemList> createState() => _ItemListState();
}

class _ItemListState extends State<_ItemList> {
  final search = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (search.text != state.search) search.text = state.search;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  onChanged: (v) => state.search = v,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Rechercher…',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualiser',
                onPressed: state.isRefreshing ? null : state.refresh,
                icon: state.isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${state.visible.length} ${state.kind == ContentKind.live ? 'chaînes' : 'titres'}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ),
        const Expanded(child: ItemListView()),
      ],
    );
  }
}

class ItemListView extends StatelessWidget {
  const ItemListView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.visible.isEmpty) return const _EmptyState();
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: state.visible.length,
      itemExtent: 64,
      // À la télécommande, il faut toujours un élément sélectionné, sinon les flèches ne font rien.
      itemBuilder: (context, i) =>
          ItemTile(item: state.visible[i], autofocus: Device.isTv && i == 0),
    );
  }
}

class ItemTile extends StatelessWidget {
  const ItemTile({super.key, required this.item, this.autofocus = false});
  final MediaItem item;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final selected = context.select<AppState, bool>(
      (s) => s.selectedItem?.id == item.id,
    );
    final favorite = context.select<AppState, bool>(
      (s) => s.favorites.contains(item.id),
    );
    final live = item.kind == ContentKind.live;
    return ListTile(
      focusColor: Brand.focus,
      autofocus: autofocus,
      selected: selected,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: live ? 52 : 36,
          height: live ? 34 : 50,
          color: Colors.white.withValues(alpha: 0.06),
          child: RemoteImage(
            item.logo,
            icon: live ? Icons.tv_rounded : Icons.movie_outlined,
            fit: live ? BoxFit.contain : BoxFit.cover,
          ),
        ),
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: _subtitle(),
      trailing: favorite
          ? const Icon(Icons.star_rounded, color: Colors.amber, size: 18)
          : null,
      onTap: () => activateItem(context, item),
      onLongPress: () => state.toggleFavorite(item),
    );
  }

  Widget? _subtitle() {
    if (item.kind == ContentKind.live) {
      return item.number == null
          ? null
          : Text(
              '${item.number}',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            );
    }
    final parts = [
      if (item.year != null) '${item.year}',
      if (item.rating != null)
        '★ ${item.rating!.toStringAsFixed(item.rating! % 1 == 0 ? 0 : 1)}',
      if (item.genres.isNotEmpty) item.genres.take(2).join(', '),
    ];
    return parts.isEmpty
        ? null
        : Text(
            parts.join(' · '),
            maxLines: 1,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final (icon, title, text) = state.isRefreshing
        ? (Icons.hourglass_top_rounded, 'Chargement…', '')
        : state.search.isNotEmpty
        ? (
            Icons.search_off_rounded,
            'Aucun résultat',
            'pour « ${state.search} »',
          )
        : (state.genre != null || state.yearFilter != null)
        ? (
            Icons.filter_alt_off_rounded,
            'Aucun titre avec ces filtres',
            'Essaie un autre genre ou une autre année.',
          )
        : state.category == AppState.favoritesId
        ? (
            Icons.star_outline_rounded,
            'Aucun favori',
            'Appui long sur une chaîne pour l\'ajouter.',
          )
        : state.category == AppState.recentsId
        ? (
            Icons.history_rounded,
            "Rien pour l'instant",
            'Ce que tu regardes apparaîtra ici.',
          )
        : (Icons.tv_off_rounded, 'Liste vide', '');
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Colors.white30),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          if (text.isNotEmpty)
            Text(text, style: const TextStyle(color: Colors.white54)),
          if (state.genre != null || state.yearFilter != null)
            TextButton(
              onPressed: state.clearFilters,
              child: const Text('Effacer les filtres'),
            ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final item = context.select<AppState, MediaItem?>((s) => s.selectedItem);
    if (item == null) return const _Welcome();
    if (item.streamUrl == null) return const SeriesView();
    return Column(
      children: [
        const Expanded(child: PlayerSurface(fullscreen: false)),
        NowPlayingBar(item: item),
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    return BrandBackground(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(size: 64),
              const SizedBox(height: 16),
              const Text(
                'Choisis une chaîne',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              for (final (icon, text) in [
                (
                  Icons.swap_vert_rounded,
                  Device.isTv
                      ? 'Flèches ↑ ↓ pour parcourir, OK pour regarder'
                      : 'Clique sur une chaîne pour la regarder',
                ),
                (
                  Icons.fullscreen_rounded,
                  'Plein écran : ↑ ↓ pour zapper, ← → pour avancer/reculer',
                ),
                (
                  Icons.star_outline_rounded,
                  'Appui long sur une chaîne : favori',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: Colors.white54),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          text,
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({super.key, required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.watch<PlayerController>();
    final now = state.epg.firstOrNull;
    final info = p.mediaInfo;
    return Container(
      color: Colors.white.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 66,
              height: 44,
              color: Colors.white.withValues(alpha: 0.06),
              child: RemoteImage(item.logo, icon: Icons.tv_rounded),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (info != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          info,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                if (now != null) ...[
                  Text(
                    '${_hm(now.start)}–${_hm(now.end)}  ${now.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 260,
                    child: LinearProgressIndicator(
                      value: now.progress(DateTime.now()),
                      color: Brand.pink,
                      minHeight: 3,
                    ),
                  ),
                  if (state.epg.length > 1)
                    Text(
                      'Ensuite : ${state.epg[1].title}',
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                ] else
                  Text(
                    state.categoryName(item.categoryId) ?? item.kind.title,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Favori',
            icon: Icon(
              state.isFavorite(item)
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: state.isFavorite(item) ? Colors.amber : null,
            ),
            onPressed: () => state.toggleFavorite(item),
          ),
          IconButton(
            tooltip: 'Plein écran',
            icon: const Icon(Icons.fullscreen_rounded),
            onPressed: () => openFullscreen(context),
          ),
        ],
      ),
    );
  }

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// MARK: - Séries

class SeriesView extends StatefulWidget {
  const SeriesView({super.key});

  @override
  State<SeriesView> createState() => _SeriesViewState();
}

class _SeriesViewState extends State<SeriesView> {
  int? season;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final item = state.selectedItem;
    final series = state.series;
    if (item == null) return const SizedBox();
    final seasons = series?.seasons ?? [];
    final current = (season != null && seasons.contains(season))
        ? season
        : seasons.firstOrNull;
    final inline =
        Device.isDesktop ||
        (MediaQuery.sizeOf(context).width >= 900 && !Device.isTv);
    return Column(
      children: [
        if (inline && state.playingEpisodeId != null)
          const SizedBox(height: 360, child: PlayerSurface(fullscreen: false))
        else
          BrandBackground(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 110,
                      height: 160,
                      child: RemoteImage(
                        series?.cover ?? item.logo,
                        icon: Icons.movie_outlined,
                        fit: BoxFit.cover,
                        cacheWidth: 300,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (series?.plot != null)
                          Text(
                            series!.plot!,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (seasons.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _Dropdown<int?>(
                value: current,
                items: [for (final s in seasons) (s, 'Saison $s')],
                onChanged: (v) => setState(() => season = v),
              ),
            ),
          ),
        Expanded(
          child: state.isLoadingSeries
              ? const Center(child: CircularProgressIndicator())
              : (series == null || series.episodes.isEmpty)
              ? const Center(
                  child: Text(
                    'Aucun épisode',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    for (final (i, e)
                        in series.episodes
                            .where((e) => e.season == current)
                            .indexed)
                      ListTile(
                        focusColor: Brand.focus,
                        autofocus: i == 0 && Device.isTv,
                        selected: state.playingEpisodeId == e.id,
                        leading: Icon(
                          state.playingEpisodeId == e.id
                              ? Icons.play_circle_rounded
                              : Icons.play_circle_outline_rounded,
                          color: state.playingEpisodeId == e.id
                              ? Brand.pink
                              : null,
                        ),
                        title: Text(
                          '${e.number}. ${e.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: e.plot == null
                            ? null
                            : Text(
                                e.plot!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                        trailing: e.duration == null
                            ? null
                            : Text(
                                e.duration!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white54,
                                ),
                              ),
                        onTap: () {
                          state.playEpisode(e);
                          if (!inline) openFullscreen(context);
                        },
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class SeriesPage extends StatelessWidget {
  const SeriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final name = context.select<AppState, String>(
      (s) => s.selectedItem?.name ?? '',
    );
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: const SeriesView(),
    );
  }
}

// MARK: - Téléphone

class _NarrowLayout extends StatefulWidget {
  const _NarrowLayout();

  @override
  State<_NarrowLayout> createState() => _NarrowLayoutState();
}

class _NarrowLayoutState extends State<_NarrowLayout> {
  bool searching = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categoryTitle = switch (state.category) {
      AppState.allId => state.kind.title,
      AppState.favoritesId => 'Favoris',
      AppState.recentsId => 'Récents',
      final id => state.categoryName(id) ?? state.kind.title,
    };
    return Scaffold(
      appBar: AppBar(
        title: searching
            ? TextField(
                autofocus: true,
                onChanged: (v) => state.search = v,
                decoration: const InputDecoration(
                  hintText: 'Rechercher…',
                  filled: false,
                  border: InputBorder.none,
                ),
              )
            : InkWell(
                onTap: () => _pickCategory(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        categoryTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded),
                  ],
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(searching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              if (searching) state.search = '';
              setState(() => searching = !searching);
            },
          ),
          const _ProviderMenu(),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 4),
          const FilterMenus(vertical: false),
          Expanded(
            child: RefreshIndicator(
              onRefresh: state.refresh,
              child: const ItemListView(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: state.availableKinds.length > 1
          ? NavigationBar(
              selectedIndex: state.availableKinds
                  .indexOf(state.kind)
                  .clamp(0, state.availableKinds.length - 1),
              onDestinationSelected: (i) =>
                  state.kind = state.availableKinds[i],
              destinations: [
                for (final k in state.availableKinds)
                  NavigationDestination(
                    icon: Icon(switch (k) {
                      ContentKind.live => Icons.live_tv_rounded,
                      ContentKind.movie => Icons.movie_rounded,
                      ContentKind.series => Icons.video_library_rounded,
                    }),
                    label: k.shortTitle,
                  ),
              ],
            )
          : null,
    );
  }

  void _pickCategory(BuildContext context) {
    final state = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            for (final (id, title) in [
              (AppState.allId, 'Tout'),
              (AppState.favoritesId, '⭐ Favoris'),
              (AppState.recentsId, '🕘 Récents'),
              for (final c in state.categories) (c.id, state.displayName(c)),
            ])
              ListTile(
                focusColor: Brand.focus,
                selected: state.category == id,
                title: Text(title),
                trailing: state.counts[id] == null
                    ? null
                    : Text('${state.counts[id]}'),
                onTap: () {
                  state.category = id;
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}
