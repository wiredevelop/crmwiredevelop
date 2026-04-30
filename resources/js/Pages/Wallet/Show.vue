<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { computed, ref } from 'vue'

const props = defineProps({
    wallet: Object,
    interventions: Array,
    checkoutMethod: String,
    stripeAvailable: Boolean,
    manualPayment: Object,
})

const searchTransactions = ref('')
const searchInterventions = ref('')

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
    const amount = Number(value || 0)
    return amount.toLocaleString('pt-PT', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

const transactions = computed(() => {
    const list = props.wallet?.transactions ?? []
    const term = searchTransactions.value.trim().toLowerCase()
    if (!term) return list
    return list.filter((item) => JSON.stringify(item).toLowerCase().includes(term))
})

const interventions = computed(() => {
    const list = props.interventions ?? []
    const term = searchInterventions.value.trim().toLowerCase()
    if (!term) return list
    return list.filter((item) => JSON.stringify(item).toLowerCase().includes(term))
})

const manualMethods = computed(() => Array.isArray(props.manualPayment?.methods) ? props.manualPayment.methods : [])
const hasManualInfo = computed(() => {
    const notes = props.manualPayment?.notes?.trim?.() ?? ''
    return notes.length > 0 || manualMethods.value.length > 0
})
</script>

<template>
    <BaseLayout>
        <template #title>Carteira</template>

        <div class="space-y-6">
            <div class="bg-white rounded shadow p-6">
                <h1 class="text-2xl font-semibold">Carteira</h1>
                <p class="mt-1 text-sm text-gray-500">{{ wallet?.client?.name }}<span v-if="wallet?.client?.company"> · {{ wallet.client.company }}</span></p>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div class="bg-white rounded shadow p-6">
                    <p class="text-xs text-gray-500">Tempo em carteira</p>
                    <p class="mt-2 text-2xl font-semibold">{{ formatHours(wallet?.balance_seconds ?? 0) }}</p>
                </div>
                <div class="bg-white rounded shadow p-6">
                    <p class="text-xs text-gray-500">Compras / transações</p>
                    <p class="mt-2 text-2xl font-semibold">{{ (wallet?.transactions?.length ?? 0) }}</p>
                </div>
            </div>

            <div class="bg-white rounded shadow p-6">
                <h2 class="font-semibold">Opções de pagamento</h2>
                <p v-if="stripeAvailable" class="mt-2 text-sm text-emerald-700">
                    O checkout Stripe está disponível para pagamento online imediato.
                </p>
                <p v-else class="mt-2 text-sm text-amber-700">
                    O checkout Stripe está indisponível neste servidor neste momento.
                </p>
                <div v-if="hasManualInfo" class="mt-3 space-y-2 text-sm text-gray-700">
                    <p>Também estão disponíveis instruções de pagamento manual.</p>
                    <p v-if="manualPayment?.notes">{{ manualPayment.notes }}</p>
                    <div v-if="manualMethods.length" class="space-y-1">
                        <div v-for="(method, index) in manualMethods" :key="index">
                            <span class="font-medium">{{ method.label || 'Método' }}:</span>
                            {{ method.value || '—' }}
                        </div>
                    </div>
                </div>
                <p v-else-if="!stripeAvailable" class="mt-3 text-sm text-gray-600">
                    Não existem instruções manuais configuradas.
                </p>
            </div>

            <div class="bg-white rounded shadow p-6">
                <div class="flex items-center justify-between mb-3">
                    <h2 class="font-semibold">Intervenções registadas</h2>
                    <span class="text-xs text-gray-500">{{ interventions.length }} registo(s)</span>
                </div>

                <input v-model="searchInterventions" type="text" placeholder="Pesquisar intervenções..." class="mb-3 w-full border rounded px-3 py-2 text-sm">

                <div class="overflow-x-auto">
                    <table class="w-full text-left text-sm">
                        <thead>
                            <tr class="bg-gray-50 border-b">
                                <th class="py-2 px-2">Tipo</th>
                                <th class="py-2 px-2">Estado</th>
                                <th class="py-2 px-2">Notas</th>
                                <th class="py-2 px-2">Duração</th>
                                <th class="py-2 px-2">Início</th>
                                <th class="py-2 px-2">Fim</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="item in interventions" :key="item.id" class="border-b">
                                <td class="py-2 px-2">{{ item.type }}</td>
                                <td class="py-2 px-2">{{ item.status }}</td>
                                <td class="py-2 px-2">
                                    <div>{{ item.notes || '—' }}</div>
                                    <div v-if="item.finish_notes" class="text-xs text-gray-500">{{ item.finish_notes }}</div>
                                </td>
                                <td class="py-2 px-2">{{ formatHours(item.total_seconds) }}</td>
                                <td class="py-2 px-2">{{ item.started_at ? new Date(item.started_at).toLocaleDateString('pt-PT') : '—' }}</td>
                                <td class="py-2 px-2">{{ item.ended_at ? new Date(item.ended_at).toLocaleDateString('pt-PT') : '—' }}</td>
                            </tr>
                            <tr v-if="interventions.length === 0">
                                <td colspan="6" class="text-center py-3 text-gray-500 text-xs">Sem resultados.</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>

            <div class="bg-white rounded shadow p-6">
                <div class="flex items-center justify-between mb-3">
                    <h2 class="font-semibold">Compras e transações</h2>
                    <span class="text-xs text-gray-500">{{ transactions.length }} registo(s)</span>
                </div>

                <input v-model="searchTransactions" type="text" placeholder="Pesquisar transações..." class="mb-3 w-full border rounded px-3 py-2 text-sm">

                <div class="overflow-x-auto">
                    <table class="w-full text-left text-sm">
                        <thead>
                            <tr class="bg-gray-50 border-b">
                                <th class="py-2 px-2">Data</th>
                                <th class="py-2 px-2">Tipo</th>
                                <th class="py-2 px-2">Descrição</th>
                                <th class="py-2 px-2">Horas</th>
                                <th class="py-2 px-2">Valor</th>
                                <th class="py-2 px-2">Documento</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="tx in transactions" :key="tx.id" class="border-b">
                                <td class="py-2 px-2">{{ tx.transaction_at ? new Date(tx.transaction_at).toLocaleDateString('pt-PT') : '—' }}</td>
                                <td class="py-2 px-2">{{ tx.type }}</td>
                                <td class="py-2 px-2">
                                    <div class="font-medium">{{ tx.description || tx.product?.name || '—' }}</div>
                                    <div v-if="tx.pack_item" class="text-xs text-gray-500">Pack: {{ tx.pack_item.hours }}h</div>
                                </td>
                                <td class="py-2 px-2 font-mono">{{ formatHours(tx.seconds) }}</td>
                                <td class="py-2 px-2">{{ formatAmount(tx.amount) }} €</td>
                                <td class="py-2 px-2">{{ tx.invoice?.number || '—' }}</td>
                            </tr>
                            <tr v-if="transactions.length === 0">
                                <td colspan="6" class="text-center py-3 text-gray-500 text-xs">Sem resultados.</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </BaseLayout>
</template>
