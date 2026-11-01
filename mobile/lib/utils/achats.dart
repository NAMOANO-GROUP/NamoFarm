import '../models/client.dart';
import '../models/stock.dart';

String _norm(String v) => v.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

/// Noms sous lesquels un fournisseur peut apparaître dans le champ libre "fournisseur" d'un stock.
List<String> fournisseurAliases(Client f) {
  return {
    _norm(f.entreprise),
    _norm('${f.prenom} ${f.nom}'),
    _norm('${f.nom} ${f.prenom}'),
  }.where((a) => a.isNotEmpty).toList();
}

/// Vrai si le stock est approvisionné par ce fournisseur (égalité ou nom contenu, insensible à la casse).
bool stockFourniPar(Stock stock, Client fournisseur) {
  final source = _norm(stock.fournisseur);
  if (source.isEmpty) return false;
  for (final alias in fournisseurAliases(fournisseur)) {
    if (source == alias) return true;
    if (alias.length >= 4 && source.contains(alias)) return true;
  }
  return false;
}

/// Une réception (entrée de stock) rattachée à un article.
class Reception {
  final Stock stock;
  final MouvementStock mouvement;

  const Reception(this.stock, this.mouvement);

  double get montant => mouvement.quantite * (mouvement.coutUnitaire > 0 ? mouvement.coutUnitaire : stock.prixUnitaire);
}

/// Réceptions (mouvements d'entrée et créations de stock) des articles donnés, de la plus récente à la plus ancienne.
List<Reception> receptionsDe(List<Stock> stocks) {
  return [
    for (final s in stocks)
      for (final m in s.mouvements)
        if (m.type == 'entree' || m.type == 'creation') Reception(s, m),
  ]..sort((a, b) => b.mouvement.date.compareTo(a.mouvement.date));
}

bool stockBas(Stock s) => s.seuilAlerte > 0 && s.quantiteActuelle <= s.seuilAlerte;
