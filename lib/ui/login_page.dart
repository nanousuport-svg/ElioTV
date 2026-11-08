import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import 'theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

enum _Mode { xtream, link, file }

class _LoginPageState extends State<LoginPage> {
  _Mode mode = _Mode.xtream;
  final server = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  final link = TextEditingController();
  final name = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: FocusTraversalGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandLogo(size: 76)),
                      const SizedBox(height: 14),
                      const Text(
                        'ElioTV',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Ta télé, simplement.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 17),
                      ),
                      const SizedBox(height: 28),
                      if (state.profiles.isNotEmpty) ..._savedProfiles(state),
                      _form(state),
                      const SizedBox(height: 20),
                      const Text(
                        'ElioTV est un lecteur : il ne fournit aucune chaîne. Il lit les accès fournis par ton fournisseur IPTV.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _savedProfiles(AppState state) => [
    const _SectionTitle('MES FOURNISSEURS'),
    for (final (i, profile) in state.profiles.indexed)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            focusColor: Brand.focus,
            autofocus: i == 0,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: Brand.gradient,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(switch (profile.type) {
                SourceType.xtream => Icons.dns_rounded,
                SourceType.m3uUrl => Icons.link_rounded,
                SourceType.m3uFile => Icons.description_rounded,
              }, size: 20),
            ),
            title: Text(
              profile.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              profile.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(state, profile),
            ),
            onTap: () => state.open(profile),
          ),
        ),
      ),
    const SizedBox(height: 18),
  ];

  Future<void> _confirmDelete(AppState state, Profile profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer « ${profile.name} » ?'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) state.deleteProfile(profile);
  }

  Widget _form(AppState state) {
    final canSubmit = switch (mode) {
      _Mode.xtream =>
        server.text.isNotEmpty &&
            username.text.isNotEmpty &&
            password.text.isNotEmpty,
      _Mode.link => link.text.isNotEmpty,
      _Mode.file => true,
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            state.profiles.isEmpty
                ? 'CONNECTE TON FOURNISSEUR'
                : 'AJOUTER UN FOURNISSEUR',
          ),
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(value: _Mode.xtream, label: Text('Xtream')),
              ButtonSegment(value: _Mode.link, label: Text('Lien M3U')),
              ButtonSegment(value: _Mode.file, label: Text('Fichier')),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => mode = s.first),
          ),
          const SizedBox(height: 14),
          ...switch (mode) {
            _Mode.xtream => [
              _field(
                server,
                Icons.language,
                'Adresse du serveur (ex. http://serveur.com:8080)',
                keyboard: TextInputType.url,
              ),
              _field(username, Icons.person_outline, "Nom d'utilisateur"),
              _field(
                password,
                Icons.lock_outline,
                'Mot de passe',
                secure: true,
              ),
              _field(name, Icons.label_outline, 'Nom à afficher (facultatif)'),
            ],
            _Mode.link => [
              _field(
                link,
                Icons.link,
                'https://…/playlist.m3u',
                keyboard: TextInputType.url,
              ),
              _field(name, Icons.label_outline, 'Nom à afficher (facultatif)'),
            ],
            _Mode.file => [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Choisis le fichier .m3u envoyé par ton fournisseur.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          },
          const SizedBox(height: 4),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: canSubmit ? Brand.gradient : null,
              color: canSubmit ? null : Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: canSubmit && !state.isLoading
                  ? () => _submit(state)
                  : null,
              child: state.isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(state.loadingMessage),
                      ],
                    )
                  : Text(
                      mode == _Mode.file
                          ? 'Choisir un fichier…'
                          : 'Se connecter',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    IconData icon,
    String hint, {
    bool secure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        obscureText: secure,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: keyboard,
        textInputAction: TextInputAction.next,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20),
          hintText: hint,
        ),
      ),
    );
  }

  Future<void> _submit(AppState state) async {
    switch (mode) {
      case _Mode.xtream:
        await state.connectXtream(
          server.text,
          username.text,
          password.text,
          name.text.trim(),
        );
      case _Mode.link:
        await state.connectM3U(link.text, name.text.trim());
      case _Mode.file:
        final files = await FilePicker.pickFiles(
          dialogTitle: 'Choisis ta playlist M3U',
        );
        final path = files.firstOrNull?.path;
        if (path != null) await state.connectM3UFile(path);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 2),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
