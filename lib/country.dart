import 'genre.dart' show words;

/// Devine le pays d'une catégorie : « FR | Sport », « |UK| News », « [DE] Kino », « FRANCE - Cinéma »,
/// « 🇮🇹 Calcio », ou n'importe où pour la VOD : « Movies French », « Series Greece ».
class Country {
  static const other = '__other';

  /// code ISO → (nom français, nom anglais). Liste des pays courants dans les offres IPTV.
  static const _names = {
    'AF': ('Afghanistan', 'Afghanistan'),
    'AL': ('Albanie', 'Albania'),
    'DZ': ('Algérie', 'Algeria'),
    'DE': ('Allemagne', 'Germany'),
    'AO': ('Angola', 'Angola'),
    'SA': ('Arabie saoudite', 'Saudi Arabia'),
    'AR': ('Argentine', 'Argentina'),
    'AM': ('Arménie', 'Armenia'),
    'AU': ('Australie', 'Australia'),
    'AT': ('Autriche', 'Austria'),
    'AZ': ('Azerbaïdjan', 'Azerbaijan'),
    'BH': ('Bahreïn', 'Bahrain'),
    'BD': ('Bangladesh', 'Bangladesh'),
    'BE': ('Belgique', 'Belgium'),
    'BJ': ('Bénin', 'Benin'),
    'BA': ('Bosnie', 'Bosnia'),
    'BR': ('Brésil', 'Brazil'),
    'BG': ('Bulgarie', 'Bulgaria'),
    'BF': ('Burkina Faso', 'Burkina Faso'),
    'CM': ('Cameroun', 'Cameroon'),
    'CA': ('Canada', 'Canada'),
    'CL': ('Chili', 'Chile'),
    'CN': ('Chine', 'China'),
    'CY': ('Chypre', 'Cyprus'),
    'CO': ('Colombie', 'Colombia'),
    'KR': ('Corée du Sud', 'South Korea'),
    'CI': ("Côte d'Ivoire", 'Ivory Coast'),
    'HR': ('Croatie', 'Croatia'),
    'CU': ('Cuba', 'Cuba'),
    'DK': ('Danemark', 'Denmark'),
    'EG': ('Égypte', 'Egypt'),
    'AE': ('Émirats arabes unis', 'United Arab Emirates'),
    'EC': ('Équateur', 'Ecuador'),
    'ES': ('Espagne', 'Spain'),
    'EE': ('Estonie', 'Estonia'),
    'US': ('États-Unis', 'United States'),
    'ET': ('Éthiopie', 'Ethiopia'),
    'FI': ('Finlande', 'Finland'),
    'FR': ('France', 'France'),
    'GA': ('Gabon', 'Gabon'),
    'GE': ('Géorgie', 'Georgia'),
    'GH': ('Ghana', 'Ghana'),
    'GR': ('Grèce', 'Greece'),
    'GN': ('Guinée', 'Guinea'),
    'HT': ('Haïti', 'Haiti'),
    'HU': ('Hongrie', 'Hungary'),
    'IN': ('Inde', 'India'),
    'ID': ('Indonésie', 'Indonesia'),
    'IQ': ('Irak', 'Iraq'),
    'IR': ('Iran', 'Iran'),
    'IE': ('Irlande', 'Ireland'),
    'IS': ('Islande', 'Iceland'),
    'IL': ('Israël', 'Israel'),
    'IT': ('Italie', 'Italy'),
    'JP': ('Japon', 'Japan'),
    'JO': ('Jordanie', 'Jordan'),
    'KZ': ('Kazakhstan', 'Kazakhstan'),
    'KE': ('Kenya', 'Kenya'),
    'KW': ('Koweït', 'Kuwait'),
    'LV': ('Lettonie', 'Latvia'),
    'LB': ('Liban', 'Lebanon'),
    'LY': ('Libye', 'Libya'),
    'LT': ('Lituanie', 'Lithuania'),
    'LU': ('Luxembourg', 'Luxembourg'),
    'MK': ('Macédoine du Nord', 'North Macedonia'),
    'MY': ('Malaisie', 'Malaysia'),
    'ML': ('Mali', 'Mali'),
    'MT': ('Malte', 'Malta'),
    'MA': ('Maroc', 'Morocco'),
    'MX': ('Mexique', 'Mexico'),
    'MC': ('Monaco', 'Monaco'),
    'ME': ('Monténégro', 'Montenegro'),
    'NG': ('Nigeria', 'Nigeria'),
    'NO': ('Norvège', 'Norway'),
    'NZ': ('Nouvelle-Zélande', 'New Zealand'),
    'OM': ('Oman', 'Oman'),
    'PK': ('Pakistan', 'Pakistan'),
    'PS': ('Palestine', 'Palestine'),
    'PA': ('Panama', 'Panama'),
    'NL': ('Pays-Bas', 'Netherlands'),
    'PE': ('Pérou', 'Peru'),
    'PH': ('Philippines', 'Philippines'),
    'PL': ('Pologne', 'Poland'),
    'PT': ('Portugal', 'Portugal'),
    'QA': ('Qatar', 'Qatar'),
    'CD': ('RD Congo', 'DR Congo'),
    'CZ': ('Tchéquie', 'Czechia'),
    'RO': ('Roumanie', 'Romania'),
    'GB': ('Royaume-Uni', 'United Kingdom'),
    'RU': ('Russie', 'Russia'),
    'SN': ('Sénégal', 'Senegal'),
    'RS': ('Serbie', 'Serbia'),
    'SG': ('Singapour', 'Singapore'),
    'SK': ('Slovaquie', 'Slovakia'),
    'SI': ('Slovénie', 'Slovenia'),
    'SO': ('Somalie', 'Somalia'),
    'SD': ('Soudan', 'Sudan'),
    'SE': ('Suède', 'Sweden'),
    'CH': ('Suisse', 'Switzerland'),
    'SY': ('Syrie', 'Syria'),
    'TH': ('Thaïlande', 'Thailand'),
    'TG': ('Togo', 'Togo'),
    'TN': ('Tunisie', 'Tunisia'),
    'TR': ('Turquie', 'Turkey'),
    'UA': ('Ukraine', 'Ukraine'),
    'UY': ('Uruguay', 'Uruguay'),
    'VE': ('Venezuela', 'Venezuela'),
    'VN': ('Viêt Nam', 'Vietnam'),
    'YE': ('Yémen', 'Yemen'),
    'ZA': ('Afrique du Sud', 'South Africa'),
    'TW': ('Taïwan', 'Taiwan'),
    'HK': ('Hong Kong', 'Hong Kong'),
    'XK': ('Kosovo', 'Kosovo'),
  };

