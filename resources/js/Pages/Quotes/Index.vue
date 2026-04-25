<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { router, usePage } from '@inertiajs/vue3'
import { computed, ref } from 'vue'

const { quotes, pipelineBaseTotal, adjudicationsTotal, installmentsTotal, installmentsByProject } = usePage().props
const list = ref(quotes.data || [])
const adjudicationPercent = ref({})
const adjudicationPaidAt = ref({})
const baseTotal = ref(Number(pipelineBaseTotal || 0))
const adjudicationsTotalValue = ref(Number(adjudicationsTotal || 0))
const installmentsTotalValue = ref(Number(installmentsTotal || 0))
const installmentsByProjectValue = ref(installmentsByProject || {})

const normalizeDateInput = (value) => {
    if (!value) return ''
    if (value instanceof Date) {
        return value.toISOString().slice(0, 10)
    }
    if (typeof value === 'string') {
        return value.slice(0, 10)
    }
    return ''
}

list.value.forEach((quote) => {
    adjudicationPercent.value[quote.id] = quote.adjudication_percent ?? ''
    adjudicationPaidAt.value[quote.id] = normalizeDateInput(quote.adjudication_paid_at)
})

const currency = new Intl.NumberFormat('pt-PT', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
})

const pipelineTotalValue = computed(() => Math.max(
    0,
    baseTotal.value - adjudicationsTotalValue.value - installmentsTotalValue.value
))

const totalReceivedValue = computed(() => adjudicationsTotalValue.value + installmentsTotalValue.value)
const formattedPipeline = computed(() => currency.format(pipelineTotalValue.value || 0))
const formattedAdjudications = computed(() => currency.format(totalReceivedValue.value || 0))
const formattedAdjudicationsOnly = computed(() => currency.format(adjudicationsTotalValue.value || 0))
const formattedInstallments = computed(() => currency.format(installmentsTotalValue.value || 0))

const updateLocalQuote = (quoteId, percent, paidAt) => {
    const target = list.value.find((item) => item.id === quoteId)
    if (!target) return
    target.adjudication_percent = percent
    target.adjudication_paid_at = paidAt
    adjudicationPaidAt.value[quoteId] = normalizeDateInput(paidAt)
}

const saveAdjudication = (quote) => {
    const percent = adjudicationPercent.value[quote.id]
    const paidAt = normalizeDateInput(adjudicationPaidAt.value[quote.id])
    const parsedPercent = percent === '' ? null : Number(percent)
    const base = Number(quote.price_development || 0)
    const previousPercent = Number(quote.adjudication_percent || 0)
    const previousAmount = base > 0 && previousPercent > 0 ? (base * previousPercent / 100) : 0
    const nextAmount = base > 0 && parsedPercent > 0 ? (base * parsedPercent / 100) : 0

    router.post(`/quotes/${quote.id}/adjudication`, {
        adjudication_percent: parsedPercent,
        adjudication_paid_at: paidAt || null
    }, {
        preserveScroll: true,
        onSuccess: () => {
            adjudicationsTotalValue.value += (nextAmount - previousAmount)
            updateLocalQuote(quote.id, parsedPercent, paidAt || null)
        }
    })
}

const clearAdjudication = (quote) => {
    adjudicationPercent.value[quote.id] = ''
    adjudicationPaidAt.value[quote.id] = ''
    saveAdjudication(quote)
}

const adjudicationAmount = (quote) => {
    const percent = Number(adjudicationPercent.value[quote.id] ?? quote.adjudication_percent ?? 0)
    const base = Number(quote.price_development || 0)
    if (!Number.isFinite(percent) || percent <= 0 || base <= 0) {
        return 0
    }
    return base * percent / 100
}

const remainingForQuote = (quote) => {
    const base = Number(quote.price_development || 0)
    const adjudication = adjudicationAmount(quote)
    const installments = Number(installmentsByProjectValue.value?.[quote.project_id] || 0)
    return Math.max(0, base - adjudication - installments)
}
</script>

