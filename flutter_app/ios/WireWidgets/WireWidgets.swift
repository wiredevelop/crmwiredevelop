import SwiftUI
import WidgetKit

private let widgetGroupId = "group.com.wiredevelop.wirecrmapp.widgets"
private let widgetSummaryKey = "wire_widget_summary"

struct WireWidgetPayload: Decodable {
  struct WalletSection: Decodable {
    let mode: String?
    let items: [WalletItem]
  }

  struct WalletItem: Decodable, Identifiable, Hashable {
    let client_id: Int
    let client_name: String
    let company: String?
    let balance_seconds: Int
    let balance_amount: Double
    let deep_link: String

    var id: String { String(client_id) }
  }

  struct BillingItem: Decodable, Identifiable, Hashable {
    let id: String
    let label: String
    let status: String
    let count: Int
    let amount: Double
    let deep_link: String
  }

  struct StatItem: Decodable, Identifiable, Hashable {
    let id: String
    let label: String
    let value: Int
    let deep_link: String
  }

  struct ModuleItem: Decodable, Identifiable, Hashable {
    let id: String
    let label: String
    let deep_link: String
  }

  let role: String?
  let stats: [StatItem]
  let billing: [BillingItem]
  let wallets: WalletSection?
  let more_modules: [ModuleItem]

  static func load() -> WireWidgetPayload {
    let defaults = UserDefaults(suiteName: widgetGroupId)
    guard
      let raw = defaults?.string(forKey: widgetSummaryKey),
      let data = raw.data(using: .utf8),
      let decoded = try? JSONDecoder().decode(WireWidgetPayload.self, from: data)
    else {
      return WireWidgetPayload(
        role: "guest",
        stats: [],
        billing: [],
        wallets: nil,
        more_modules: []
      )
    }

    return decoded
  }
}

struct WalletEntry: TimelineEntry {
  let date: Date
  let wallet: WireWidgetPayload.WalletItem?
}

struct BillingEntry: TimelineEntry {
  let date: Date
  let item: WireWidgetPayload.BillingItem?
}

struct StatsEntry: TimelineEntry {
  let date: Date
  let stats: [WireWidgetPayload.StatItem]
}

struct ModuleEntry: TimelineEntry {
  let date: Date
  let module: WireWidgetPayload.ModuleItem?
}

