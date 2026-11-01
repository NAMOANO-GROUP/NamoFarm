import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namofarm/screens/crm/crm_common.dart';

void main() {
  testWidgets('Un message avec bouton (Annuler, Consigner) disparaît tout seul', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCrmSnack(
              context,
              'Pensez à consigner cet échange',
              action: SnackBarAction(label: 'Consigner', onPressed: () {}),
            ),
            child: const Text('Appeler'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Appeler'));
    await tester.pumpAndSettle();
    expect(find.text('Pensez à consigner cet échange'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('Pensez à consigner cet échange'), findsNothing);
  });
}
