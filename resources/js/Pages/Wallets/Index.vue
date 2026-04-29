<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { Head, router, useForm } from '@inertiajs/vue3'
import { computed, ref, watch } from 'vue'

const props = defineProps({
    clients: Array,
    selectedClientId: [Number, String, null],
    selectedClient: Object,
    wallet: Object,
    transactions: Array,
    packs: Array,
    stripeAvailable: Boolean
})

const clientSelection = ref(props.selectedClientId ? String(props.selectedClientId) : '')

const packForm = useForm({
    client_id: clientSelection.value || '',
    product_id: props.packs?.[0]?.id || '',
    pack_item_id: '',
    quantity: 1
})

watch(
    () => packForm.product_id,
    (value) => {
        const items = props.packs?.find((pack) => String(pack.id) === String(value))?.pack_items || []
        packForm.pack_item_id = items[0]?.id ? String(items[0].id) : ''
    },
    { immediate: true }
)

const updateClient = () => {
    packForm.client_id = clientSelection.value || ''

    router.get('/wallets', {
        client_id: clientSelection.value || undefined
    }, {
        preserveState: true,
        replace: true,
        preserveScroll: true
    })
}

const submitPack = () => {
    packForm.post('/wallets/packs', {
        preserveScroll: true,
        onSuccess: () => packForm.reset('quantity')
    })
}

const submitStripePack = () => {
    packForm.post('/wallets/packs/stripe', {
        preserveScroll: true
    })
}

const formatHours = (seconds) => {
    if (seconds === null || seconds === undefined) return '—'
    const sign = seconds < 0 ? '-' : ''
    const abs = Math.abs(seconds)
    const hrs = Math.floor(abs / 3600)
    const mins = Math.floor((abs % 3600) / 60)
    const secs = abs % 60
    const base = `${sign}${hrs}h ${String(mins).padStart(2, '0')}m`
    return secs ? `${base} ${String(secs).padStart(2, '0')}s` : base
}

const formatAmount = (value) => {
    if (value === null || value === undefined) return '—'
    const amount = Number(value)
    const sign = amount < 0 ? '-' : ''
    const abs = Math.abs(amount)
    return `${sign}${abs.toLocaleString('pt-PT', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} €`
}

const pendingHoursLabel = (tx) => {
    const payment = tx?.payment_metadata || {}
    const packItem = tx?.pack_item || null
    const quantity = Number(payment?.quantity || 1)

    if (tx?.payment_provider !== 'stripe' || payment?.status !== 'pending' || !packItem?.hours) {
        return null
    }

    const totalHours = Number(packItem.hours) * Math.max(quantity, 1)
    return `Pendente (+${totalHours}h)`
}

const balanceHours = computed(() => formatHours(props.wallet?.balance_seconds ?? 0))
const balanceAmount = computed(() => formatAmount(props.wallet?.balance_amount ?? 0))

const typeLabel = (type) => {
    if (type === 'purchase') return 'Compra'
    if (type === 'expense') return 'Gasto'
    if (type === 'usage') return 'Consumo'
    return 'Ajuste'
}

const selectedPack = computed(() =>
    props.packs?.find((pack) => String(pack.id) === String(packForm.product_id)) || null
)

const selectedPackItems = computed(() => selectedPack.value?.pack_items || [])

const selectedPackItem = computed(() =>
    selectedPackItems.value.find((item) => String(item.id) === String(packForm.pack_item_id)) || null
)

const deleteTransaction = (tx) => {
    if (!confirm('Queres apagar esta transação?')) {
        return
    }

    router.delete(`/wallets/transactions/${tx.id}`, {
        preserveScroll: true,
        onSuccess: () => {
            router.reload({ only: ['wallet', 'transactions'] })
        }
    })
}
</script>