struct WalletProvider: TimelineProvider {
  func placeholder(in context: Context) -> WalletEntry {
    WalletEntry(date: .now, wallet: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (WalletEntry) -> Void) {
    completion(WalletEntry(date: .now, wallet: defaultWallet()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<WalletEntry>) -> Void) {
    let entry = WalletEntry(date: .now, wallet: defaultWallet())
    completion(Timeline(entries: [entry], policy: .never))
  }

  private func defaultWallet() -> WireWidgetPayload.WalletItem? {
    WireWidgetPayload.load().wallets?.items.first
  }
}

struct BillingProvider: TimelineProvider {
  func placeholder(in context: Context) -> BillingEntry {
    BillingEntry(date: .now, item: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (BillingEntry) -> Void) {
    completion(BillingEntry(date: .now, item: defaultBilling()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BillingEntry>) -> Void) {
    let entry = BillingEntry(date: .now, item: defaultBilling())
    completion(Timeline(entries: [entry], policy: .never))
  }

  private func defaultBilling() -> WireWidgetPayload.BillingItem? {
    let items = WireWidgetPayload.load().billing
    return items.first(where: { $0.id == "all" }) ?? items.first
  }
}

struct StatsProvider: TimelineProvider {
  func placeholder(in context: Context) -> StatsEntry {
    StatsEntry(date: .now, stats: [])
  }

  func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
    completion(StatsEntry(date: .now, stats: WireWidgetPayload.load().stats))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
    let entry = StatsEntry(date: .now, stats: WireWidgetPayload.load().stats)
    completion(Timeline(entries: [entry], policy: .never))
  }
}

struct ModuleProvider: TimelineProvider {
  func placeholder(in context: Context) -> ModuleEntry {
    ModuleEntry(date: .now, module: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (ModuleEntry) -> Void) {
    completion(ModuleEntry(date: .now, module: defaultModule()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ModuleEntry>) -> Void) {
    let entry = ModuleEntry(date: .now, module: defaultModule())
    completion(Timeline(entries: [entry], policy: .never))
  }

  private func defaultModule() -> WireWidgetPayload.ModuleItem? {
    WireWidgetPayload.load().more_modules.first
  }
}

struct WalletWidgetView: View {
  let entry: WalletEntry

  var body: some View {
    let wallet = entry.wallet
    VStack(alignment: .leading, spacing: 8) {
      Text("Carteira")
        .font(.caption)
        .foregroundColor(.secondary)
      Text(wallet?.client_name ?? "Sem dados")
        .font(.headline)
      Text(formatHours(wallet?.balance_seconds ?? 0))
        .font(.title3.bold())
      Text(formatCurrency(wallet?.balance_amount ?? 0))
        .font(.subheadline.weight(.semibold))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .wireWidgetBackground()
    .widgetURL(wallet.flatMap { URL(string: $0.deep_link) })
  }
}

struct BillingWidgetView: View {
  let entry: BillingEntry

  var body: some View {
    let item = entry.item
    VStack(alignment: .leading, spacing: 8) {
      Text(item?.label ?? "Faturação")
        .font(.caption)
        .foregroundColor(.secondary)
      Text(formatCurrency(item?.amount ?? 0))
        .font(.title3.bold())
      Text("\(item?.count ?? 0) documentos")
        .font(.subheadline)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .wireWidgetBackground()
    .widgetURL(item.flatMap { URL(string: $0.deep_link) })
  }
}

struct StatsWidgetView: View {
  let entry: StatsEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Indicadores")
        .font(.caption)
        .foregroundColor(.secondary)

      ForEach(Array(entry.stats.prefix(2))) { item in
        HStack {
          Text(item.label)
            .font(.subheadline)
          Spacer()
          Text("\(item.value)")
            .font(.headline)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .wireWidgetBackground()
    .widgetURL(URL(string: entry.stats.first?.deep_link ?? "wirecrm://projects"))
  }
}

struct ModuleWidgetView: View {
  let entry: ModuleEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Módulo")
        .font(.caption)
        .foregroundColor(.secondary)
      Text(entry.module?.label ?? "Mais")
        .font(.title3.bold())
      Text("Abrir na app")
        .font(.subheadline)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .wireWidgetBackground()
    .widgetURL(URL(string: entry.module?.deep_link ?? "wirecrm://more"))
  }
}

struct WireWalletWidget: Widget {
  let kind = "WireWalletWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: WalletProvider()) { entry in
      WalletWidgetView(entry: entry)
    }
    .configurationDisplayName("Carteira")
    .description("Mostra uma carteira do CRM.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct WireBillingWidget: Widget {
  let kind = "WireBillingWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: BillingProvider()) { entry in
      BillingWidgetView(entry: entry)
    }
    .configurationDisplayName("Faturação")
    .description("Mostra um indicador de faturação.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct WireStatsWidget: Widget {
  let kind = "WireStatsWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StatsProvider()) { entry in
      StatsWidgetView(entry: entry)
    }
    .configurationDisplayName("Indicadores")
    .description("Clientes e projetos ativos.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct WireModuleWidget: Widget {
  let kind = "WireModuleWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ModuleProvider()) { entry in
      ModuleWidgetView(entry: entry)
    }
    .configurationDisplayName("Módulo")
    .description("Atalho para um módulo da aba Mais.")
    .supportedFamilies([.systemSmall])
  }
}

@main
struct WireWidgetsBundle: WidgetBundle {
  var body: some Widget {
    WireWalletWidget()
    WireBillingWidget()
    WireStatsWidget()
    WireModuleWidget()
  }
}

private func formatCurrency(_ amount: Double) -> String {
  let formatter = NumberFormatter()
  formatter.locale = Locale(identifier: "pt_PT")
  formatter.numberStyle = .currency
  return formatter.string(from: NSNumber(value: amount)) ?? "0,00 €"
}

private func formatHours(_ seconds: Int) -> String {
  let absolute = abs(seconds)
  let hours = absolute / 3600
  let minutes = (absolute % 3600) / 60
  let prefix = seconds < 0 ? "-" : ""
  return "\(prefix)\(hours)h \(String(format: "%02d", minutes))m"
}

private extension View {
  @ViewBuilder
  func wireWidgetBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      self.containerBackground(.background, for: .widget)
    } else {
      self
        .padding(12)
        .background(Color(.systemBackground))
    }
  }
}
