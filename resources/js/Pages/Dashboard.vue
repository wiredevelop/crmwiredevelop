<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { usePage, Link } from '@inertiajs/vue3'
import { ref, computed } from 'vue'

const { stats, recentClients, recentProjects, recentInvoices, pendingInvoices, salesGoal, salesProgress, salesAchieved, salesBreakdown, salesBreakdownDetails } = usePage().props

const currentYear = new Date().getFullYear()
const salesProgressValue = computed(() => salesProgress ?? 0)
const salesAchievedValue = computed(() => salesAchieved ?? stats.invoiced_amount ?? 0)
const salesRemaining = computed(() => {
    if (!salesGoal || salesGoal <= 0) return null
    return Math.max(0, salesGoal - salesAchievedValue.value)
})
const salesBreakdownValue = computed(() => salesBreakdown ?? {
    paid_invoices: 0,
    installments: 0,
    adjudications: 0
})
const salesBreakdownDetailsValue = computed(() => salesBreakdownDetails ?? {
    paid_invoices: [],
    installments: [],
    adjudications: []
})

const formatAmount = (value) => {
    const amount = Number(value || 0)
    return amount.toLocaleString('pt-PT', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

// === SEARCH ===
const searchInvoices = ref('')
const searchPending = ref('')
const searchClients = ref('')
const searchProjects = ref('')

// === SORT ===
const sortKey = ref(null)
const sortDir = ref('asc')

function sortBy(column) {
    if (sortKey.value === column) {
        sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
    } else {
        sortKey.value = column
        sortDir.value = 'asc'
    }
}

function sortedAndFiltered(list, searchTerm) {
    let result = list

    if (searchTerm) {
        const term = searchTerm.toLowerCase()

        result = result.filter(item =>
            JSON.stringify(item).toLowerCase().includes(term)
        )
    }

    if (sortKey.value) {
        result = [...result].sort((a, b) => {
            const x = a[sortKey.value] ?? ''
            const y = b[sortKey.value] ?? ''

            if (typeof x === 'string') {
                return sortDir.value === 'asc'
                    ? x.localeCompare(y)
                    : y.localeCompare(x)
            }

            return sortDir.value === 'asc' ? x - y : y - x
        })
    }

    return result
}

// WRAPPERS (para cada tabela)
const invoicesFiltered = computed(() =>
    sortedAndFiltered(recentInvoices, searchInvoices.value)
)

const pendingFiltered = computed(() =>
    sortedAndFiltered(pendingInvoices, searchPending.value)
)

const clientsFiltered = computed(() =>
    sortedAndFiltered(recentClients, searchClients.value)
)

const projectsFiltered = computed(() =>
    sortedAndFiltered(recentProjects, searchProjects.value)
)
</script>

<template>
    <BaseLayout>
        <template #title>Dashboard</template>

        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-6">
            <div>
                <h2 class="text-lg font-semibold">Atalhos rápidos</h2>
                <p class="text-sm text-gray-500">Inicia uma intervenção com um clique.</p>
            </div>
            <Link href="/interventions" class="bg-[#015557] text-white px-4 py-2 rounded hover:bg-[#014548]">
                Iniciar intervenção
            </Link>
        </div>

        <!-- ===================== KPIs ===================== -->
        <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4 mb-8">

            <div class="bg-white rounded shadow p-4">
                <p class="text-xs text-gray-500">Clientes</p>
                <p class="text-2xl font-semibold">{{ stats.total_clients }}</p>
            </div>

            <div class="bg-white rounded shadow p-4">
                <p class="text-xs text-gray-500">Projetos Ativos</p>
                <p class="text-2xl font-semibold">{{ stats.active_projects }}</p>
            </div>

            <div class="bg-white rounded shadow p-4">
                <p class="text-xs text-gray-500">Projetos Concluídos</p>
                <p class="text-2xl font-semibold">{{ stats.completed_projects }}</p>
            </div>

            <div class="bg-white rounded shadow p-4">
                <p class="text-xs text-gray-500">Faturação Total</p>
                <p class="text-xl font-semibold">
                    {{ stats.paid_amount }} €
                </p>
                <p class="text-xs text-yellow-600">
                    + {{ stats.pending_amount }} € pendente
                </p>
            </div>

        </div>

        <div class="bg-white rounded shadow p-4 mb-8">
            <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between mb-3">
                <div>
                    <h2 class="font-semibold">Meta de vendas {{ currentYear }}</h2>
                    <p class="text-xs text-gray-500">Acompanhe o progresso anual.</p>
                </div>
                <Link href="/settings" class="text-xs text-[#015557] hover:underline">Definir meta</Link>
            </div>

            <div v-if="salesGoal && salesGoal > 0">
                <div class="flex items-center justify-between text-sm">
                    <span class="text-gray-600">{{ salesAchievedValue }} € contabilizado</span>
                    <span class="font-medium">{{ salesGoal }} € meta</span>
                </div>
                <div class="mt-2 h-3 w-full bg-gray-200 rounded">
                    <div
                        class="h-3 bg-[#015557] rounded"
                        :style="{ width: `${salesProgressValue}%` }"
                    ></div>
                </div>
                <p class="text-xs text-gray-500 mt-2">
                    {{ salesProgressValue }}% atingido
                    <span v-if="salesRemaining !== null">· faltam {{ salesRemaining }} €</span>
                </p>
                <details class="mt-2 text-xs text-gray-500">
                    <summary class="cursor-pointer select-none text-[#015557]">Ver detalhes</summary>
                    <div class="mt-2 grid grid-cols-1 sm:grid-cols-3 gap-2">
                        <div>Faturas pagas: {{ formatAmount(salesBreakdownValue.paid_invoices) }} €</div>
                        <div>Parcelas: {{ formatAmount(salesBreakdownValue.installments) }} €</div>
                        <div>Adjudicações: {{ formatAmount(salesBreakdownValue.adjudications) }} €</div>
                    </div>

                    <div class="mt-3 space-y-3">
                        <div v-if="salesBreakdownDetailsValue.paid_invoices.length">
                            <p class="text-[11px] uppercase tracking-wide text-gray-400">Faturas pagas</p>
                            <ul class="mt-1 space-y-1">
                                <li v-for="item in salesBreakdownDetailsValue.paid_invoices" :key="`inv-${item.id}`">
                                    {{ item.number }} · {{ item.project || 'Sem projeto' }} · {{ formatAmount(item.amount) }} €
                                </li>
                            </ul>
                        </div>

                        <div v-if="salesBreakdownDetailsValue.installments.length">
                            <p class="text-[11px] uppercase tracking-wide text-gray-400">Parcelas</p>
                            <ul class="mt-1 space-y-1">
                                <li v-for="item in salesBreakdownDetailsValue.installments" :key="`inst-${item.id}`">
                                    {{ item.project }} · {{ item.client }} · {{ formatAmount(item.amount) }} € · {{ item.paid_at }}
                                </li>
                            </ul>
                        </div>

                        <div v-if="salesBreakdownDetailsValue.adjudications.length">
                            <p class="text-[11px] uppercase tracking-wide text-gray-400">Adjudicações</p>
                            <ul class="mt-1 space-y-1">
                                <li v-for="item in salesBreakdownDetailsValue.adjudications" :key="`adj-${item.id}`">
                                    {{ item.project }} · {{ item.percent }}% · {{ formatAmount(item.amount) }} € · {{ item.paid_at }}
                                </li>
                            </ul>
                        </div>
                    </div>
                </details>
            </div>

            <p v-else class="text-sm text-gray-500">Define uma meta anual nas definições.</p>
        </div>

        <!-- ===================== FINANCEIRO ===================== -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-10">

            <!-- Faturas Recentes -->
            <div class="bg-white rounded shadow p-4 col-span-2">
                <div class="flex items-center justify-between mb-3">
                    <h2 class="font-semibold">Últimas Faturas</h2>
                    <Link href="/invoices" class="text-xs text-[#015557] hover:underline">
                    Ver todas
                    </Link>
                </div>

                <!-- SEARCH -->
                <input v-model="searchInvoices" type="text" placeholder="Pesquisar..."
                    class="mb-3 w-full border rounded px-3 py-1 text-sm">

                <div class="overflow-x-auto">
                    <table class="w-full text-left text-sm">
                    <thead>
                        <tr class="bg-gray-50 border-b">
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('number')">
                                Nº
                            </th>
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('client')">
                                Cliente
                            </th>
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('project')">
                                Projeto
                            </th>
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('total')">
                                Total
                            </th>
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('status')">
                                Estado
                            </th>
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('issued_at')">
                                Emitida
                            </th>
                        </tr>
                    </thead>

                    <tbody>
                        <tr v-for="i in invoicesFiltered" :key="i.id" class="border-b">
                            <td class="py-2 px-2">{{ i.number }}</td>
                            <td class="py-2 px-2">{{ i.client?.name }}</td>
                            <td class="py-2 px-2">{{ i.project?.name }}</td>
                            <td class="py-2 px-2">{{ i.total }} €</td>
                            <td class="py-2 px-2">
                                <span :class="i.status === 'pago' ? 'text-green-600' : 'text-red-600'">
                                    {{ i.status }}
                                </span>
                            </td>
                            <td class="py-2 px-2">
                                {{ new Date(i.issued_at).toLocaleDateString('pt-PT') }}
                            </td>
                        </tr>

                        <tr v-if="invoicesFiltered.length === 0">
                            <td colspan="6" class="text-center py-3 text-gray-500 text-xs">
                                Sem resultados.
                            </td>
                        </tr>

                    </tbody>
                    </table>
                </div>
            </div>

            <!-- Pendentes -->
            <div class="bg-white rounded shadow p-4">
                <h2 class="font-semibold mb-3">Faturas Pendentes</h2>

                <input v-model="searchPending" type="text" placeholder="Pesquisar..."
                    class="mb-3 w-full border rounded px-3 py-1 text-sm">

                <div class="overflow-x-auto">
                    <table class="w-full text-left text-sm">
                    <thead>
                        <tr class="bg-gray-50 border-b">
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('client')">Cliente</th>
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('total')">Valor</th>
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('due_at')">Venc.</th>
                        </tr>
                    </thead>

                    <tbody>
                        <tr v-for="p in pendingFiltered" :key="p.id" class="border-b">
                            <td class="py-2 px-2">{{ p.client?.name }}</td>
                            <td class="py-2 px-2">{{ p.total }} €</td>
                            <td class="py-2 px-2">{{ new Date(p.due_at).toLocaleDateString('pt-PT') }}</td>
                        </tr>

                        <tr v-if="pendingFiltered.length === 0">
                            <td colspan="3" class="text-center text-gray-500 py-3 text-xs">
                                Sem resultados.
                            </td>
                        </tr>
                    </tbody>
                    </table>
                </div>
            </div>
        </div>

        <!-- ===================== CLIENTES + PROJETOS ===================== -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">

            <!-- Últimos clientes -->
            <div class="bg-white rounded shadow p-4">
                <div class="flex items-center justify-between mb-3">
                    <h2 class="font-semibold">Últimos Clientes</h2>
                    <Link href="/clients" class="text-xs text-[#015557] hover:underline">
                    Ver todos
                    </Link>
                </div>

                <input v-model="searchClients" type="text" placeholder="Pesquisar..."
                    class="mb-3 w-full border rounded px-3 py-1 text-sm">

                <div class="overflow-x-auto">
                    <table class="w-full text-left text-sm">
                    <thead>
                        <tr class="bg-gray-50 border-b">
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('name')">Nome</th>
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('company')">Empresa</th>
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('email')">Email</th>
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('created_at')">Criado</th>
                        </tr>
                    </thead>

                    <tbody>
                        <tr v-for="c in clientsFiltered" :key="c.id" class="border-b">
                            <td class="py-2 px-2">{{ c.name }}</td>
                            <td class="py-2 px-2">{{ c.company }}</td>
                            <td class="py-2 px-2">{{ c.email }}</td>
                            <td class="py-2 px-2">{{ new Date(c.created_at).toLocaleDateString('pt-PT') }}</td>
                        </tr>
                    </tbody>
                    </table>
                </div>
            </div>

            <!-- Últimos projetos -->
            <div class="bg-white rounded shadow p-4">
                <div class="flex items-center justify-between mb-3">
                    <h2 class="font-semibold">Últimos Projetos</h2>
                    <Link href="/projects" class="text-xs text-[#015557] hover:underline">
                    Ver todos
                    </Link>
                </div>

                <input v-model="searchProjects" type="text" placeholder="Pesquisar..."
                    class="mb-3 w-full border rounded px-3 py-1 text-sm">

                <div class="overflow-x-auto">
                    <table class="w-full text-left text-sm">
                    <thead>
                        <tr class="bg-gray-50 border-b">
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('name')">Projeto</th>
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('client')">Cliente</th>
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('status')">Estado</th>
                            <th class="py-2 px-2 cursor-pointer" @click="sortBy('created_at')">Criado</th>
                        </tr>
                    </thead>

                    <tbody>
                        <tr v-for="p in projectsFiltered" :key="p.id" class="border-b">
                            <td class="py-2 px-2">{{ p.name }}</td>
                            <td class="py-2 px-2">{{ p.client?.name }}</td>
                            <td class="py-2 px-2">{{ p.status }}</td>
                            <td class="py-2 px-2">{{ new Date(p.created_at).toLocaleDateString('pt-PT') }}</td>
                        </tr>
                    </tbody>
                    </table>
                </div>
            </div>

        </div>

    </BaseLayout>
</template>
