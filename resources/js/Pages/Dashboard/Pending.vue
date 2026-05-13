<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { Link, usePage } from '@inertiajs/vue3'
import { computed, ref } from 'vue'

const { pendingTotals = {}, pendingSections = {} } = usePage().props

const tabs = [
    { key: 'todos', label: 'Todos' },
    { key: 'projects', label: 'Projetos' },
    { key: 'documents', label: 'Documentos' },
    { key: 'interventions', label: 'Intervenções' },
]

const activeTab = ref('todos')

const activeItems = computed(() => pendingSections?.[activeTab.value] ?? [])

const formatAmount = (value) => {
    const amount = Number(value || 0)
    return amount.toLocaleString('pt-PT', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

const formatDate = (value) => {
    if (!value) return '—'
    return new Date(value).toLocaleDateString('pt-PT')
}
</script>

<template>
    <BaseLayout>
        <template #title>Pendente</template>

        <div class="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div>
                <h1 class="text-xl font-semibold">Detalhe do pendente</h1>
                <p class="text-sm text-gray-500">Origem do valor pendente do cliente.</p>
            </div>
            <Link :href="route('dashboard')" class="inline-flex items-center rounded border border-[#015557] px-4 py-2 text-sm font-medium text-[#015557]">
                Voltar
            </Link>
        </div>

        <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <button
                v-for="tab in tabs"
                :key="tab.key"
                type="button"
                class="rounded-lg border p-4 text-left transition"
                :class="activeTab === tab.key ? 'border-[#015557] bg-[#015557] text-white' : 'border-gray-200 bg-white text-gray-800'"
                @click="activeTab = tab.key"
            >
                <div class="text-xs uppercase tracking-wide" :class="activeTab === tab.key ? 'text-white/70' : 'text-gray-500'">
                    {{ tab.label }}
                </div>
                <div class="mt-2 text-xl font-semibold">
                    {{ formatAmount(pendingTotals?.[tab.key]) }} €
                </div>
            </button>
        </div>

        <div class="mt-6 rounded-xl bg-white shadow">
            <div class="border-b border-gray-100 px-4 py-3">
                <h2 class="font-semibold">{{ tabs.find((tab) => tab.key === activeTab)?.label }}</h2>
            </div>

            <div v-if="activeItems.length" class="divide-y divide-gray-100">
                <div v-for="item in activeItems" :key="item.id" class="px-4 py-4">
                    <div class="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                        <div>
                            <p class="text-xs uppercase tracking-wide text-[#015557]">{{ item.category_label }}</p>
                            <h3 class="font-semibold text-gray-900">{{ item.title }}</h3>
                            <p class="text-sm text-gray-600">{{ item.subtitle }}</p>
                            <p class="mt-1 text-sm text-gray-500">{{ item.description }}</p>
                        </div>
                        <div class="text-left md:text-right">
                            <p class="text-lg font-semibold text-amber-600">{{ formatAmount(item.amount) }} €</p>
                            <p class="text-xs text-gray-500">{{ formatDate(item.date) }}</p>
                        </div>
                    </div>
                </div>
            </div>

            <div v-else class="px-4 py-8 text-sm text-gray-500">
                Sem valores pendentes nesta secção.
            </div>
        </div>
    </BaseLayout>
</template>
