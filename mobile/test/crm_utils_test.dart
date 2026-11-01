import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/models/client.dart';
import 'package:namofarm/models/crm_pipeline.dart';
import 'package:namofarm/models/interaction.dart';
import 'package:namofarm/models/tache_crm.dart';
import 'package:namofarm/screens/crm/clients_tab.dart';
import 'package:namofarm/utils/contact_launcher.dart';
import 'package:namofarm/utils/crm_labels.dart';

void main() {
  // Samedi 31 octobre 2026, 10h.
  final now = DateTime(2026, 10, 31, 10);

  group('Libellés CRM', () {
    test('traduisent les valeurs techniques avec accents', () {
      expect(pipelineStage('negociation').label, 'Négociation');
      expect(pipelineStage('qualifie').label, 'Qualifié');
      expect(tacheStatut('a_faire').label, 'À faire');
      expect(tacheType('rendez_vous').label, 'Rendez-vous');
      expect(clientStatut('actif').label, 'Actif');
      expect(interactionType('commentaire').label, 'Note');
    });

    test('humanisent une valeur inconnue au lieu de planter', () {
      expect(tacheType('visite_ferme').label, 'Visite ferme');
      expect(clientStatut('').label, '—');
    });

    test('isTacheOuverte', () {
      expect(isTacheOuverte('a_faire'), isTrue);
      expect(isTacheOuverte('en_cours'), isTrue);
      expect(isTacheOuverte('terminee'), isFalse);
      expect(isTacheOuverte('annulee'), isFalse);
    });

    test('initiales et couleur d’avatar stable', () {
      expect(initials('Awa Diop'), 'AD');
      expect(initials('  moussa  '), 'M');
      expect(initials('Jean Pierre Ndiaye'), 'JN');
      expect(initials(''), '?');
      expect(avatarColor('Awa Diop'), avatarColor('Awa Diop'));
    });

    test('scoreColor', () {
      expect(scoreColor(85), scoreColor(70));
      expect(scoreColor(50), isNot(scoreColor(85)));
      expect(scoreColor(10), isNot(scoreColor(50)));
    });
  });

  group('Dates relatives', () {
    test('relativeDay', () {
      expect(relativeDay(DateTime(2026, 10, 31, 22), now: now), "Aujourd'hui");
      expect(relativeDay(DateTime(2026, 11, 1), now: now), 'Demain');
      expect(relativeDay(DateTime(2026, 10, 30), now: now), 'Hier');
      expect(relativeDay(DateTime(2026, 11, 5), now: now), 'Dans 5 j');
      expect(relativeDay(DateTime(2026, 10, 20), now: now), 'Il y a 11 j');
      expect(relativeDay(DateTime(2026, 1, 2), now: now), '02/01/2026');
    });

    test('timelineDayLabel et formats', () {
      expect(timelineDayLabel(DateTime(2026, 10, 31, 8), now: now), "Aujourd'hui");
      expect(timelineDayLabel(DateTime(2026, 10, 30), now: now), 'Hier');
      expect(timelineDayLabel(DateTime(2026, 8, 15), now: now), '15 août 2026');
      expect(formatHeure(DateTime(2026, 1, 1, 7, 5)), '07:05');
    });

    test('dueBucketFor regroupe par échéance façon Planner', () {
      final wednesday = DateTime(2026, 10, 28);
      expect(dueBucketFor(DateTime(2026, 10, 27), now: wednesday), DueBucket.enRetard);
      expect(dueBucketFor(DateTime(2026, 10, 28, 18), now: wednesday), DueBucket.aujourdhui);
      expect(dueBucketFor(DateTime(2026, 11, 1), now: wednesday), DueBucket.cetteSemaine);
      expect(dueBucketFor(DateTime(2026, 11, 2), now: wednesday), DueBucket.plusTard);
    });

    test('dueDateForBucket donne une date cohérente avec la colonne', () {
      final wednesday = DateTime(2026, 10, 28, 9);
      expect(dueDateForBucket(DueBucket.enRetard, now: wednesday), isNull);
      for (final b in [DueBucket.aujourdhui, DueBucket.cetteSemaine, DueBucket.plusTard]) {
        expect(dueBucketFor(dueDateForBucket(b, now: wednesday)!, now: wednesday), b);
      }
    });
  });

  group('Liens de contact', () {
    test('internationalDigits', () {
      expect(internationalDigits('+221 77 12 34 56'), '22177123456');
      expect(internationalDigits('00221 77 123 45 67'), '221771234567');
      expect(internationalDigits('123'), isNull);
    });

    test('telUri, whatsappUri et mailUri', () {
      expect(telUri('+221 77 12 34 56').toString(), 'tel:+22177123456');
      expect(telUri(''), isNull);
      expect(whatsappUri('+221 77 12 34 56', message: 'Bonjour Awa').toString(), 'https://wa.me/22177123456?text=Bonjour+Awa');
      expect(whatsappUri('+221 77 12 34 56').toString(), 'https://wa.me/22177123456');
      expect(mailUri('awa@ferme.sn', subject: 'Devis poulets').toString(), 'mailto:awa@ferme.sn?subject=Devis%20poulets');
      expect(mailUri('pas-un-email'), isNull);
    });
  });

  group('Modèles CRM', () {
    test('PipelineDeal parse, copie et prépare la mise à jour', () {
      final deal = PipelineDeal.fromJson({
        'clientId': 'c1',
        'prenom': 'Awa',
        'nom': 'Diop',
        'stage': 'proposition',
        'score': 72,
        'montant': 250000,
        'probabilite': 50,
        'dateCloturePrevue': '2026-11-15T00:00:00.000Z',
        'commandesCount': 3,
      });
      expect(deal.nomComplet, 'Awa Diop');
      expect(deal.montantPondere, 125000);
      expect(deal.dateCloturePrevue, isNotNull);

      final moved = deal.copyWith(stage: 'negociation', probabilite: 75);
      final payload = moved.toUpdatePayload(note: 'RDV fixé');
      expect(payload['stage'], 'negociation');
      expect(payload['montant'], 250000);
      expect(payload['probabilite'], 75);
      expect(payload['note'], 'RDV fixé');
      expect(payload['dateCloturePrevue'], isNotNull);
    });

    test('CrmSuggestion devient une tâche', () {
      final s = CrmSuggestion.fromJson({
        'id': 'reachat-c1',
        'kind': 'reachat',
        'clientId': 'c1',
        'clientNom': 'Awa Diop',
        'titre': 'Proposer un réachat',
        'type': 'appel',
        'priorite': 'haute',
        'dateEcheance': '2026-11-02T00:00:00.000Z',
      });
      final payload = s.toTachePayload(assigneA: 'Moussa');
      expect(payload['clientId'], 'c1');
      expect(payload['type'], 'appel');
      expect(payload['priorite'], 'haute');
      expect(payload['statut'], 'a_faire');
      expect(payload['assigneA'], 'Moussa');
    });

    test('CrmDashboardData calcule l’évolution du CA', () {
      final d = CrmDashboardData.fromJson({
        'caMois': 150000,
        'caMoisPrecedent': 100000,
        'relancesAFaire': 2,
        'topClients': [
          {'_id': 'c1', 'prenom': 'Awa', 'nom': 'Diop', 'chiffreAffairesCumul': 900000},
        ],
        'ventesParMois': [
          {'_id': {'annee': 2026, 'mois': 10}, 'total': 150000},
        ],
      });
      expect(d.evolutionCa, closeTo(50, 0.001));
      expect(d.relancesEnRetard, 2);
      expect(d.topClients.single.nomComplet, 'Awa Diop');
      expect(d.ventesParMois.single.mois, 10);
      expect(const CrmDashboardData().evolutionCa, isNull);
    });

    test('TacheCRM lit la checklist et le client peuplé', () {
      final t = TacheCRM.fromJson({
        '_id': 't1',
        'titre': 'Livrer',
        'dateEcheance': '2026-11-02T00:00:00.000Z',
        'clientId': {'_id': 'c1', 'prenom': 'Awa', 'nom': 'Diop', 'telephone': '+221 77'},
        'checklist': [
          {'titre': 'Préparer', 'fait': true},
          {'titre': 'Livrer', 'fait': false},
        ],
      });
      expect(t.clientId, 'c1');
      expect(t.clientNom, 'Awa Diop');
      expect(t.checklistFaits, 1);
      expect(t.copyWith(statut: 'terminee').checklist.length, 2);
      expect(t.toJson()['checklist'], hasLength(2));
    });

    test('Interaction lit le contenu JSON des mises à jour de pipeline', () {
      final i = Interaction.fromJson({
        '_id': 'i1',
        'clientId': 'c1',
        'type': 'pipeline_update',
        'contenu': '{"stage":"gagne","montant":300000}',
        'dateInteraction': '2026-10-30T10:00:00.000Z',
      });
      expect(i.isPipelineUpdate, isTrue);
      expect(i.pipelineMeta?['stage'], 'gagne');

      final note = Interaction.fromJson({'clientId': 'c1', 'type': 'appel', 'contenu': 'pas du json'});
      expect(note.pipelineMeta, isNull);
    });

    test('les dates envoyées à l’API sont en UTC (pas de décalage à chaque enregistrement)', () {
      final local = DateTime(2026, 11, 1, 23, 30);
      final deal = PipelineDeal(clientId: 'c1', dateCloturePrevue: local);
      final tache = TacheCRM(clientId: 'c1', titre: 'T', dateEcheance: local);
      final suggestion = CrmSuggestion(id: 's', kind: 'k', clientId: 'c1', clientNom: 'X', titre: 'T', dateEcheance: local);

      for (final sent in [
        deal.toUpdatePayload()['dateCloturePrevue'] as String,
        tache.toJson()['dateEcheance'] as String,
        suggestion.toTachePayload()['dateEcheance'] as String,
      ]) {
        expect(sent, endsWith('Z'));
        expect(DateTime.parse(sent).toLocal(), local);
      }
    });

    test('copyWith permet d’effacer la date de clôture', () {
      final deal = PipelineDeal(clientId: 'c1', dateCloturePrevue: DateTime(2026, 12, 1));
      expect(deal.copyWith(stage: 'gagne').dateCloturePrevue, isNotNull);
      expect(deal.copyWith(clearDateCloture: true).dateCloturePrevue, isNull);
      expect(deal.copyWith(clearDateCloture: true).toUpdatePayload()['dateCloturePrevue'], isNull);
    });
  });

  group('Vues clients', () {
    Client c(String id, {String statut = 'actif', double ca = 0, DateTime? contact}) =>
        Client(id: id, nom: id, prenom: '', telephone: '', statut: statut, chiffreAffairesCumul: ca, dernierContactLe: contact);

    test('Sans contact 30 j exclut les inactifs et les contacts récents', () {
      final clients = [
        c('recent', contact: now.subtract(const Duration(days: 3))),
        c('ancien', contact: now.subtract(const Duration(days: 45))),
        c('jamais'),
        c('inactif', statut: 'inactif'),
      ];
      expect(applyClientsView(clients, ClientsView.sansContact, now: now).map((x) => x.id), ['ancien', 'jamais']);
    });

    test('Meilleurs clients trie par CA et ignore les CA nuls', () {
      final clients = [c('a', ca: 100), c('b', ca: 0), c('c', ca: 500)];
      expect(applyClientsView(clients, ClientsView.topClients).map((x) => x.id), ['c', 'a']);
      expect(applyClientsView(clients, ClientsView.tous), hasLength(3));
    });
  });
}
