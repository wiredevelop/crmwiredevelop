package app.wiredevelop.pt

import android.content.Context
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale

data class WalletWidgetItem(
    val clientId: String,
    val clientName: String,
    val company: String?,
    val balanceSeconds: Int,
    val balanceAmount: Double,
    val deepLink: String,
)

data class BillingWidgetItem(
    val id: String,
    val label: String,
    val count: Int,
    val amount: Double,
    val deepLink: String,
)

data class StatsWidgetItem(
    val id: String,
    val label: String,
    val value: Int,
    val deepLink: String,
)

data class ModuleWidgetItem(
    val id: String,
    val label: String,
    val deepLink: String,
)

object WireWidgetData {
    private const val summaryKey = "wire_widget_summary"

    fun role(context: Context): String = root(context).optString("role", "guest")

    fun wallets(context: Context): List<WalletWidgetItem> =
        root(context)
            .optJSONObject("wallets")
            ?.optJSONArray("items")
            .toJsonObjects()
            .map { item ->
                WalletWidgetItem(
                    clientId = item.opt("client_id").toString(),
                    clientName = item.optString("client_name", "Cliente"),
                    company = item.optString("company").ifBlank { null },
                    balanceSeconds = item.optInt("balance_seconds", 0),
                    balanceAmount = item.optDouble("balance_amount", 0.0),
                    deepLink = item.optString("deep_link", "wirecrm://wallets"),
                )
            }

    fun billing(context: Context): List<BillingWidgetItem> =
        root(context)
            .optJSONArray("billing")
            .toJsonObjects()
            .map { item ->
                BillingWidgetItem(
                    id = item.optString("id", ""),
                    label = item.optString("label", "Indicador"),
                    count = item.optInt("count", 0),
                    amount = item.optDouble("amount", 0.0),
                    deepLink = item.optString("deep_link", "wirecrm://invoices"),
                )
            }

    fun stats(context: Context): List<StatsWidgetItem> =
        root(context)
            .optJSONArray("stats")
            .toJsonObjects()
            .map { item ->
                StatsWidgetItem(
                    id = item.optString("id", ""),
                    label = item.optString("label", "Indicador"),
                    value = item.optInt("value", 0),
                    deepLink = item.optString("deep_link", "wirecrm://projects"),
                )
            }

    fun modules(context: Context): List<ModuleWidgetItem> =
        root(context)
            .optJSONArray("more_modules")
            .toJsonObjects()
            .map { item ->
                ModuleWidgetItem(
                    id = item.optString("id", ""),
                    label = item.optString("label", "Módulo"),
                    deepLink = item.optString("deep_link", "wirecrm://more"),
                )
            }

    fun findBilling(context: Context, id: String): BillingWidgetItem? =
        billing(context).firstOrNull { it.id == id }

    fun formatHours(seconds: Int): String {
        val sign = if (seconds < 0) "-" else ""
        val absolute = kotlin.math.abs(seconds)
        val hours = absolute / 3600
        val minutes = (absolute % 3600) / 60
        return "$sign${hours}h ${minutes.toString().padLeft(2, '0')}m"
    }

    fun formatCurrency(amount: Double): String {
        val format = NumberFormat.getCurrencyInstance(Locale("pt", "PT"))
        return format.format(amount)
    }

    private fun root(context: Context): JSONObject {
        val prefs = HomeWidgetPlugin.getData(context)
        val raw = prefs.getString(summaryKey, null) ?: "{}"
        return try {
            JSONObject(raw)
        } catch (_: Exception) {
            JSONObject()
        }
    }

    private fun JSONArray?.toJsonObjects(): List<JSONObject> {
        if (this == null) {
            return emptyList()
        }

        return List(length()) { index -> optJSONObject(index) ?: JSONObject() }
    }
}
