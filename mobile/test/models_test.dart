import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/models/alerte.dart';
import 'package:namofarm/models/bande.dart';
import 'package:namofarm/models/stock.dart';

void main() {
  group('Bande.fromJson', () {
    test('parse une bande complète avec suivis et événements', () {
      final bande = Bande.fromJson({
        '_id': 'b1',
        'nom': 'Bande A',
        'dateOuverture': '2026-07-01T00:00:00.000Z',
        'dateFermeture': '2026-08-15T00:00:00.000Z',
        'statut': 'fermee',
        'typeVolaille': 'pondeuse',
        'race': 'ISA Brown',
        'nombreInitial': 500,
        'nombreActuel': 480,
        'mortaliteTotale': 20,
        'poidsArriveeG': 40,
        'coutPoussin': 650,
        'ageJours': 45,
        'tauxMortalite': 4,
        'suiviJournalier': [
          {'_id': 's1', 'date': '2026-07-02T00:00:00.000Z', 'alimentationKg': 12, 'mortaliteJour': 2},
        ],
        'evenementsSante': [
          {'_id': 'e1', 'date': '2026-07-05T00:00:00.000Z', 'type': 'vaccination', 'description': 'Gumboro', 'cout': 5000},
        ],
        'evenementsPrevisionnels': [
          {'_id': 'p1', 'datePrevue': '2026-07-10T00:00:00.000Z'},
        ],
      });

      expect(bande.id, 'b1');
      expect(bande.statut, 'fermee');
      expect(bande.typeVolaille, 'pondeuse');
      expect(bande.dateFermeture, DateTime.utc(2026, 8, 15));
      expect(bande.poidsArriveeG, 40.0);
      expect(bande.coutPoussin, 650.0);
      expect(bande.tauxMortalite, '4');
      expect(bande.suiviJournalier.single.alimentationKg, 12.0);
      expect(bande.suiviJournalier.single.mortaliteJour, 2);
      expect(bande.evenementsSante.single.cout, 5000.0);
      expect(bande.evenementsSante.single.dureeJours, 1);

      final prev = bande.evenementsPrevisionnels.single;
      expect(prev.type, 'intervention_diverse');
      expect(prev.statut, 'planifie');
      expect(prev.priorite, 'moyenne');
      expect(prev.dateRealisation, isNull);
    });

    test('applique les valeurs par défaut quand les champs optionnels manquent', () {
      final bande = Bande.fromJson({
        'nom': 'Bande B',
        'dateOuverture': '2026-07-01',
        'statut': 'ouverte',
        'race': 'Cobb',
        'nombreInitial': 100,
        'nombreActuel': 100,
      });

      expect(bande.id, isNull);
      expect(bande.typeVolaille, 'poulet_chair');
      expect(bande.dureeElevageJours, 45);
      expect(bande.mortaliteTotale, 0);
      expect(bande.dateFermeture, isNull);
      expect(bande.suiviJournalier, isEmpty);
      expect(bande.evenementsSante, isEmpty);
      expect(bande.evenementsPrevisionnels, isEmpty);
    });

    test('toJson n’envoie que les champs modifiables', () {
      final json = Bande(
        nom: 'Bande C',
        dateOuverture: DateTime(2026, 7, 1),
        typeVolaille: 'poulet_chair',
        race: 'Ross',
        nombreInitial: 200,
        nombreActuel: 150,
      ).toJson();

      expect(json['nom'], 'Bande C');
      expect(json['nombreInitial'], 200);
      expect(json.containsKey('nombreActuel'), isFalse);
      expect(json.containsKey('statut'), isFalse);
    });
  });

  group('Stock.fromJson', () {
    test('convertit les nombres entiers en double et parse les mouvements', () {
      final stock = Stock.fromJson({
        '_id': 'st1',
        'nom': 'Aliment démarrage',
        'categorie': 'aliment',
        'unite': 'kg',
        'quantiteActuelle': 100,
        'seuilAlerte': 10,
        'prixUnitaire': 350,
        'enAlerte': false,
        'dateExpiration': '2027-01-01T00:00:00.000Z',
        'mouvements': [
          {'_id': 'm1', 'date': '2026-07-01T08:00:00.000Z', 'type': 'entree', 'quantite': 100, 'coutUnitaire': 350},
        ],
      });

      expect(stock.quantiteActuelle, 100.0);
      expect(stock.prixUnitaire, 350.0);
      expect(stock.enAlerte, isFalse);
      expect(stock.dateExpiration, DateTime.utc(2027, 1, 1));
      expect(stock.mouvements.single.type, 'entree');
      expect(stock.mouvements.single.coutUnitaire, 350.0);
      expect(stock.mouvements.single.utilisateur, '');
    });

    test('tolère l’absence de mouvements et de champs optionnels', () {
      final stock = Stock.fromJson({'nom': 'Vaccin', 'categorie': 'sante', 'unite': 'dose'});

      expect(stock.quantiteActuelle, 0);
      expect(stock.fournisseur, '');
      expect(stock.dateExpiration, isNull);
      expect(stock.mouvements, isEmpty);
    });
  });

  group('Alerte.fromJson', () {
    Map<String, dynamic> base() => {
          'titre': 'Vaccin',
          'message': 'Rappel',
          'type': 'sante',
          'dateEcheance': '2026-07-13T00:00:00.000Z',
        };

    test('accepte un identifiant _id ou id', () {
      expect(Alerte.fromJson({...base(), '_id': 'a1'}).id, 'a1');
      expect(Alerte.fromJson({...base(), 'id': 42}).id, '42');
    });

    test('extrait bandeId qu’il soit une chaîne ou un objet peuplé', () {
      expect(Alerte.fromJson({...base(), 'bandeId': 'b1'}).bandeId, 'b1');
      expect(Alerte.fromJson({...base(), 'bandeId': {'_id': 'b2', 'nom': 'X'}}).bandeId, 'b2');
      expect(Alerte.fromJson(base()).bandeId, isNull);
    });

    test('applique les valeurs par défaut', () {
      final alerte = Alerte.fromJson(base());
      expect(alerte.statut, 'active');
      expect(alerte.recurrence, 'aucune');
      expect(alerte.priorite, 'moyenne');
      expect(alerte.automatique, isFalse);
      expect(alerte.touteJournee, isFalse);
      expect(alerte.recurrenceConfig, isEmpty);
    });

    test('ignore une dateFin invalide au lieu de planter', () {
      expect(Alerte.fromJson({...base(), 'dateFin': 'pas-une-date'}).dateFin, isNull);
    });

    test('toJson / fromJson aller-retour', () {
      final original = Alerte(
        titre: 'Pesée',
        message: 'Peser 6 sujets',
        type: 'autre',
        dateEcheance: DateTime.utc(2026, 7, 20),
        recurrence: 'hebdomadaire',
        recurrenceConfig: const {'jours': [1]},
        priorite: 'haute',
      );
      final copy = Alerte.fromJson(original.toJson());

      expect(copy.titre, original.titre);
      expect(copy.dateEcheance, original.dateEcheance);
      expect(copy.recurrence, 'hebdomadaire');
      expect(copy.recurrenceConfig, {'jours': [1]});
      expect(copy.priorite, 'haute');
    });
  });
}
