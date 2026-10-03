/// Shared explanation catalogue. A technical message is evidence, not proof of
/// an underlying cause: unknown failures retain a neutral explanation.
class OperationsIssue {
  const OperationsIssue(
    this.code,
    this.title,
    this.reason,
    this.action, {
    this.reconnect = false,
  });
  final String code, title, reason, action;
  final bool reconnect;
}

OperationsIssue explainOperationsIssue(
  String message, {
  bool adminRequest = false,
}) {
  final e = message.toLowerCase();
  bool has(String text) => e.contains(text);
  bool http(int code) => RegExp('\\b$code\\b').hasMatch(e);
  if (has('invalid user token') ||
      has('jwt expired') && adminRequest ||
      has('invalid jwt') && adminRequest ||
      adminRequest &&
          RegExp(r'(status|statuscode)\s*[:=]\s*401\b').hasMatch(e)) {
    return const OperationsIssue(
      'admin_session',
      'Session de connexion refusée',
      'Le serveur ne reconnaît plus la session utilisée pour accéder à l’administration. Elle peut avoir expiré ou être devenue invalide. Ce message ne signifie pas que les batchs ont échoué.',
      'Se reconnecter, puis actualiser. Les dernières données affichées peuvent ne plus être à jour.',
      reconnect: true,
    );
  }
  if (has('api_football_sync_run_id') ||
      has('identifiant de collecte manquant')) {
    return const OperationsIssue(
      'missing_collection_id',
      'Lien entre la collecte et les résultats manquant',
      'L’étape des résultats n’a pas reçu la référence de la collecte. Elle ne peut donc pas enregistrer ses appels dans le suivi du quota et s’arrête. Ce message ne dit pas que le quota est épuisé.',
      'Faire vérifier la transmission de cette référence entre les fonctions et leurs versions déployées, puis relancer le batch.',
    );
  }
  if (has('does not cover the full requested period')) {
    return const OperationsIssue(
      'incomplete_empty_fixture_coverage',
      'Calendrier incomplet pour cette période',
      'Aucun match ou autre donnée exploitable n’a été trouvé, et l’application n’a pas de réponse valide pour chaque journée demandée. Un flux vide est normal quand toute la période a été vérifiée et qu’aucun match n’est prévu ; ici, il manque une partie de cette vérification.',
      'Consulter la collecte des journées manquantes puis relancer le batch. La nouvelle version publie un flux vide lorsque le calendrier complet confirme l’absence de match.',
    );
  }
  if (has('empty match feed snapshot') ||
      has('refusing to publish an empty') ||
      has('no cached api-football responses') ||
      has('snapshot manquant')) {
    return const OperationsIssue(
      'empty_snapshot',
      'Ancien refus de publication vide',
      'L’ancienne version bloquait tout snapshot sans ligne exploitable, même si aucun match n’était prévu. Ce message ne distingue pas une période sans match d’une collecte incomplète. La nouvelle version vérifie la couverture de chaque journée et accepte un flux vide lorsque la période entière a été collectée avec succès.',
      'Relancer avec les fonctions mises à jour, puis contrôler que toutes les dates de la période sont présentes dans la collecte.',
    );
  }
  if (has('enrichment scope') || has('player enrichment scope')) {
    return const OperationsIssue(
      'enrichment_too_large',
      'Ancien arrêt sur volume d’enrichissement',
      'Cette exécution utilisait une ancienne limite par batch et s’est arrêtée avant de tout récupérer. Le volume n’est pas une erreur de données : le traitement doit avancer par lots pour respecter le temps d’exécution et les limites d’appels de chaque passage.',
      'Relancer avec la version mise à jour : elle découpe les appels en lots successifs et reprend automatiquement jusqu’à la fin.',
    );
  }
  if (has('stale running window') || has('expiration du délai')) {
    return const OperationsIssue(
      'missing_completion',
      'Fin du batch non confirmée',
      'Le batch est resté « en cours » au-delà du délai de surveillance sans confirmer sa fin. Il a été classé en échec. Le message ne précise pas s’il a été interrompu, bloqué ou s’il a perdu sa connexion.',
      'Consulter la dernière étape et les données déjà enregistrées, puis relancer si nécessaire.',
    );
  }
  if (has('daily_limit')) {
    return const OperationsIssue(
      'daily_quota',
      'Quota quotidien atteint',
      'Le budget quotidien d’appels au fournisseur a été consommé. Les nouveaux appels sont refusés.',
      'Attendre le renouvellement du quota, puis relancer les batchs concernés.',
    );
  }
  if (has('minute_limit') || http(429)) {
    return const OperationsIssue(
      'request_rate',
      'Trop d’appels rapprochés',
      'Le fournisseur ou le contrôle du quota refuse de nouveaux appels pour le moment. La fréquence des demandes est trop élevée.',
      'Attendre avant de relancer. Si cela se répète, réduire la fréquence ou les exécutions simultanées.',
    );
  }
  if (http(401) || has('unauthorized')) {
    return const OperationsIssue(
      'server_credentials',
      'Accès entre services refusé',
      'Un service n’accepte pas les identifiants reçus. Il peut s’agir de la clé du fournisseur ou du secret utilisé entre les fonctions ; le détail technique indique le service concerné.',
      'Faire vérifier la configuration et les secrets du service concerné, puis relancer.',
    );
  }
  if (http(403) || has('admin access') || has('not authorized')) {
    return OperationsIssue(
      'forbidden',
      'Autorisation insuffisante',
      adminRequest
          ? 'Le compte connecté n’est pas autorisé à accéder à cette administration.'
          : 'Le service a refusé l’accès à la ressource demandée.',
      adminRequest
          ? 'Utiliser un compte administrateur autorisé ou faire vérifier ses droits.'
          : 'Faire vérifier les droits et l’abonnement du service concerné.',
    );
  }
  if (has('déjà en attente') || has('déjà en cours')) {
    return const OperationsIssue(
      'already_queued',
      'Cette compétition a déjà un batch prévu',
      'Un batch est déjà en attente ou en cours pour cette compétition. Le nouveau lancement est refusé pour éviter un doublon.',
      'Ouvrir le cycle concerné et attendre sa fin, ou interrompre ce batch avant de relancer.',
    );
  }
  if (has('timeout') || has('timed out') || has('aborted') || http(504)) {
    return const OperationsIssue(
      'timeout',
      'Délai de réponse dépassé',
      'Une étape n’a pas confirmé sa fin dans le délai autorisé. Certaines données peuvent déjà avoir été enregistrées.',
      'Vérifier la dernière étape avant de relancer. Si l’erreur revient, faire examiner la durée et le volume du traitement.',
    );
  }
  if (has('failed to fetch') ||
      has('socketexception') ||
      has('clientexception') ||
      has('network')) {
    return const OperationsIssue(
      'network',
      'Communication avec le serveur impossible',
      'La demande n’a pas obtenu de réponse exploitable. Le message ne permet pas de distinguer une coupure réseau d’un serveur indisponible.',
      'Vérifier la connexion, puis actualiser. Avant de répéter un lancement, vérifier si le batch a été créé.',
    );
  }
  if (has('quota')) {
    return const OperationsIssue(
      'quota',
      'Appel bloqué par le contrôle du quota',
      'Le contrôle du budget d’appels a refusé la demande. Le détail disponible ne précise pas quelle limite a été atteinte.',
      'Consulter la consommation et le détail technique avant de relancer.',
    );
  }
  if (http(500) || http(502) || http(503)) {
    return const OperationsIssue(
      'server_error',
      'Une étape a rencontré une erreur serveur',
      'Le service n’a pas pu terminer la demande. Le code seul ne donne pas la cause précise.',
      'Consulter le détail technique et le journal de l’étape. Si le problème persiste, faire corriger la cause avant de relancer.',
    );
  }
  return const OperationsIssue(
    'unknown',
    'Erreur à examiner',
    'Cette erreur ne dispose pas encore d’une explication spécifique dans le dictionnaire. Sa cause ne peut pas être déduite avec certitude.',
    'Ouvrir le détail technique et le transmettre pour diagnostic.',
  );
}
