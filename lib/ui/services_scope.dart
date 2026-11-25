import 'package:flutter/widgets.dart';
import '../data/app_services.dart';

/// Gives screens access to the data layer.
class ServicesScope extends InheritedWidget {
  const ServicesScope({super.key, required this.services, required super.child});
  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ServicesScope>();
    assert(scope != null, 'ServicesScope not found');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(ServicesScope oldWidget) => services != oldWidget.services;
}
