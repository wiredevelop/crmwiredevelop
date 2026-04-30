package app.wiredevelop.pt

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetLaunchIntent

const val EXTRA_COLLECTION_TYPE = "collection_type"
const val COLLECTION_WALLETS = "wallets"
const val COLLECTION_BILLING = "billing"
const val COLLECTION_MODULES = "modules"

class WidgetCollectionService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return WireCollectionFactory(applicationContext, intent)
    }
}

private data class CollectionRow(
    val title: String,
    val subtitle: String,
    val meta: String,
    val deepLink: String,
)

private class WireCollectionFactory(
    private val context: Context,
    intent: Intent,
) : RemoteViewsService.RemoteViewsFactory {
    private val collectionType =
        intent.getStringExtra(EXTRA_COLLECTION_TYPE) ?: COLLECTION_WALLETS
    private val rows = mutableListOf<CollectionRow>()

    override fun onCreate() = Unit

    override fun onDataSetChanged() {
        rows.clear()
        rows += when (collectionType) {
            COLLECTION_BILLING ->
                WireWidgetData.billing(context).map { item ->
                    CollectionRow(
                        title = item.label,
                        subtitle = "${item.count} documentos",
                        meta = WireWidgetData.formatCurrency(item.amount),
                        deepLink = item.deepLink,
                    )
                }

            COLLECTION_MODULES ->
                WireWidgetData.modules(context).map { item ->
                    CollectionRow(
                        title = item.label,
                        subtitle = "Abrir módulo",
                        meta = "",
                        deepLink = item.deepLink,
                    )
                }

            else ->
                WireWidgetData.wallets(context).map { item ->
                    CollectionRow(
                        title = item.clientName,
                        subtitle = item.company ?: "Carteira",
                        meta =
                            "${WireWidgetData.formatHours(item.balanceSeconds)} · " +
                                WireWidgetData.formatCurrency(item.balanceAmount),
                        deepLink = item.deepLink,
                    )
                }
        }
    }

    override fun onDestroy() = rows.clear()

    override fun getCount(): Int = rows.size

    override fun getViewAt(position: Int): RemoteViews {
        val row = rows.getOrNull(position) ?: return RemoteViews(context.packageName, R.layout.widget_collection_item)
        return RemoteViews(context.packageName, R.layout.widget_collection_item).apply {
            setTextViewText(R.id.widget_item_title, row.title)
            setTextViewText(R.id.widget_item_subtitle, row.subtitle)
            setTextViewText(R.id.widget_item_meta, row.meta)

            val fillInIntent = Intent().apply {
                data = Uri.parse(row.deepLink)
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            }
            setOnClickFillInIntent(R.id.widget_item_container, fillInIntent)
        }
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
