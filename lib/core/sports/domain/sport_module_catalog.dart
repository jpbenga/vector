import 'sport_module.dart';

/// Validated composition root. Registering a module does not require adding
/// a case to a shared engine or changing the router's accepted sport keys.
class SportModuleCatalog {
  SportModuleCatalog(Iterable<SportModuleDefinition> modules)
    : modules = List.unmodifiable(modules) {
    final keys = <String>{};
    for (final module in this.modules) {
      module.sport.validate();
      module.dataPolicy.validate();
      module.provider?.validate();
      if (!keys.add(module.sport.key)) {
        throw ArgumentError('Duplicate sport: ${module.sport.key}');
      }
      final readings = <String, SportReadingDefinition>{};
      for (final reading in module.readings) {
        if (reading.id.trim().isEmpty || readings.containsKey(reading.id)) {
          throw ArgumentError('Invalid or duplicate reading: ${reading.id}');
        }
        readings[reading.id] = reading;
      }
      final scenarios = <String>{};
      for (final scenario in module.scenarios) {
        if (scenario.id.trim().isEmpty ||
            !scenarios.add(scenario.id) ||
            scenario.requiredReadingIds.isEmpty ||
            scenario.requiredReadingIds.toSet().length !=
                scenario.requiredReadingIds.length ||
            scenario.requiredReadingIds.any(
              (id) => readings[id]?.implemented != true,
            )) {
          throw ArgumentError('Invalid scenario dependencies: ${scenario.id}');
        }
      }
    }
  }

  final List<SportModuleDefinition> modules;

  SportModuleDefinition? find(String key) {
    for (final module in modules) {
      if (module.sport.key == key) return module;
    }
    return null;
  }
}
