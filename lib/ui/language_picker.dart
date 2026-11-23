import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../country.dart';

/// Libellé court du choix actuel : « 🌐 Toutes les langues », « 🇫🇷 France », « 🇫🇷 🇧🇪 🇨🇭 ».
String languagesLabel(Set<String> languages) {
  if (languages.isEmpty) return '🌐 Toutes les langues';
  final codes = languages.toList()..sort();
  if (codes.length == 1) return Country.label(codes.first);
  if (codes.length <= 4) return codes.map(Country.flag).join(' ');
  return '🌐 ${codes.length} langues';
}

/// Choix des langues affichées : seules les chaînes, films et séries des langues cochées restent
/// visibles, dans toutes les rubriques. Rien de coché = tout afficher.
Future<void> showLanguagePicker(BuildContext context) async {
  final state = context.read<AppState>();
  final selected = {...state.languages};
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Mes langues'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Coche les langues que tu regardes : tout le reste sera masqué '
                '(TV, films et séries). Tu peux changer ce choix à tout moment.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (i, (code, count))
                        in state.languageOptions.indexed)
                      CheckboxListTile(
                        autofocus: i == 0,
                        dense: true,
                        value: selected.contains(code),
                        title: Text(Country.label(code)),
                        subtitle: Text(
                          count > 1 ? '$count contenus' : '$count contenu',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        onChanged: (on) => setState(
                          () => on == true
                              ? selected.add(code)
                              : selected.remove(code),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              selected.clear();
              Navigator.pop(context, true);
            },
            child: const Text('Tout afficher'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              selected.isEmpty
                  ? 'Valider'
                  : 'Valider (${selected.length})',
            ),
          ),
        ],
      ),
    ),
  );
  // Fermé sans valider : on garde le choix actuel, mais on ne redemandera plus.
  state.languages = saved == true ? selected : state.languages;
}

/// Bouton des filtres : montre les langues choisies et ouvre le choix.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Material(
      color: state.languages.isEmpty
          ? Colors.white.withValues(alpha: 0.06)
          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showLanguagePicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  languagesLabel(state.languages),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.tune_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Propose une fois le choix des langues quand un fournisseur en offre plusieurs.
class LanguagePrompt extends StatefulWidget {
  const LanguagePrompt({super.key, required this.child});
  final Widget child;

  @override
  State<LanguagePrompt> createState() => _LanguagePromptState();
}

class _LanguagePromptState extends State<LanguagePrompt> {
  bool _asking = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Attendre la liste complète (films et séries compris) pour proposer toutes les langues.
    if (!_asking && !state.isRefreshing && state.shouldAskLanguages) {
      _asking = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showLanguagePicker(context);
        _asking = false;
      });
    }
    return widget.child;
  }
}