<template>
    <BaseLayout>
        <template #title>Orçamentos</template>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
            <div class="bg-white rounded shadow p-4">
                <p class="text-xs text-gray-500">Dinheiro em cima da mesa</p>
                <p class="text-2xl font-semibold">{{ formattedPipeline }} €</p>
                <p class="text-xs text-gray-500">Projetos ativos (exclui concluídos e cancelados).</p>
            </div>
            <div v-if="totalReceivedValue > 0" class="bg-white rounded shadow p-4 border border-emerald-100">
                <p class="text-xs text-emerald-600">Adjudicações / Parcelas</p>
                <p class="text-2xl font-semibold text-emerald-600">{{ formattedAdjudications }} €</p>
                <p class="text-xs text-emerald-500">
                    Adjudicações: {{ formattedAdjudicationsOnly }} € · Parcelas: {{ formattedInstallments }} €
                </p>
            </div>
        </div>

        <div class="bg-white rounded shadow overflow-x-auto">
            <table class="min-w-[760px] w-full text-left text-sm">
                <thead>
                    <tr class="bg-gray-50 border-b">
                        <th class="py-2 px-3">Projeto</th>
                        <th class="py-2 px-3">Cliente</th>
                        <th class="py-2 px-3">Tipo</th>
                        <th class="py-2 px-3">Desenvolvimento</th>
                        <th class="py-2 px-3">Criado</th>
                        <th class="py-2 px-3 w-36"></th>
                    </tr>
                </thead>

                <tbody v-if="list.length">
                    <tr v-for="q in list" :key="q.id" class="border-b hover:bg-gray-50">
                        <td class="py-2 px-3">{{ q.project?.name }}</td>
                        <td class="py-2 px-3">{{ q.project?.client?.name }}</td>
                        <td class="py-2 px-3">{{ q.project_type }}</td>
                        <td class="py-2 px-3">
                            <div>
                                {{ q.price_development }} €
                                <div class="text-[11px] text-gray-400">
                                    falta {{ currency.format(remainingForQuote(q)) }} €
                                </div>
                            </div>
                        </td>
                        <td class="py-2 px-3">
                            {{ new Date(q.created_at).toLocaleDateString('pt-PT') }}
                        </td>
                        <td class="py-2 px-3 text-right">
                            <div class="inline-flex items-center gap-2">
                                <div class="relative group inline-flex">
                                    <button
                                        type="button"
                                        class="text-xs text-blue-600 hover:underline"
                                    >
                                        Exportar
                                    </button>
                                    <div
                                        class="absolute right-0 top-full z-10 hidden min-w-[120px] rounded border border-gray-200 bg-white shadow group-hover:block"
                                    >
                                        <a
                                            :href="route('quotes.pdf', q.id)"
                                            target="_blank"
                                            class="block px-3 py-2 text-xs text-gray-700 hover:bg-gray-50"
                                        >
                                            PDF
                                        </a>
                                        <a
                                            :href="route('quotes.docx', q.id)"
                                            class="block px-3 py-2 text-xs text-gray-700 hover:bg-gray-50"
                                        >
                                            DOCX
                                        </a>
                                        <a
                                            :href="route('quotes.docx.partner', q.id)"
                                            class="block px-3 py-2 text-xs text-gray-700 hover:bg-gray-50"
                                        >
                                            DOCX Parceiro
                                        </a>
                                    </div>
                                </div>
                                <a :href="`/q/${q.public_token}`" target="_blank" class="text-green-600 text-xs">
                                    Partilhar
                                </a>
                            </div>
                        </td>
                    </tr>
                </tbody>

                <tbody v-else>
                    <tr>
                        <td colspan="6" class="py-4 text-center text-gray-500">
                            Nenhum orçamento encontrado.
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>
    </BaseLayout>
</template>
