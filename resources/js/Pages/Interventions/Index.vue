<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { Head, router, useForm } from '@inertiajs/vue3'
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'

const props = defineProps({
    clients: Array,
    interventions: Array,
    selectedClientId: [Number, String, null],
    selectedTab: String,
    types: Array,
    selectedClient: Object,
    wallet: Object,
    transactions: Array,
    packs: Array
})

const tabs = [
    { id: 'pack', label: 'Manutenções de packs' },
    { id: 'no-pack', label: 'Manutenções sem packs' }
]

const resolveInitialTab = () => {
    if (props.selectedClientId) {
        const match = props.clients?.find((client) =>
            String(client.id) === String(props.selectedClientId)
        )
        if (match) {
            return match.has_active_pack ? 'pack' : 'no-pack'
        }
    }

    if (props.selectedTab === 'pack' || props.selectedTab === 'no-pack') {
        return props.selectedTab
    }

    return 'pack'
}

const activeTab = ref(resolveInitialTab())

const packClients = computed(() =>
    (props.clients || []).filter((client) => client.has_active_pack)
)

const nonPackClients = computed(() =>
    (props.clients || []).filter((client) => !client.has_active_pack)
)

const filteredClients = computed(() =>
    activeTab.value === 'pack' ? packClients.value : nonPackClients.value
)

const allowedClientIds = computed(() =>
    new Set(filteredClients.value.map((client) => String(client.id)))
)

const clientSelection = ref(props.selectedClientId ? String(props.selectedClientId) : '')

const filteredInterventions = computed(() => props.interventions || [])

const selectedClientMeta = computed(() =>
    (props.clients || []).find((client) => String(client.id) === String(clientSelection.value)) || null
)

const form = useForm({
    client_id: clientSelection.value || '',
    type: props.types?.[0] || 'Manutenção',
    notes: '',
    is_pack: activeTab.value === 'pack',
    hourly_rate: ''
})

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

const now = ref(Date.now())
let timer = null

const syncQuery = () => {
    router.get('/interventions', {
        client_id: clientSelection.value || undefined,
        tab: activeTab.value
    }, {
        preserveState: true,
        replace: true,
        preserveScroll: true
    })
}

const syncClientSelection = () => {
    if (clientSelection.value && !allowedClientIds.value.has(clientSelection.value)) {
        clientSelection.value = ''
    }

    form.client_id = clientSelection.value || ''
    packForm.client_id = clientSelection.value || ''
}

const syncHourlyRate = () => {
    if (activeTab.value !== 'no-pack') {
        form.hourly_rate = ''
        return
    }

    const rate = selectedClientMeta.value?.hourly_rate
    form.hourly_rate = rate !== null && rate !== undefined ? Number(rate) : ''
}

onMounted(() => {
    timer = setInterval(() => {
        now.value = Date.now()
    }, 1000)
})

onUnmounted(() => {
    if (timer) clearInterval(timer)
})

watch([packClients, nonPackClients], () => {
    if (activeTab.value === 'pack' && !packClients.value.length && nonPackClients.value.length) {
        activeTab.value = 'no-pack'
    }
    if (activeTab.value === 'no-pack' && !nonPackClients.value.length && packClients.value.length) {
        activeTab.value = 'pack'
    }
}, { immediate: true })

watch(filteredClients, () => {
    syncClientSelection()
}, { immediate: true })

watch([() => clientSelection.value, () => activeTab.value], () => {
    form.is_pack = activeTab.value === 'pack'
    syncHourlyRate()
}, { immediate: true })

const setTab = (tabId) => {
    if (activeTab.value === tabId) return
    activeTab.value = tabId
    syncClientSelection()
    syncQuery()
}

const updateClient = () => {
    syncClientSelection()
    syncQuery()
}

const submit = () => {
    form.is_pack = activeTab.value === 'pack'
    if (!form.is_pack && (form.hourly_rate === '' || form.hourly_rate === null || form.hourly_rate === undefined)) {
        alert('Indica o valor/hora.')
        return
    }
    form.post('/interventions', {
        preserveScroll: true,
        onSuccess: () => form.reset('notes')
    })
}

const submitPack = () => {
    packForm.post('/wallets/packs', {
        preserveScroll: true,
        onSuccess: () => packForm.reset('quantity')
    })
}

const pause = (item) => {
    router.post(`/interventions/${item.id}/pause`, {}, { preserveScroll: true })
}

const resume = (item) => {
    router.post(`/interventions/${item.id}/resume`, {}, { preserveScroll: true })
}

