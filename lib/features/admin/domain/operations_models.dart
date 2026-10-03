class OpsTask {
  OpsTask(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  String get name => json['competition_name'] as String? ?? 'Compétition';
  String get status => json['status'] as String? ?? 'pending';
  int get stage => (json['stage'] as num? ?? 0).toInt();
  int get leagueId => (json['league_id'] as num).toInt();
  bool get stopping => json['cancel_requested'] == true && status == 'running';
  bool get terminal => ['succeeded', 'failed', 'cancelled'].contains(status);
  double get progress => stage.clamp(0, 4) / 4;
  Map<String, dynamic> get counters => opsMap(json['counters']);
  Map<String, dynamic> get sample => opsMap(json['sample']);
  String? get error => json['error_message'] as String?;
  String get label => stopping ? 'Arrêt demandé' : opsStatus(status);
}

class OpsOverview {
  OpsOverview(this.json);
  final Map<String, dynamic> json;
  List<Map<String, dynamic>> get competitions => opsRows(json['competitions']);
  List<Map<String, dynamic>> get cycles => opsRows(json['cycles']);
  List<OpsTask> get tasks => opsRows(json['tasks']).map(OpsTask.new).toList();
  List<OpsTask> get active => opsRows(json['active']).map(OpsTask.new).toList();
  List<Map<String, dynamic>> get legacy => opsRows(json['legacy']);
  String? get cycleId => json['selected_cycle_id'] as String?;
  Map<String, dynamic> get cycle =>
      cycles.where((x) => x['id'] == cycleId).firstOrNull ?? {};
  bool get scheduling => json['scheduling_enabled'] == true;
  DateTime? get updatedAt => DateTime.tryParse('${json['generated_at']}');
  int count(String status) => tasks.where((x) => x.status == status).length;
  // Processed includes failures; success is always displayed separately.
  double get progress => tasks.isEmpty
      ? 0
      : tasks.fold<double>(0, (sum, t) => sum + (t.terminal ? 1 : t.progress)) /
            tasks.length;
  String competitionName(int id) =>
      competitions.where((x) => x['league_id'] == id).firstOrNull?['name']
          as String? ??
      'Compétition non cataloguée ($id)';
}

const opsStageNames = ['Collecte API', 'Résultats', 'Snapshot', 'Publication'];
const opsStageExpectations = [
  'Calendrier, équipes, cotes et historiques disponibles auprès du fournisseur. Les réponses en cache restent utilisables.',
  'Scores finaux des sept derniers jours et résultats des lectures publiées.',
  'Données consolidées : matchs à venir, classement et forme récente, même pendant une trêve.',
  'Lectures et scénarios calculés ; snapshot compact accessible à l’application.',
];
String opsStatus(String value) => switch (value) {
  'pending' => 'En attente',
  'running' => 'En cours',
  'succeeded' => 'Réussi',
  'failed' => 'Échec',
  'partial' => 'Partiel',
  'cancelled' => 'Interrompu',
  _ => value,
};
Map<String, dynamic> opsMap(Object? v) =>
    v is Map<Object?, Object?> ? Map<String, dynamic>.from(v) : {};
List<Map<String, dynamic>> opsRows(Object? v) => v is List
    ? v
          .whereType<Map<Object?, Object?>>()
          .map((x) => Map<String, dynamic>.from(x))
          .toList()
    : [];
