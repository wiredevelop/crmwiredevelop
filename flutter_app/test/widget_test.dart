import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wire_crm_app/widgets/ui.dart';

void main() {
  testWidgets('empty state renders message', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: EmptyState('Sem registos disponíveis'),
        ),
      ),
    );

    expect(find.text('Sem registos disponíveis'), findsOneWidget);
  });
}