const finish = (item) => {
    if (!confirm('Concluir intervenção?')) return
    const finishNotes = prompt('Notas para o fecho da intervencao (opcional):')
    if (finishNotes === null) return
    const endInput = prompt('Hora de fim (YYYY-MM-DD HH:MM) opcional. Deixa vazio para não alterar:')
    if (endInput === null) return
    let durationInput = null
    if (!endInput.trim()) {
        const rawDurationInput = prompt('Duração (hh:mm:ss) opcional:')
        if (rawDurationInput === null) return
        if (rawDurationInput.trim()) {
            if (!/^\d{1,3}:\d{2}:\d{2}$/.test(rawDurationInput.trim())) {
                alert('Indica uma duração válida no formato hh:mm:ss.')
                return
            }
            durationInput = rawDurationInput.trim()
        }
    }
    router.post(`/interventions/${item.id}/finish`, {
        finish_notes: finishNotes.trim() || null,
        ended_at: endInput.trim() || null,
        duration_input: durationInput
    }, { preserveScroll: true })
}

const formatDateTime = (value) => {
    if (!value) return '—'
    return new Date(value).toLocaleString('pt-PT')
}

const formatDuration = (seconds) => {
    const safe = Math.max(0, seconds)
    const hrs = Math.floor(safe / 3600)
    const mins = Math.floor((safe % 3600) / 60)
    const secs = Math.floor(safe % 60)
    return `${String(hrs).padStart(2, '0')}:${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`
}

const durationSeconds = (item) => {
    if (!item?.started_at) return 0
    const start = new Date(item.started_at).getTime()
    const pausedTotal = item.total_paused_seconds || 0

    if (item.status === 'completed') {
        return item.total_seconds || 0
    }

    if (item.status === 'paused') {
        const pausedAt = item.paused_at ? new Date(item.paused_at).getTime() : now.value
        return Math.max(0, Math.floor((pausedAt - start) / 1000) - pausedTotal)
    }

    return Math.max(0, Math.floor((now.value - start) / 1000) - pausedTotal)
}

const statusClass = (status) => {
    if (status === 'running') return 'bg-green-100 text-green-700'
    if (status === 'paused') return 'bg-yellow-100 text-yellow-700'
    return 'bg-gray-100 text-gray-700'
}

