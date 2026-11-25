import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pdfrx/pdfrx.dart';
import 'core/l10n/app_strings.dart';
import 'core/l10n/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'data/app_services.dart';
import 'data/repositories/settings_repository.dart';
import 'ui/home_screen.dart';
import 'ui/services_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize(); // loads PDFium
  final services = await AppServices.init();
  await services.pipeline.recoverInterrupted(); // interrupted work -> paused
  final savedLocale = await services.settings.get(SettingsKeys.locale);
  runApp(PdfAiApp(
    services: services,
    localeController: LocaleController(services.settings, savedLocale),
  ));
}

class PdfAiApp extends StatelessWidget {
  const PdfAiApp({super.key, required this.services, required this.localeController});
  final AppServices services;
  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return ServicesScope(
      services: services,
      child: ValueListenableBuilder<Locale>(
        valueListenable: localeController,
        builder: (context, locale, _) => MaterialApp(
          title: 'PDFAI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: locale, // RTL/LTR is applied automatically from the locale
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: HomeScreen(localeController: localeController),
        ),
      ),
    );
  }
}
