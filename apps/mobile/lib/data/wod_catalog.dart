import 'models.dart';

/// Catalogue des 15 séances de référence (ids alignés sur le score-service / seed).
/// 8 avec matériel, 7 sans. Utilisé par l'écran de log.
const List<WodCatalogItem> wodCatalog = [
  // Avec matériel
  WodCatalogItem(id: 'hyrox_sprint', name: 'Sprint HYROX', scoreType: 'time', requiresEquipment: true),
  WodCatalogItem(id: 'fran', name: 'Fran', scoreType: 'time', requiresEquipment: true),
  WodCatalogItem(id: 'grace', name: 'Grace', scoreType: 'time', requiresEquipment: true),
  WodCatalogItem(id: 'jackie', name: 'Jackie', scoreType: 'time', requiresEquipment: true),
  WodCatalogItem(id: 'row_2k', name: '2000 m Rameur', scoreType: 'time', requiresEquipment: true),
  WodCatalogItem(id: 'helen', name: 'Helen', scoreType: 'time', requiresEquipment: true),
  WodCatalogItem(id: 'karen', name: 'Karen', scoreType: 'time', requiresEquipment: true),
  WodCatalogItem(id: 'cindy', name: 'Cindy', scoreType: 'reps', requiresEquipment: true),
  // Sans matériel
  WodCatalogItem(id: 'benchmark_zero', name: 'Benchmark Zéro', scoreType: 'time', requiresEquipment: false),
  WodCatalogItem(id: 'run_5k', name: '5 km Course', scoreType: 'time', requiresEquipment: false),
  WodCatalogItem(id: 'run_3k', name: '3 km Course', scoreType: 'time', requiresEquipment: false),
  WodCatalogItem(id: 'run_1k', name: '1 km Course', scoreType: 'time', requiresEquipment: false),
  WodCatalogItem(id: 'run_400', name: '400 m Course', scoreType: 'time', requiresEquipment: false),
  WodCatalogItem(id: 'max_pushups', name: 'Max pompes strictes (une série)', scoreType: 'reps', requiresEquipment: false),
  WodCatalogItem(id: 'max_air_squats', name: 'Max air squats (une série)', scoreType: 'reps', requiresEquipment: false),
  WodCatalogItem(id: 'max_air_squats_2min', name: 'Max air squats (2 min)', scoreType: 'reps', requiresEquipment: false),
  WodCatalogItem(id: 'burpees_7min', name: 'Test burpees (7 min)', scoreType: 'reps', requiresEquipment: false),
  WodCatalogItem(id: 'ergo_skill', name: 'Machine & Mur', scoreType: 'time', requiresEquipment: true),
];
