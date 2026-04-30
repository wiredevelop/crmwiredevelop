package app.wiredevelop.pt

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class WalletCollectionWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val adapterIntent =
                Intent(context, WidgetCollectionService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    putExtra(EXTRA_COLLECTION_TYPE, COLLECTION_WALLETS)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }

            val views = RemoteViews(context.packageName, R.layout.widget_wallet_collection).apply {
                setTextViewText(
                    R.id.widget_header,
                    if (WireWidgetData.role(context) == "client") "Carteira" else "Carteiras",
                )
                setRemoteAdapter(R.id.widget_list, adapterIntent)
                setEmptyView(R.id.widget_list, R.id.widget_empty)
                setPendingIntentTemplate(
                    R.id.widget_list,
                    launchIntent(context),
                )
                setOnClickPendingIntent(R.id.widget_header, launchIntent(context, "wirecrm://wallets"))
            }

            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
        }
    }
}

class BillingOverviewWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val adapterIntent =
                Intent(context, WidgetCollectionService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    putExtra(EXTRA_COLLECTION_TYPE, COLLECTION_BILLING)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }

            val views = RemoteViews(context.packageName, R.layout.widget_billing_overview).apply {
                setTextViewText(R.id.widget_header, "Faturação")
                setRemoteAdapter(R.id.widget_list, adapterIntent)
                setEmptyView(R.id.widget_list, R.id.widget_empty)
                setPendingIntentTemplate(R.id.widget_list, launchIntent(context))
                setOnClickPendingIntent(R.id.widget_header, launchIntent(context, "wirecrm://invoices"))
            }

            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
        }
    }
}

class BillingPaidWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) = updateBillingStatusWidget(context, appWidgetManager, appWidgetIds, "paid")
}

class BillingPendingWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) = updateBillingStatusWidget(context, appWidgetManager, appWidgetIds, "pending")
}

class BillingTotalWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) = updateBillingStatusWidget(context, appWidgetManager, appWidgetIds, "all")
}

class BusinessStatsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val stats = WireWidgetData.stats(context)
        val first = stats.getOrNull(0)
        val second = stats.getOrNull(1)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_business_stats).apply {
                setTextViewText(R.id.widget_title, "Indicadores")
                setTextViewText(R.id.widget_primary_label, first?.label ?: "Sem dados")
                setTextViewText(R.id.widget_primary_value, (first?.value ?: 0).toString())
                setTextViewText(R.id.widget_secondary_label, second?.label ?: "—")
                setTextViewText(R.id.widget_secondary_value, (second?.value ?: 0).toString())
                setOnClickPendingIntent(
                    R.id.widget_primary_card,
                    launchIntent(context, first?.deepLink ?: "wirecrm://clients"),
                )
                setOnClickPendingIntent(
                    R.id.widget_secondary_card,
                    launchIntent(context, second?.deepLink ?: "wirecrm://projects"),
                )
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class MoreModulesWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val adapterIntent =
                Intent(context, WidgetCollectionService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    putExtra(EXTRA_COLLECTION_TYPE, COLLECTION_MODULES)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }

            val views = RemoteViews(context.packageName, R.layout.widget_more_modules).apply {
                setTextViewText(R.id.widget_header, "Módulos")
                setRemoteAdapter(R.id.widget_list, adapterIntent)
                setEmptyView(R.id.widget_list, R.id.widget_empty)
                setPendingIntentTemplate(R.id.widget_list, launchIntent(context))
                setOnClickPendingIntent(R.id.widget_header, launchIntent(context, "wirecrm://more"))
            }

            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
        }
    }
}

private fun updateBillingStatusWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
    billingId: String,
) {
    val item = WireWidgetData.findBilling(context, billingId)

    appWidgetIds.forEach { widgetId ->
        val views = RemoteViews(context.packageName, R.layout.widget_billing_status).apply {
            setTextViewText(R.id.widget_title, item?.label ?: "Faturação")
            setTextViewText(R.id.widget_value, WireWidgetData.formatCurrency(item?.amount ?: 0.0))
            setTextViewText(R.id.widget_meta, "${item?.count ?: 0} documentos")
            setOnClickPendingIntent(
                R.id.widget_container,
                launchIntent(context, item?.deepLink ?: "wirecrm://invoices"),
            )
        }

        appWidgetManager.updateAppWidget(widgetId, views)
    }
}

private fun launchIntent(
    context: Context,
    deepLink: String? = null,
): PendingIntent =
    HomeWidgetLaunchIntent.getActivity(
        context,
        MainActivity::class.java,
        deepLink?.let(Uri::parse),
    )
