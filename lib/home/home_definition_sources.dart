import 'package:cloud_firestore/cloud_firestore.dart';

/// Read-only global definitions. Subscription ownership stays in HomePage.
class HomeDefinitionSources {
  final Stream<QuerySnapshot<Map<String, dynamic>>> Function() categories;
  final Stream<QuerySnapshot<Map<String, dynamic>>> Function() backgrounds;
  final Stream<QuerySnapshot<Map<String, dynamic>>> Function() functions;

  const HomeDefinitionSources({
    required this.categories,
    required this.backgrounds,
    required this.functions,
  });

  factory HomeDefinitionSources.fromFirestore(FirebaseFirestore db) =>
      HomeDefinitionSources(
        categories: () => db.collection('locationCategories').snapshots(),
        backgrounds: () => db.collection('backgrounds').snapshots(),
        functions: () => db.collection('functions').snapshots(),
      );
}
