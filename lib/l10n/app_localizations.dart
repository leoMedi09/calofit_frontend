import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const _localizedValues = {
    'es': {
      'welcome': '¡Bienvenido!',
      'dashboard': 'Dashboard',
      'patients': 'Pacientes',
      'assistant': 'Asistente',
      'profile': 'Perfil',
      'menu': 'Menú',
      'settings': 'Ajustes',
      'logout': 'Cerrar Sesión',
      'language': 'Idioma',
      'language_es': 'Español',
      'language_en': 'Inglés',
      'save': 'Guardar',
      'edit_profile': 'Editar Perfil',
      'security': 'Seguridad',
      'active': 'Activo',
      'verified': 'Verificado',
      'hello': 'Hola',
      'ready_to_work': '¡Listo para trabajar!',
    },
    'en': {
      'welcome': 'Welcome!',
      'dashboard': 'Dashboard',
      'patients': 'Patients',
      'assistant': 'Assistant',
      'profile': 'Profile',
      'menu': 'Menu',
      'settings': 'Settings',
      'logout': 'Logout',
      'language': 'Language',
      'language_es': 'Spanish',
      'language_en': 'English',
      'save': 'Save',
      'edit_profile': 'Edit Profile',
      'security': 'Security',
      'active': 'Active',
      'verified': 'Verified',
      'hello': 'Hello',
      'ready_to_work': 'Ready to work!',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['es', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