const statusLabel = (status) => {
    if (status === 'running') return 'Em curso'
    if (status === 'paused') return 'Em pausa'
    return 'Concluída'
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

const walletTransactions = computed(() => props.transactions || [])
</script>

<template>
    <Head title="Intervenções" />

    <BaseLayout>
        <template #title>Intervenções</template>

        <div class="mb-6 flex flex-wrap gap-2">
            <button
                v-for="tab in tabs"
                :key="tab.id"
                type="button"
                class="px-4 py-2 rounded border text-sm transition"
                :class="activeTab === tab.id ? 'bg-[#015557] text-white border-[#015557]' : 'bg-white text-gray-600'"
                @click="setTab(tab.id)"
            >
                {{ tab.label }}
            </button>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <div class="bg-white rounded shadow p-6 lg:col-span-1 space-y-4">
                <div>
                    <h2 class="text-lg font-semibold">Nova intervenção</h2>
                    <p class="text-sm text-gray-500">Escolhe o cliente e inicia a contagem.</p>
                </div>

                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Cliente</label>
                    <select v-model="clientSelection" @change="updateClient"
                        class="w-full border rounded px-3 py-2 text-sm">
                        <option value="">Selecionar cliente</option>
                        <option v-for="client in filteredClients" :key="client.id" :value="String(client.id)">
                            {{ client.name }} <span v-if="client.company">({{ client.company }})</span>
                        </option>
                    </select>
                </div>

                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Tipo de intervenção</label>
                    <input v-model="form.type" list="intervention-types"
                        class="w-full border rounded px-3 py-2 text-sm" placeholder="Ex: Manutenção" />
                    <datalist id="intervention-types">
                        <option v-for="type in types" :key="type" :value="type" />
                    </datalist>
                </div>

                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Notas</label>
                    <textarea v-model="form.notes" rows="3" class="w-full border rounded px-3 py-2 text-sm"
                        placeholder="Detalhes da intervenção"></textarea>
                </div>

                <div v-if="activeTab === 'no-pack' && form.client_id">
                    <label class="block text-sm font-medium text-gray-700 mb-1">Valor/hora</label>
                    <input
                        v-model.number="form.hourly_rate"
                        type="number"
                        min="0"
                        step="0.01"
                        class="w-full border rounded px-3 py-2 text-sm"
                        placeholder="Ex: 45,00"
                    />
                </div>

                <button type="button" @click="submit"
                    class="w-full bg-[#015557] text-white px-4 py-2 rounded hover:bg-[#014548] disabled:opacity-50"
                    :disabled="form.processing || !form.client_id || !form.type
                        || (activeTab === 'no-pack' && (form.hourly_rate === '' || form.hourly_rate === null || form.hourly_rate === undefined))">
                    Iniciar intervenção
                </button>
            </div>

            <div class="bg-white rounded shadow p-6 lg:col-span-2 space-y-4">
                <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                        <h2 class="text-lg font-semibold">Registos recentes</h2>
                        <p class="text-sm text-gray-500">Pausar, retomar ou concluir intervenções.</p>
                    </div>
                </div>

                <p v-if="!filteredInterventions.length" class="text-sm text-gray-500">Sem intervenções para mostrar.</p>

                <div v-else class="overflow-x-auto">
                    <table class="w-full text-sm text-left">
                        <thead>
                            <tr class="bg-gray-50 border-b">
                                <th class="py-2 px-2">Cliente</th>
                                <th class="py-2 px-2">Tipo</th>
                                <th class="py-2 px-2">Estado</th>
                                <th class="py-2 px-2">Início</th>
                                <th class="py-2 px-2">Fim</th>
                                <th class="py-2 px-2">Tempo</th>
                                <th class="py-2 px-2 text-right">Ações</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="item in filteredInterventions" :key="item.id" class="border-b">
                                <td class="py-2 px-2">
                                    {{ item.client?.name || '—' }}
                                </td>
                                <td class="py-2 px-2">
                                    <div class="flex items-center gap-2">
                                        <span
                                            class="px-2 py-0.5 text-xs font-semibold rounded-full"
                                            :class="item.is_pack ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'"
                                        >
                                            PACK
                                        </span>
                                        <div class="font-medium">{{ item.type }}</div>
                                    </div>
                                    <div v-if="item.notes" class="text-xs text-gray-500">Notas inicio: {{ item.notes }}</div>
                                    <div v-if="item.finish_notes" class="text-xs text-gray-500">Notas fim: {{ item.finish_notes }}</div>
                                </td>
                                <td class="py-2 px-2">
                                    <span class="px-2 py-1 text-xs rounded-full" :class="statusClass(item.status)">
                                        {{ statusLabel(item.status) }}
                                    </span>
                                </td>
                                <td class="py-2 px-2">{{ formatDateTime(item.started_at) }}</td>
                                <td class="py-2 px-2">{{ formatDateTime(item.ended_at) }}</td>
                                <td class="py-2 px-2 font-mono">{{ formatDuration(durationSeconds(item)) }}</td>
                                <td class="py-2 px-2">
                                    <div class="flex justify-end gap-2">
                                        <button v-if="item.status === 'running'" type="button" @click="pause(item)"
                                            class="px-3 py-1 text-xs rounded border">Pausar</button>
                                        <button v-if="item.status === 'paused'" type="button" @click="resume(item)"
                                            class="px-3 py-1 text-xs rounded border">Retomar</button>
                                        <button v-if="item.status !== 'completed'" type="button" @click="finish(item)"
                                            class="px-3 py-1 text-xs rounded border text-red-600">Concluir</button>
                                    </div>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <div class="mt-8 space-y-6">
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
                            <option v-for="client in filteredClients" :key="client.id" :value="String(client.id)">
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
                                Registar compra
                            </button>
                        </div>
                    </div>
                </div>

                <div class="bg-white rounded shadow p-6 lg:col-span-2">
                    <h3 class="text-base font-semibold mb-4">Transações</h3>

                    <p v-if="!walletTransactions.length" class="text-sm text-gray-500">Sem transações registadas.</p>

                    <div v-else class="overflow-x-auto">
                        <table class="w-full text-sm text-left">
                            <thead>
                                <tr class="bg-gray-50 border-b">
                                    <th class="py-2 px-2">Data</th>
                                    <th class="py-2 px-2">Tipo</th>
                                    <th class="py-2 px-2">Descrição</th>
                                    <th class="py-2 px-2">Horas</th>
                                    <th class="py-2 px-2">Valor</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr v-for="tx in walletTransactions" :key="tx.id" class="border-b">
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
                                    </td>
                                    <td class="py-2 px-2 font-mono">{{ formatHours(tx.seconds) }}</td>
                                    <td class="py-2 px-2">{{ formatAmount(tx.amount) }}</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </BaseLayout>
</template>