  /// Codes non standard très utilisés par les fournisseurs (langues, régions, abréviations à 3 lettres).
  static const _aliases = {
    'UK': 'GB',
    'EN': 'GB',
    'ENG': 'GB',
    'USA': 'US',
    'FRA': 'FR',
    'GER': 'DE',
    'DEU': 'DE',
    'ITA': 'IT',
    'ESP': 'ES',
    'SPA': 'ES',
    'POR': 'PT',
    'NED': 'NL',
    'NLD': 'NL',
    'BEL': 'BE',
    'SUI': 'CH',
    'CHE': 'CH',
    'CAN': 'CA',
    'TUR': 'TR',
    'ALB': 'AL',
    'POL': 'PL',
    'ROM': 'RO',
    'ROU': 'RO',
    'RUS': 'RU',
    'SWE': 'SE',
    'DEN': 'DK',
    'DNK': 'DK',
    'NOR': 'NO',
    'FIN': 'FI',
    'GRE': 'GR',
    'GRC': 'GR',
    'IND': 'IN',
    'PAK': 'PK',
    'IRN': 'IR',
    'IRE': 'IE',
    'ALG': 'DZ',
    'DZA': 'DZ',
    'TUN': 'TN',
    'BRA': 'BR',
    'MEX': 'MX',
    'ARG': 'AR',
    'AUS': 'AU',
    'AR': 'ARABE',
    'ARA': 'ARABE',
    'ARAB': 'ARABE',
    'ARABIC': 'ARABE',
    'ARABE': 'ARABE',
    'EXYU': 'EXYU',
    'LAT': 'LATAM',
    'LATAM': 'LATAM',
    'LATINO': 'LATAM',
    'AFR': 'AFRIQUE',
    'AFRICA': 'AFRIQUE',
    'AFRIQUE': 'AFRIQUE',
    'KU': 'KURDE',
    'KURD': 'KURDE',
    'KURDISH': 'KURDE',
  };

  /// Adjectifs et langues des catégories VOD (« Movies French », « Spanish Series »).
  static const _demonyms = {
    'FRENCH': 'FR',
    'FRANCAIS': 'FR',
    'FRANCAISE': 'FR',
    'VF': 'FR',
    'GERMAN': 'DE',
    'ALLEMAND': 'DE',
    'DEUTSCH': 'DE',
    'SPANISH': 'ES',
    'ESPAGNOL': 'ES',
    'ESPANOL': 'ES',
    'ITALIAN': 'IT',
    'ITALIEN': 'IT',
    'ITALIANO': 'IT',
    'PORTUGUESE': 'PT',
    'PORTUGAIS': 'PT',
    'BRAZILIAN': 'BR',
    'TURKISH': 'TR',
    'TURC': 'TR',
    'TURKEY': 'TR',
    'HOLLAND': 'NL',
    'GREEK': 'GR',
    'GREC': 'GR',
    'DUTCH': 'NL',
    'POLISH': 'PL',
    'RUSSIAN': 'RU',
    'KOREAN': 'KR',
    'COREEN': 'KR',
    'JAPANESE': 'JP',
    'CHINESE': 'CN',
    'INDIAN': 'IN',
    'HINDI': 'IN',
    'BOLLYWOOD': 'IN',
    'ENGLISH': 'GB',
    'ANGLAIS': 'GB',
    'BRITISH': 'GB',
    'AMERICAN': 'US',
    'CANADIAN': 'CA',
    'QUEBEC': 'CA',
    'BELGIAN': 'BE',
    'SWISS': 'CH',
    'SWEDISH': 'SE',
    'NORWEGIAN': 'NO',
    'DANISH': 'DK',
    'FINNISH': 'FI',
    'ROMANIAN': 'RO',
    'ALBANIAN': 'AL',
    'PERSIAN': 'IR',
    'IRANIAN': 'IR',
    'MEXICAN': 'MX',
    'KURDISH': 'KURDE',
    'AFRICAN': 'AFRIQUE',
    'LATINO': 'LATAM',
    'ARABIC': 'ARABE',
    'ARAB': 'ARABE',
    'ARABE': 'ARABE',
  };

