import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:house_rent/models/house.dart';
import 'package:house_rent/services/session_recommendation.dart';

void main() {
  test('strong session intent reranks similar unseen homes', () {
    final session = SessionRecommendation.instance..reset();
    final engaged = House('Engaged', 'Lusaka', '',
        id: 1, areaId: 10, type: 'Apartment', bedrooms: 2, priceRental: 6000);
    final similar = House('Similar', 'Lusaka', '',
        id: 2, areaId: 10, type: 'Apartment', bedrooms: 2, priceRental: 6500);
    final formerLeader = House('Former leader', 'Ndola', '',
        id: 3,
        areaId: 20,
        type: 'House',
        bedrooms: 4,
        priceRental: 15000,
        recommendationScore: 30);

    session.observe(engaged, 4);
    final ranked = session.rank([formerLeader, similar]);

    expect(ranked.first.id, similar.id);
    session.reset();
  });

  testWidgets('session learning never notifies listeners during build',
      (tester) async {
    final session = SessionRecommendation.instance..reset();
    final house = House('Home', 'Lusaka', '', id: 7, areaId: 2);
    var observed = false;
    await tester.pumpWidget(MaterialApp(
      home: AnimatedBuilder(
        animation: session,
        builder: (_, __) {
          if (!observed) {
            observed = true;
            session.observe(house, 1);
          }
          return const SizedBox();
        },
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    session.reset();
  });
}
