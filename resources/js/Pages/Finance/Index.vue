<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { Link, router, useForm, usePage } from '@inertiajs/vue3'
import { computed, ref, watch } from 'vue'

const shortcuts = [
    {
        title: 'Documentos',
        description: 'Emitir, marcar pago e acompanhar recebimentos.',
        href: '/invoices',
        action: 'Ver documentos'
    },
    {
        title: 'Orçamentos',
        description: 'Criar e partilhar propostas para clientes.',
        href: '/quotes',
        action: 'Ver orcamentos'
    },
    {
        title: 'Carteiras',
        description: 'Consultar saldos e transacoes por cliente.',
        href: '/wallets',
        action: 'Gerir carteiras'
    },
    {
        title: 'Produtos / Packs',
        description: 'Gerir catalogo para propostas e packs.',
        href: '/products',
        action: 'Gerir catalogo'
    },
    {
        title: 'Dados da Empresa',
        description: 'Dados para pagamento e informacao nos PDFs.',
        href: '/company',
        action: 'Editar dados'
    }
]

const page = usePage()
const sales = computed(() => page.props.sales ?? [])
const projects = computed(() => page.props.projects ?? [])
const installments = computed(() => page.props.installments ?? [])
const invoices = computed(() => page.props.invoices ?? [])
const toastMessage = ref('')
const toastVisible = ref(false)
const selectedItems = ref([])
const bulkAction = ref('')
const activeClientId = ref(null)
const expandedKeys = ref(new Set())
const installmentForm = useForm({
    project_id: '',
    amount: '',
    note: '',
    paid_at: new Date().toISOString().slice(0, 10),
    invoice_id: ''
})

const selectedProject = computed(() =>
    projects.value.find((project) => String(project.id) === String(installmentForm.project_id))
)

const invoicesForProject = computed(() => {
    if (!installmentForm.project_id) return []
    return invoices.value.filter((invoice) =>
        String(invoice.project_id) === String(installmentForm.project_id)
    )
})

const clientGroups = computed(() => {
    const groups = new Map()

    sales.value.forEach((sale) => {
        const id = sale.client_id !== null && sale.client_id !== undefined
            ? String(sale.client_id)
            : 'unknown'
        const name = sale.client || 'Sem cliente'

        if (!groups.has(id)) {
            groups.set(id, { id, name, sales: [] })
        }

        groups.get(id).sales.push(sale)
    })

    return Array.from(groups.values())
        .sort((a, b) => a.name.localeCompare(b.name))
})

const filteredSales = computed(() => {
    if (!activeClientId.value) return []
    return clientGroups.value.find((group) => group.id === activeClientId.value)?.sales || []
})

const resolveSource = (sale) => {
    if (sale.source) {
        return sale.source
    }

    return sale.type === 'Projeto' ? 'project' : 'transaction'
}

const saleKey = (sale) => `${resolveSource(sale)}-${sale.id}`

const isInterventionSale = (sale) => !!sale.intervention
const isPackIntervention = (sale) => !!sale?.intervention?.is_pack

const isExpanded = (sale) => expandedKeys.value.has(saleKey(sale))

const toggleExpanded = (sale, event) => {
    if (!isInterventionSale(sale)) return
    if (event?.target?.closest?.('input, button, label, a, select, textarea')) return

    const key = saleKey(sale)
    const next = new Set(expandedKeys.value)
    if (next.has(key)) {
        next.delete(key)
    } else {
        next.add(key)
    }
    expandedKeys.value = next
}

const setActiveClient = (id) => {
    activeClientId.value = String(id)
}

watch(clientGroups, (groups) => {
    if (!groups.length) {
        activeClientId.value = null
        return
    }

    const exists = groups.some((group) => group.id === activeClientId.value)
    if (!exists) {
        activeClientId.value = groups[0].id
    }
}, { immediate: true })

watch(activeClientId, () => {
    selectedItems.value = []
    bulkAction.value = ''
})

const selectedSales = computed(() =>
    selectedItems.value
        .map((item) => filteredSales.value.find((sale) => sale.id === item.id && resolveSource(sale) === item.source))
        .filter(Boolean)
)

const selectedClientIds = computed(() => {
    const ids = selectedSales.value.map((sale) => sale.client_id).filter(Boolean)
    return Array.from(new Set(ids))
})

