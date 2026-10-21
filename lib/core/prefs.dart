import 'package:shared_preferences/shared_preferences.dart';

/// Телефондо сакталуучу майда маалыматтар.
class Prefs {
  static const _last = 'lastCode';
  static const _profile = 'driverProfile'; // [аты, телефон, модель, номер, түс]
  static const _lang = 'language';

  static Future<String?> lastCode() async =>
      (await SharedPreferences.getInstance()).getString(_last);

  static Future<void> setLastCode(String code) async =>
      (await SharedPreferences.getInstance()).setString(_last, code);

  static Future<List<String>> profile() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_profile) ?? const [];
  }

  static Future<void> saveProfile(List<String> v) async =>
      (await SharedPreferences.getInstance()).setStringList(_profile, v);

  static Future<String?> language() async =>
      (await SharedPreferences.getInstance()).getString(_lang);

  static Future<void> setLanguage(String code) async =>
      (await SharedPreferences.getInstance()).setString(_lang, code);

  static const _unlocked = 'driverUnlockedUid';

  static Future<String?> driverUnlockedUid() async =>
      (await SharedPreferences.getInstance()).getString(_unlocked);

  static Future<void> setDriverUnlockedUid(String? uid) async {
    final p = await SharedPreferences.getInstance();
    uid == null ? await p.remove(_unlocked) : await p.setString(_unlocked, uid);
  }
}
