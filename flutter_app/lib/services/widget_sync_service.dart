import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'api_client.dart';

class WidgetSyncService {
  WidgetSyncService._();

  static const String appGroupId = 'group.com.wiredevelop.wireCrmApp.widgets';
  static const String summaryKey = 'wire_widget_summary';
  static const String updatedAtKey = 'wire_widget_updated_at';

  static const List<String> _iOSWidgetKinds = <String>[
    'WireWalletWidget',
    'WireBillingWidget',
    'WireStatsWidget',
    'WireModuleWidget',
  ];

  static const List<String> _androidWidgetProviders = <String>[
    'app.wiredevelop.pt.WalletCollectionWidgetProvider',
    'app.wiredevelop.pt.BillingOverviewWidgetProvider',
    'app.wiredevelop.pt.BillingPaidWidgetProvider',
    'app.wiredevelop.pt.BillingPendingWidgetProvider',
    'app.wiredevelop.pt.BillingTotalWidgetProvider',
    'app.wiredevelop.pt.BusinessStatsWidgetProvider',
    'app.wiredevelop.pt.MoreModulesWidgetProvider',
  ];

  static Future<void> configure() async {
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(appGroupId);
    }
  }

  static Future<void> sync(ApiClient client) async {
    try {
      await configure();

      final result = await client.get('/widgets/summary');
      final data =
          ((result['data'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{});
      final encoded = jsonEncode(data);

      await Future.wait<bool?>(<Future<bool?>>[
        HomeWidget.saveWidgetData<String>(summaryKey, encoded),
        HomeWidget.saveWidgetData<String>(
          updatedAtKey,
          DateTime.now().toUtc().toIso8601String(),
        ),
      ]);

      await _updateAll();
    } catch (error, stackTrace) {
      debugPrint('Widget sync failed: $error\n$stackTrace');
    }
  }

  static Future<void> clear() async {
    try {
      await configure();
      await Future.wait<bool?>(<Future<bool?>>[
        HomeWidget.saveWidgetData<String>(
          summaryKey,
          jsonEncode(<String, dynamic>{}),
        ),
        HomeWidget.saveWidgetData<String>(
          updatedAtKey,
          DateTime.now().toUtc().toIso8601String(),
        ),
      ]);
      await _updateAll();
    } catch (error, stackTrace) {
      debugPrint('Widget clear failed: $error\n$stackTrace');
    }
  }

  static Future<void> _updateAll() async {
    final futures = <Future<bool?>>[];

    for (final kind in _iOSWidgetKinds) {
      futures.add(HomeWidget.updateWidget(iOSName: kind));
    }

    if (Platform.isAndroid) {
      for (final provider in _androidWidgetProviders) {
        futures.add(HomeWidget.updateWidget(qualifiedAndroidName: provider));
      }
    }

    await Future.wait<bool?>(futures);
  }
}