  static const _specialNames = {
    'ARABE': 'Monde arabe',
    'EXYU': 'Ex-Yougoslavie',
    'LATAM': 'Amérique latine',
    'AFRIQUE': 'Afrique',
    'KURDE': 'Kurde',
  };

  /// Codes ISO qui sont surtout des mots courants dans les noms de catégories.
  static const _ignored = {'TV', 'AD', 'FM', 'PM', 'ST'};

  static final Map<String, String> _nameIndex = {
    for (final e in _names.entries) ...{
      words(e.value.$1).join(' '): e.key,
      words(e.value.$2).join(' '): e.key,
    },
  };

  static const _separators = '|:-–—])•/».▶►>';

  /// Code pays et nom sans le préfixe (« FR | Sport » → FR, « Sport »).
  static (String, String)? detect(String raw) {
    final trimmed = raw.trim();
    final runes = trimmed.runes.toList();
    // Drapeau emoji en tête : deux « regional indicators ».
    if (runes.length >= 2 && _isIndicator(runes[0]) && _isIndicator(runes[1])) {
      final code = String.fromCharCodes([
        runes[0] - 0x1F1E6 + 65,
        runes[1] - 0x1F1E6 + 65,
      ]);
      return (
        _aliases[code] ?? code,
        _clean(String.fromCharCodes(runes.skip(2))),
      );
    }
    var start = 0;
    while (start < trimmed.length && '|[(#★•*- '.contains(trimmed[start])) {
      start++;
    }
    final s = trimmed.substring(start);
    var segmentEnd = s.length;
    for (var i = 0; i < s.length; i++) {
      if (_separators.contains(s[i])) {
        segmentEnd = i;
        break;
      }
    }
    final wordEnd = RegExp(r'[^A-Za-zÀ-ÿ]').firstMatch(s)?.start ?? s.length;
    for (final end in [segmentEnd, wordEnd]) {
      final code = _code(s.substring(0, end).trim());
      if (code != null) return (code, _clean(s.substring(end)));
    }
    return null;
  }

  static bool _isIndicator(int rune) => rune >= 0x1F1E6 && rune <= 0x1F1FF;

  static String? _code(String candidate) {
    if (candidate.isEmpty) return null;
    final key = words(candidate).join(' ');
    if (key.isEmpty) return null;
    // Les abréviations ne comptent qu'en majuscules : « IT » oui, « It » non.
    if (key.length <= 3 && candidate != candidate.toUpperCase()) return null;
    final alias = _aliases[key];
    if (alias != null) return alias;
    if (key.length == 2 && _names.containsKey(key) && !_ignored.contains(key))
      return key;
    if (key.length >= 4) return _nameIndex[key];
    return null;
  }

  /// Cherche un pays n'importe où dans le nom (catégories de films et séries).
  static String? detectAnywhere(String raw) {
    final tokens = words(raw);
    // « Turkish Series Translated to Arabic » s'adresse au public arabophone.
    if (tokens.join(' ').contains('TRANSLATED TO ARABIC')) return 'ARABE';
    for (final length in [3, 2, 1]) {
      for (var start = 0; start + length <= tokens.length; start++) {
        final phrase = tokens.sublist(start, start + length).join(' ');
        if (phrase.length < 4 && !_demonyms.containsKey(phrase)) continue;
        final code = _demonyms[phrase] ?? _nameIndex[phrase];
        if (code != null) return code;
      }
    }
    return null;
  }

  static String _clean(String s) {
    var i = 0;
    while (i < s.length &&
        (' [('.contains(s[i]) || _separators.contains(s[i]))) {
      i++;
    }
    return s.substring(i).trim();
  }

  static String name(String code) {
    if (code == other) return 'Autres';
    return _specialNames[code] ?? _names[code]?.$1 ?? code;
  }

  static String flag(String code) {
    if (code.length != 2 || !_names.containsKey(code)) return '🌍';
    return String.fromCharCodes(code.codeUnits.map((c) => 0x1F1E6 + c - 65));
  }

  static String label(String code) => '${flag(code)} ${name(code)}';
}
