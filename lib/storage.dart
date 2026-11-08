import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Fournisseurs enregistrés, mots de passe et copie locale des listes
/// (l'app s'ouvre instantanément sur la dernière liste).
class Storage {
  static late Directory _dir;
  static late SharedPreferences prefs;

  static Future<void> init() async {
    _dir = await getApplicationSupportDirectory();
    await _dir.create(recursive: true);
    prefs = await SharedPreferences.getInstance();
  }

  static File get _profilesFile => File('${_dir.path}/profiles.json');

  /// Fichier privé de l'app (dossier propre à l'app sur chaque système).
  static File get _credentialsFile => File('${_dir.path}/credentials.json');
  static File _catalogFile(String id) => File('${_dir.path}/catalog_$id.json');

  static List<Profile> loadProfiles() {
    try {
      final list = jsonDecode(_profilesFile.readAsStringSync()) as List;
      return list.map((p) => Profile.fromJson(p)).toList();
    } catch (_) {
      return [];
    }
  }

  static void saveProfiles(List<Profile> profiles) => _profilesFile
      .writeAsStringSync(jsonEncode(profiles.map((p) => p.toJson()).toList()));

  static Map<String, dynamic> _credentials() {
    try {
      return jsonDecode(_credentialsFile.readAsStringSync())
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static String? password(String profileId) =>
      _credentials()[profileId] as String?;

  static void setPassword(String profileId, String? value) {
    final all = _credentials();
    if (value == null) {
      all.remove(profileId);
    } else {
      all[profileId] = value;
    }
    _credentialsFile.writeAsStringSync(jsonEncode(all));
    if (!Platform.isWindows)
      Process.runSync('chmod', ['600', _credentialsFile.path]);
  }

  /// Décodage hors du fil principal : une liste de 100 000 titres ne fige pas l'écran.
  static Future<Catalog?> loadCatalog(String id) async {
    final path = _catalogFile(id).path;
    return Isolate.run(() {
      try {
        return Catalog.fromJson(
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
        );
      } catch (_) {
        return null;
      }
    });
  }

  static Future<void> saveCatalog(String id, Catalog catalog) async {
    final path = _catalogFile(id).path;
    await Isolate.run(
      () => File(path).writeAsStringSync(jsonEncode(catalog.toJson())),
    );
  }

  static void deleteCatalog(String id) {
    try {
      _catalogFile(id).deleteSync();
    } catch (_) {}
  }
}