const hasMultipleClients = computed(() =>
    bulkAction.value === 'invoice' && selectedClientIds.value.length > 1
)

const isInvoiced = (sale) =>
    !!(sale.to_invoice || sale.invoice_id || sale.invoiced)

const isSelectable = (sale) => {
    if (isPackIntervention(sale)) {
        return false
    }
    if (bulkAction.value === 'uninvoice') {
        return isInvoiced(sale)
    }

    return !isInvoiced(sale)
}

const selectableSales = computed(() =>
    filteredSales.value.filter((sale) => isSelectable(sale))
)

const isSelected = (sale) =>
    selectedItems.value.some((item) => item.source === resolveSource(sale) && item.id === sale.id)

const allSelected = computed(() =>
    selectableSales.value.length > 0
    && selectableSales.value.every((sale) => isSelected(sale))
)

watch(filteredSales, () => {
    const allowedKeys = selectableSales.value.map((sale) => `${resolveSource(sale)}-${sale.id}`)
    selectedItems.value = selectedItems.value.filter((item) =>
        allowedKeys.includes(`${item.source}-${item.id}`)
    )

    const next = new Set()
    filteredSales.value.forEach((sale) => {
        const key = saleKey(sale)
        if (expandedKeys.value.has(key)) {
            next.add(key)
        }
    })
    expandedKeys.value = next
})

watch(bulkAction, () => {
    selectedItems.value = []
})