<template>
    <Head title="Carteiras" />

    <BaseLayout>
        <template #title>Carteiras</template>

        <div class="space-y-6">
            <div class="bg-white rounded shadow p-6">
                <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                    <div>
                        <h2 class="text-lg font-semibold">Carteira do cliente</h2>
                        <p class="text-sm text-gray-500">Consulta saldo e regista transações.</p>
                    </div>

                    <div class="w-full md:w-80">
                        <select v-model="clientSelection" @change="updateClient"
                            class="w-full border rounded px-3 py-2 text-sm">
                            <option value="">Selecionar cliente</option>
                            <option v-for="client in clients" :key="client.id" :value="String(client.id)">
                                {{ client.name }} <span v-if="client.company">({{ client.company }})</span>
                            </option>
                        </select>
                    </div>
                </div>
            </div>

            <div v-if="!selectedClientId" class="text-sm text-gray-500">Seleciona um cliente para gerir a carteira.</div>

            <div v-else class="grid grid-cols-1 lg:grid-cols-3 gap-6">
                <div class="bg-white rounded shadow p-6 space-y-4">
                    <div>
                        <h3 class="text-base font-semibold">Saldo</h3>
                        <p class="text-sm text-gray-500">{{ selectedClient?.name }}</p>
                    </div>

                    <div class="space-y-2">
                        <div class="flex items-center justify-between text-sm">
                            <span class="text-gray-500">Horas</span>
                            <span class="font-semibold">{{ balanceHours }}</span>
                        </div>
                        <div class="flex items-center justify-between text-sm">
                            <span class="text-gray-500">Valor</span>
                            <span class="font-semibold">{{ balanceAmount }}</span>
                        </div>
                    </div>

                    <div class="border-t pt-4">
                        <h4 class="text-sm font-semibold mb-3">Compra de pack</h4>
                        <p v-if="!packs?.length" class="text-xs text-gray-500">Sem packs disponíveis.</p>

                        <div v-else class="space-y-3">
                            <div>
                                <label class="block text-xs font-medium text-gray-600 mb-1">Pack</label>
                                <select v-model="packForm.product_id" class="w-full border rounded px-3 py-2 text-sm">
                                    <option v-for="pack in packs" :key="pack.id" :value="pack.id">
                                        {{ pack.name }}
                                    </option>
                                </select>
                            </div>

                            <div>
                                <label class="block text-xs font-medium text-gray-600 mb-1">Opção</label>
                                <select v-model="packForm.pack_item_id" class="w-full border rounded px-3 py-2 text-sm">
                                    <option v-for="item in selectedPackItems" :key="item.id" :value="item.id">
                                        {{ item.hours }}h • {{ formatAmount(item.pack_price) }}
                                    </option>
                                </select>
                            </div>

                            <div>
                                <label class="block text-xs font-medium text-gray-600 mb-1">Quantidade</label>
                                <input v-model.number="packForm.quantity" type="number" min="1" step="1"
                                    class="w-full border rounded px-3 py-2 text-sm" />
                            </div>

                            <div v-if="selectedPackItem" class="border rounded p-3 text-xs bg-gray-50">
                                <div class="flex items-center justify-between">
                                    <span class="text-gray-500">Horas incluídas</span>
                                    <span class="font-medium">{{ selectedPackItem.hours }}h</span>
                                </div>
                                <div class="flex items-center justify-between">
                                    <span class="text-gray-500">Preço pack</span>
                                    <span class="font-medium">{{ formatAmount(selectedPackItem.pack_price) }}</span>
                                </div>
                                <div class="flex items-center justify-between">
                                    <span class="text-gray-500">Validade</span>
                                    <span class="font-medium">{{ selectedPackItem.validity_months }} meses</span>
                                </div>
                            </div>

                            <button type="button" @click="submitPack"
                                class="w-full bg-[#015557] text-white px-4 py-2 rounded hover:bg-[#014548] disabled:opacity-50"
                                :disabled="packForm.processing || !packForm.client_id || !packForm.product_id || !packForm.pack_item_id">
                                Registar compra manual
                            </button>
                            <button type="button" @click="submitStripePack"
                                class="w-full border border-[#015557] text-[#015557] px-4 py-2 rounded hover:bg-[#015557]/5 disabled:opacity-50"
                                :disabled="packForm.processing || !stripeAvailable || !packForm.client_id || !packForm.product_id || !packForm.pack_item_id">
                                {{ stripeAvailable ? 'Stripe' : 'Stripe indisponível' }}
                            </button>
                        </div>
                    </div>
                </div>

                <div class="bg-white rounded shadow p-6 lg:col-span-2">
                    <h3 class="text-base font-semibold mb-4">Transações</h3>

                    <p v-if="!transactions.length" class="text-sm text-gray-500">Sem transações registadas.</p>

                    <div v-else class="overflow-x-auto">
                        <table class="w-full text-sm text-left">
                            <thead>
                                <tr class="bg-gray-50 border-b">
                                    <th class="py-2 px-2">Data</th>
                                    <th class="py-2 px-2">Tipo</th>
                                    <th class="py-2 px-2">Descrição</th>
                                    <th class="py-2 px-2">Horas</th>
                                    <th class="py-2 px-2">Valor</th>
                                    <th class="py-2 px-2 text-right">Ações</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr v-for="tx in transactions" :key="tx.id" class="border-b">
                                    <td class="py-2 px-2">{{ new Date(tx.transaction_at).toLocaleDateString('pt-PT') }}</td>
                                    <td class="py-2 px-2">{{ typeLabel(tx.type) }}</td>
                                    <td class="py-2 px-2">
                                        <div class="font-medium">
                                            {{ tx.description || tx.product?.name || '—' }}
                                        </div>
                                        <div v-if="tx.product && tx.pack_item" class="text-xs text-gray-500">
                                            Pack: {{ tx.product.name }} • {{ tx.pack_item.hours }}h
                                        </div>
                                        <div v-if="tx.intervention" class="text-xs text-gray-500">
                                            Intervenção: {{ tx.intervention.type }}
                                        </div>
                                        <div v-if="tx.invoice" class="text-xs text-gray-500">
                                            Documento: {{ tx.invoice.number }} · {{ tx.invoice.status }}
                                        </div>
                                    </td>
                                    <td class="py-2 px-2 font-mono">{{ pendingHoursLabel(tx) || formatHours(tx.seconds) }}</td>
                                    <td class="py-2 px-2">{{ formatAmount(tx.amount) }}</td>
                                    <td class="py-2 px-2 text-right">
                                        <button
                                            type="button"
                                            class="text-xs text-red-600 hover:underline"
                                            @click="deleteTransaction(tx)"
                                        >
                                            Apagar
                                        </button>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </BaseLayout>
</template>