const formatAmount = (value) => {
    const amount = Number(value || 0)
    return amount.toLocaleString('pt-PT', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

const formatDate = (value) => {
    if (!value) return '—'
    return new Date(value).toLocaleDateString('pt-PT')
}

const formatDuration = (seconds) => {
    if (seconds === null || seconds === undefined) return '—'
    const safe = Math.max(0, Number(seconds) || 0)
    const hrs = Math.floor(safe / 3600)
    const mins = Math.floor((safe % 3600) / 60)
    const secs = Math.floor(safe % 60)
    return `${String(hrs).padStart(2, '0')}:${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`
}

const formatRate = (sale) => {
    if (!sale?.intervention) return '—'
    if (sale.intervention.is_pack) return 'Incluído no pack'
    const rate = sale.intervention.hourly_rate
    if (rate === null || rate === undefined) return '—'
    return `${formatAmount(rate)} €/h`
}

const invoiceStatusLabel = (sale) => {
    if (isPackIntervention(sale)) return 'Incluído no pack'
    if (sale.invoice_status === 'pago') return 'Pago'
    if (sale.invoice_status === 'pendente') return 'Não pago'
    if (isInvoiced(sale)) return 'Faturado'
    return 'Não faturado'
}

const toggleInstallment = (sale, event) => {
    const checked = event.target.checked
    let installmentCount = null

    if (checked) {
        const current = sale.installment_count || 2
        const input = prompt('Em quantas vezes?', String(current))
        if (input === null) {
            event.target.checked = false
            return
        }
        const parsed = Number.parseInt(input, 10)
        if (!Number.isFinite(parsed) || parsed < 2) {
            alert('Indica um numero de parcelas valido (minimo 2).')
            event.target.checked = false
            return
        }
        installmentCount = parsed
    }

    router.post(`/finance/sales/${resolveSource(sale)}/${sale.id}/installment`, {
        is_installment: checked,
        installment_count: installmentCount
    }, {
        preserveScroll: true,
        onSuccess: () => {
            router.reload({ only: ['sales'] })
        }
    })
}

const toggleToInvoice = (sale, event) => {
    const source = resolveSource(sale)
    const endpoint = source === 'project'
        ? `/finance/sales/project/${sale.id}/to-invoice`
        : `/finance/sales/transaction/${sale.id}/to-invoice`

    router.post(endpoint, {
        to_invoice: event.target.checked
    }, {
        preserveScroll: true,
        onSuccess: () => {
            toastMessage.value = event.target.checked
                ? 'Marcado como faturado.'
                : 'Faturado removido.'
            toastVisible.value = true
            setTimeout(() => {
                toastVisible.value = false
            }, 2500)
            router.reload({ only: ['sales'] })
        }
    })
}

const toggleSelectAll = () => {
    if (allSelected.value) {
        selectedItems.value = []
        return
    }

    selectedItems.value = selectableSales.value.map((sale) => ({
        source: resolveSource(sale),
        id: sale.id
    }))
}

const toggleSelection = (sale, event) => {
    if (event.target.checked) {
        if (!isSelected(sale)) {
            selectedItems.value.push({
                source: resolveSource(sale),
                id: sale.id
            })
        }
        return
    }

    selectedItems.value = selectedItems.value.filter((item) =>
        !(item.source === resolveSource(sale) && item.id === sale.id)
    )
}

const applyBulk = () => {
    if (!bulkAction.value) return
    if (!selectedItems.value.length) {
        alert('Seleciona pelo menos um item.')
        return
    }
    if (hasMultipleClients.value) {
        alert('Seleciona vendas do mesmo cliente.')
        return
    }

    if (bulkAction.value === 'invoice') {
        router.post('/finance/sales/bulk-invoice', {
            items: selectedItems.value
        }, {
            preserveScroll: true,
            onSuccess: () => {
                toastMessage.value = 'Faturas criadas.'
                toastVisible.value = true
                setTimeout(() => {
                    toastVisible.value = false
                }, 2500)
                selectedItems.value = []
                bulkAction.value = ''
                router.reload({ only: ['sales'] })
            }
        })
    }

    if (bulkAction.value === 'uninvoice') {
        router.post('/finance/sales/bulk-uninvoice', {
            items: selectedItems.value
        }, {
            preserveScroll: true,
            onSuccess: () => {
                toastMessage.value = 'Faturacao removida.'
                toastVisible.value = true
                setTimeout(() => {
                    toastVisible.value = false
                }, 2500)
                selectedItems.value = []
                bulkAction.value = ''
                router.reload({ only: ['sales'] })
            }
        })
    }
}

const submitInstallment = () => {
    installmentForm.post('/finance/installments', {
        preserveScroll: true,
        onSuccess: () => {
            installmentForm.reset('amount', 'note', 'invoice_id')
            router.reload({ only: ['installments'] })
        }
    })
}

const removeInstallment = (installment) => {
    if (!confirm('Remover esta parcela?')) return
    router.delete(`/finance/installments/${installment.id}`, {
        preserveScroll: true,
        onSuccess: () => {
            router.reload({ only: ['installments'] })
        }
    })
}
</script>

<template>
    <BaseLayout>
        <template #title>Financeiro</template>

        <div
            v-if="toastVisible"
            class="fixed top-4 right-4 z-50 bg-[#015557] text-white text-sm px-4 py-3 rounded shadow-lg"
        >
            {{ toastMessage }}
        </div>

        <div class="space-y-6">
            <div class="bg-white rounded shadow p-6">
                <h1 class="text-2xl font-semibold">Financeiro</h1>
                <p class="text-sm text-gray-500 mt-2">
                    Atalhos rapidos para toda a gestao financeira.
                </p>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
                <div v-for="item in shortcuts" :key="item.title" class="bg-white rounded shadow p-5 flex flex-col">
                    <div class="flex-1">
                        <h2 class="text-lg font-semibold">{{ item.title }}</h2>
                        <p class="text-sm text-gray-500 mt-2">{{ item.description }}</p>
                    </div>

                    <div class="mt-4">
                        <Link :href="item.href" class="text-sm text-[#015557] hover:underline">
                            {{ item.action }}
                        </Link>
                    </div>
                </div>
            </div>

            <div class="bg-white rounded shadow p-6">
                <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between mb-4">
                    <div>
                        <h2 class="text-lg font-semibold">Vendas</h2>
                        <p class="text-sm text-gray-500">Projetos concluidos, packs/produtos e intervenções sem pack.</p>
                </div>
            </div>

            <div class="bg-white rounded shadow p-6">
                <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between mb-4">
                    <div>
                        <h2 class="text-lg font-semibold">Parcelas</h2>
                        <p class="text-sm text-gray-500">Regista parcelas pagas por projeto.</p>
                    </div>
                </div>

                <form class="grid grid-cols-1 lg:grid-cols-4 gap-4 mb-6" @submit.prevent="submitInstallment">
                    <div class="lg:col-span-2">
                        <label class="block text-xs text-gray-500 mb-1">Projeto</label>
                        <select v-model="installmentForm.project_id" class="w-full border rounded px-3 py-2 text-sm" required>
                            <option value="">Selecionar projeto</option>
                            <option v-for="project in projects" :key="project.id" :value="project.id">
                                {{ project.name }} · {{ project.client }} ({{ project.status }})
                            </option>
                        </select>
                        <p v-if="selectedProject" class="mt-1 text-xs text-gray-500">
                            Cliente: {{ selectedProject.client }}
                        </p>
                    </div>

                    <div>
                        <label class="block text-xs text-gray-500 mb-1">Valor</label>
                        <input
                            v-model="installmentForm.amount"
                            type="number"
                            step="0.01"
                            min="0.01"
                            class="w-full border rounded px-3 py-2 text-sm"
                            placeholder="0,00"
                            required
                        />
                    </div>

                    <div>
                        <label class="block text-xs text-gray-500 mb-1">Pago em</label>
                        <input
                            v-model="installmentForm.paid_at"
                            type="date"
                            class="w-full border rounded px-3 py-2 text-sm"
                        />
                    </div>

                    <div class="lg:col-span-2">
                        <label class="block text-xs text-gray-500 mb-1">Nota (opcional)</label>
                        <input
                            v-model="installmentForm.note"
                            type="text"
                            class="w-full border rounded px-3 py-2 text-sm"
                            placeholder="Ex: 1a parcela"
                        />
                    </div>

                    <div class="lg:col-span-2">
                        <label class="block text-xs text-gray-500 mb-1">Fatura associada (opcional)</label>
                        <select v-model="installmentForm.invoice_id" class="w-full border rounded px-3 py-2 text-sm">
                            <option value="">Sem fatura</option>
                            <option v-for="invoice in invoicesForProject" :key="invoice.id" :value="invoice.id">
                                {{ invoice.number }} · {{ formatAmount(invoice.total) }} € · {{ invoice.status }}
                            </option>
                        </select>
                    </div>

                    <div class="lg:col-span-4 flex items-center justify-end gap-3">
                        <button
                            type="submit"
                            class="bg-[#015557] text-white px-4 py-2 rounded hover:bg-[#014548] disabled:opacity-50"
                            :disabled="installmentForm.processing"
                        >
                            Registar parcela
                        </button>
                    </div>
                </form>

                <div v-if="installments.length" class="overflow-x-auto">
                    <table class="min-w-[760px] w-full text-left text-sm">
                        <thead>
                            <tr class="bg-gray-50 border-b">
                                <th class="py-2 px-3">Projeto</th>
                                <th class="py-2 px-3">Cliente</th>
                                <th class="py-2 px-3">Valor</th>
                                <th class="py-2 px-3">Pago em</th>
                                <th class="py-2 px-3">Fatura</th>
                                <th class="py-2 px-3">Nota</th>
                                <th class="py-2 px-3 w-24"></th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="installment in installments" :key="installment.id" class="border-b">
                                <td class="py-2 px-3">{{ installment.project }}</td>
                                <td class="py-2 px-3">{{ installment.client }}</td>
                                <td class="py-2 px-3">{{ formatAmount(installment.amount) }} €</td>
                                <td class="py-2 px-3">{{ formatDate(installment.paid_at) }}</td>
                                <td class="py-2 px-3">{{ installment.invoice }}</td>
                                <td class="py-2 px-3">{{ installment.note || '—' }}</td>
                                <td class="py-2 px-3 text-right">
                                    <button
                                        type="button"
                                        class="text-xs text-red-600 hover:underline"
                                        @click="removeInstallment(installment)"
                                    >
                                        Remover
                                    </button>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>

                <p v-else class="text-sm text-gray-500">Sem parcelas registadas.</p>
            </div>

                <div v-if="clientGroups.length" class="flex flex-wrap gap-2 mb-4">
                    <button
                        v-for="group in clientGroups"
                        :key="group.id"
                        type="button"
                        class="px-3 py-2 rounded border text-sm transition"
                        :class="activeClientId === group.id ? 'bg-[#015557] text-white border-[#015557]' : 'bg-white text-gray-600'"
                        @click="setActiveClient(group.id)"
                    >
                        {{ group.name }}
                        <span class="text-xs text-gray-200" v-if="activeClientId === group.id">
                            ({{ group.sales.length }})
                        </span>
                        <span class="text-xs text-gray-500" v-else>
                            ({{ group.sales.length }})
                        </span>
                    </button>
                </div>

                <div class="flex flex-wrap items-center gap-3 mb-4 text-sm">
                    <select v-model="bulkAction" class="border rounded px-3 py-2 text-sm">
                        <option value="">Acoes em massa</option>
                        <option value="invoice">Faturar selecionados</option>
                        <option value="uninvoice">Desfaturar selecionados</option>
                    </select>
                    <button
                        type="button"
                        class="bg-[#015557] text-white px-4 py-2 rounded hover:bg-[#014548] disabled:opacity-50"
                        :disabled="!selectedItems.length || !bulkAction || hasMultipleClients"
                        @click="applyBulk"
                    >
                        Aplicar
                    </button>
                    <span v-if="hasMultipleClients" class="text-sm text-red-500">
                        Seleciona vendas do mesmo cliente.
                    </span>
                </div>

                <div v-if="filteredSales.length" class="overflow-x-auto">
                    <table class="min-w-[980px] w-full text-left text-sm">
                        <thead>
                            <tr class="bg-gray-50 border-b">
                                <th class="py-2 px-2 w-10">
                                    <input
                                        type="checkbox"
                                        class="rounded border-gray-300"
                                        :checked="allSelected"
                                        :disabled="!selectableSales.length"
                                        @change="toggleSelectAll"
                                    />
                                </th>
                                <th class="py-2 px-2">Tipo</th>
                                <th class="py-2 px-2">Cliente</th>
                                <th class="py-2 px-2">Descricao</th>
                                <th class="py-2 px-2">Valor</th>
                                <th class="py-2 px-2">Data</th>
                                <th class="py-2 px-2">Estado</th>
                                <th class="py-2 px-2">Parcelado</th>
                                <th class="py-2 px-2">Faturado</th>
                            </tr>
                        </thead>
                        <tbody>
                            <template v-for="sale in filteredSales" :key="saleKey(sale)">
                                <tr
                                    class="border-b"
                                    :class="isInterventionSale(sale) ? 'cursor-pointer hover:bg-gray-50' : ''"
                                    @click="toggleExpanded(sale, $event)"
                                >
                                    <td class="py-2 px-2">
                                        <input
                                            type="checkbox"
                                            class="rounded border-gray-300 disabled:opacity-40"
                                            :checked="isSelected(sale)"
                                            :disabled="!isSelectable(sale)"
                                            @change="toggleSelection(sale, $event)"
                                        />
                                    </td>
                                    <td class="py-2 px-2 font-medium">{{ sale.type }}</td>
                                    <td class="py-2 px-2">{{ sale.client }}</td>
                                    <td class="py-2 px-2">
                                        <div class="font-medium">{{ sale.description }}</div>
                                        <div class="text-xs text-gray-500">ID interno #{{ sale.transaction_id || sale.id }}</div>
                                        <div v-if="sale.document_number" class="text-xs text-gray-500">
                                            Documento: {{ sale.document_number }}
                                        </div>
                                        <div v-if="sale.payment_reference" class="text-xs text-gray-500">
                                            Stripe: {{ sale.payment_reference }}
                                        </div>
                                        <div v-if="sale.billing?.provider === 'stripe'" class="mt-1 text-xs">
                                            <span class="font-medium" :class="sale.billing.wants_invoice ? 'text-emerald-700' : 'text-gray-500'">
                                                {{ sale.billing.wants_invoice ? 'Cliente pediu documento com NIF' : 'Sem pedido de documento com NIF' }}
                                            </span>
                                            <div v-if="sale.billing.wants_invoice" class="text-gray-600">
                                                {{ sale.billing.name || '—' }} · {{ sale.billing.vat || 'Sem NIF' }}
                                            </div>
                                        </div>
                                    </td>
                                    <td class="py-2 px-2">{{ formatAmount(sale.amount) }} €</td>
                                    <td class="py-2 px-2">{{ formatDate(sale.date) }}</td>
                                    <td class="py-2 px-2">{{ invoiceStatusLabel(sale) }}</td>
                                    <td class="py-2 px-2">
                                        <template v-if="resolveSource(sale) === 'transaction' && !isPackIntervention(sale)">
                                            <label class="inline-flex items-center gap-2 text-sm text-gray-600">
                                                <input
                                                    type="checkbox"
                                                    class="rounded border-gray-300"
                                                    :checked="sale.is_installment"
                                                    @change="toggleInstallment(sale, $event)"
                                                />
                                                Parcelado
                                            </label>
                                            <span v-if="sale.is_installment && sale.installment_count"
                                                  class="ml-2 text-xs text-gray-500">
                                                x{{ sale.installment_count }}
                                            </span>
                                        </template>
                                        <span v-else class="text-xs text-gray-400">—</span>
                                    </td>
                                    <td class="py-2 px-2">
                                        <span v-if="isPackIntervention(sale)" class="text-xs text-gray-500">
                                            Incluído no pack
                                        </span>
                                        <label
                                            v-else-if="resolveSource(sale) === 'transaction'"
                                            class="inline-flex items-center gap-2 text-sm text-gray-600"
                                        >
                                            <input
                                                type="checkbox"
                                                class="rounded border-gray-300"
                                                :checked="isInvoiced(sale)"
                                                @change="toggleToInvoice(sale, $event)"
                                            />
                                            Faturado
                                        </label>
                                        <label
                                            v-else-if="resolveSource(sale) === 'project'"
                                            class="inline-flex items-center gap-2 text-sm text-gray-600"
                                        >
                                            <input
                                                type="checkbox"
                                                class="rounded border-gray-300"
                                                :checked="isInvoiced(sale)"
                                                @change="toggleToInvoice(sale, $event)"
                                            />
                                            Faturado
                                        </label>
                                        <span v-else class="text-xs text-gray-400">—</span>
                                    </td>
                                </tr>
                                <tr v-if="isExpanded(sale)" class="bg-gray-50">
                                    <td colspan="9" class="px-4 py-3">
                                        <table class="w-full text-sm">
                                            <tbody>
                                                <tr>
                                                    <td class="w-40 text-gray-500">Notas início</td>
                                                    <td>
                                                        <span class="text-xs text-gray-600">
                                                            {{ sale.intervention?.notes || '—' }}
                                                        </span>
                                                    </td>
                                                </tr>
                                                <tr>
                                                    <td class="w-40 text-gray-500">Notas fim</td>
                                                    <td>
                                                        <span class="text-xs text-gray-600">
                                                            {{ sale.intervention?.finish_notes || '—' }}
                                                        </span>
                                                    </td>
                                                </tr>
                                                <tr>
                                                    <td class="w-40 text-gray-500">Duração</td>
                                                    <td class="font-mono">{{ formatDuration(sale.intervention?.total_seconds) }}</td>
                                                </tr>
                                                <tr>
                                                    <td class="w-40 text-gray-500">Valor/hora</td>
                                                    <td>{{ formatRate(sale) }}</td>
                                                </tr>
                                                <tr v-if="sale.billing?.provider === 'stripe'">
                                                    <td class="w-40 text-gray-500">Faturação Stripe</td>
                                                    <td>
                                                        <div class="text-xs text-gray-600">
                                                            Estado checkout: {{ sale.billing.status || '—' }}
                                                        </div>
                                                        <div class="text-xs text-gray-600">
                                                            Pedido com NIF: {{ sale.billing.wants_invoice ? 'Sim' : 'Não' }}
                                                        </div>
                                                        <div class="text-xs text-gray-600">
                                                            {{ sale.billing.name || '—' }} · {{ sale.billing.email || '—' }} · {{ sale.billing.phone || '—' }}
                                                        </div>
                                                        <div class="text-xs text-gray-600">
                                                            {{ sale.billing.vat || 'Sem NIF' }} · {{ sale.billing.address || '—' }} · {{ sale.billing.postal_code || '—' }} {{ sale.billing.city || '' }} {{ sale.billing.country || '' }}
                                                        </div>
                                                    </td>
                                                </tr>
                                            </tbody>
                                        </table>
                                    </td>
                                </tr>
                            </template>
                        </tbody>
                    </table>
                </div>

                <p v-else class="text-sm text-gray-500">Sem vendas registadas.</p>
            </div>
        </div>
    </BaseLayout>
</template>
