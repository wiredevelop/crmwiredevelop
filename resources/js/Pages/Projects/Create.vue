<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import RichTextEditor from '@/Components/RichTextEditor.vue'
import { Head, useForm, Link } from '@inertiajs/vue3'
import { computed, watch, ref } from 'vue'

const props = defineProps({
    clients: Array,
    defaultTerms: String,
    catalog: Array, // produtos/packs do catálogo
})

const form = useForm({
    client_id: '',
    name: '',
    type: 'website',
    custom_type: '',
    status: 'planeamento',

    technologies: '',
    description: '',

    development_items: [
        { feature: 'Estrutura inicial do projeto (setup + ambiente)', hours: 2 },
        { feature: 'Páginas públicas (até 4)', hours: 8 },
    ],
    development_total_hours: 0,

    price_development: '',

    // Manutenção mensal (checkbox + input)
    maintenance_enabled: false,
    price_maintenance_monthly: '',

    include_domain: false,
    include_hosting: false,

    price_domain_first_year: '',
    price_domain_other_years: '',
    price_hosting_first_year: '',
    price_hosting_other_years: '',

    // imports (multi)
    imports: [],

    terms: props.defaultTerms || '',
})

/* ===== HORAS ===== */
const totalHours = computed(() =>
    form.development_items.reduce((sum, item) => {
        const h = parseFloat(item.hours)
        return isNaN(h) ? sum : sum + h
    }, 0)
)

watch(totalHours, (v) => {
    form.development_total_hours = v
}, { immediate: true })

const addFeature = () => form.development_items.push({ feature: '', hours: 1 })
const removeFeature = (i) => form.development_items.splice(i, 1)

/* ===== IMPORT MODAL ===== */
const importOpen = ref(false)
const selected = ref(null)

// para packs: por defeito seleciona todas as linhas
const selectedPackLines = ref([])

const openImport = (item) => {
    selected.value = item
    if (item.type === 'pack') {
        selectedPackLines.value = item.pack_items.map((_, i) => i)
    } else {
        selectedPackLines.value = []
    }
    importOpen.value = true
}

const toggleLine = (i) => {
    if (selectedPackLines.value.includes(i)) {
        selectedPackLines.value = selectedPackLines.value.filter(x => x !== i)
    } else {
        selectedPackLines.value.push(i)
    }
}

const confirmImport = () => {
    if (!selected.value) return

    const item = selected.value

    const payload = {
        product_id: item.id,
        type: item.type,
        name: item.name,
        slug: item.slug,
        short_description: item.short_description,
        content_html: item.content_html,
        price: item.price ?? null,
        pack_items: null,
        info_fields: null,
    }

    if (item.type === 'pack') {
        payload.pack_items = item.pack_items
            .filter((_, idx) => selectedPackLines.value.includes(idx))
            .map(x => ({
                hours: x.hours,
                normal_price: x.normal_price,
                pack_price: x.pack_price,
                validity_months: x.validity_months,
                featured: !!x.featured,
            }))
    }

    // info adicional só aparece se importar
    payload.info_fields = (item.info_fields || []).map(x => ({
        type: x.type,
        label: x.label,
        value: x.value,
    }))

    form.imports.push(payload)

    importOpen.value = false
    selected.value = null
}

const removeImport = (idx) => {
    form.imports.splice(idx, 1)
}

/* ===== TOTAL ESTIMADO ===== */
const totalEstimated = computed(() => {
    const dev = parseFloat(form.price_development) || 0
    const maint = form.maintenance_enabled ? (parseFloat(form.price_maintenance_monthly) || 0) : 0
    const domain = form.include_domain ? (parseFloat(form.price_domain_first_year) || 0) : 0
    const hosting = form.include_hosting ? (parseFloat(form.price_hosting_first_year) || 0) : 0
    return dev + maint + domain + hosting
})

const submit = () => {
    // garantir coerência
    if (!form.maintenance_enabled) form.price_maintenance_monthly = null
    if (!form.include_domain) {
        form.price_domain_first_year = null
        form.price_domain_other_years = null
    }
    if (!form.include_hosting) {
        form.price_hosting_first_year = null
        form.price_hosting_other_years = null
    }

    form.post('/projects')
}
</script>

<template>

    <Head title="Novo Projeto" />

    <BaseLayout>
        <template #title>Novo Projeto</template>

        <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-semibold">Criar Projeto + Orçamento</h1>

            <Link href="/projects" class="text-sm text-gray-600 hover:text-gray-900">
            ← Voltar à lista
            </Link>
        </div>

        <form @submit.prevent="submit" class="space-y-8">

            <!-- INFO BASE -->
            <div class="bg-white p-6 rounded shadow space-y-4">
                <h2 class="text-lg font-semibold">Informação do Projeto</h2>

                <div>
                    <label class="block text-sm font-medium mb-1">Cliente</label>
                    <select v-model="form.client_id" class="w-full border rounded p-2">
                        <option value="">— Cliente —</option>
                        <option v-for="c in clients" :key="c.id" :value="c.id">
                            {{ c.name }} <span v-if="c.company">({{ c.company }})</span>
                        </option>
                    </select>
                </div>

                <div>
                    <label class="block text-sm font-medium mb-1">Nome do projeto</label>
                    <input v-model="form.name" class="w-full border rounded p-2" placeholder="Nome do projeto" />
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium mb-1">Tipo</label>
                        <select v-model="form.type" class="w-full border rounded p-2">
                            <option value="website">Website</option>
                            <option value="loja_online">Loja Online</option>
                            <option value="landing_page">Landing Page</option>
                            <option value="plugin">Plugin</option>
                            <option value="outro">Outro</option>
                        </select>
                    </div>

                    <div v-if="form.type === 'outro'">
                        <label class="block text-sm font-medium mb-1">Tipo personalizado</label>
                        <input v-model="form.custom_type" class="w-full border rounded p-2"
                            placeholder="Tipo personalizado" />
                    </div>
                </div>

                <div>
                    <label class="block text-sm font-medium mb-1">Tecnologias</label>
                    <input v-model="form.technologies" class="w-full border rounded p-2"
                        placeholder="Laravel, Vue, ..." />
                </div>

                <div>
                    <label class="block text-sm font-medium mb-1">Descrição</label>
                    <RichTextEditor v-model="form.description" placeholder="Descrição do projeto" />
                </div>
            </div>

            <!-- DESENVOLVIMENTO -->
            <div class="bg-white p-6 rounded shadow space-y-4">
                <div class="flex justify-between items-center">
                    <h2 class="font-semibold text-lg">Desenvolvimento</h2>
                    <button type="button" @click="addFeature" class="text-sm border px-3 py-1 rounded hover:bg-gray-50">
                        + Linha
                    </button>
                </div>

                <div class="overflow-x-auto">
                    <table class="w-full text-sm border-collapse">
                        <thead>
                            <tr class="border-b bg-gray-50">
                                <th class="text-left px-3 py-2">Funcionalidade</th>
                                <th class="text-left px-3 py-2 w-28">Horas</th>
                                <th class="px-3 py-2 w-16"></th>
                            </tr>
                        </thead>

                        <tbody>
                            <tr v-for="(item, i) in form.development_items" :key="i" class="border-b">
                                <td class="px-3 py-2">
                                    <input v-model="item.feature" class="w-full border rounded p-2" />
                                </td>
                                <td class="px-3 py-2">
                                    <input type="number" step="0.5" v-model="item.hours"
                                        class="w-full border rounded p-2" />
                                </td>
                                <td class="px-3 py-2 text-right">
                                    <button type="button" @click="removeFeature(i)" class="text-red-600 hover:underline"
                                        v-if="form.development_items.length > 1">
                                        Remover
                                    </button>
                                </td>
                            </tr>
                        </tbody>

                        <tfoot>
                            <tr>
                                <td class="px-3 py-2 font-semibold text-right">Total horas:</td>
                                <td class="px-3 py-2 font-semibold">{{ totalHours }}</td>
                                <td></td>
                            </tr>
                        </tfoot>
                    </table>
                </div>
            </div>

            <!-- IMPORTAR PRODUTOS/PACKS -->
            <div class="bg-white p-6 rounded shadow space-y-4">
                <div class="flex justify-between items-center">
                    <h2 class="font-semibold text-lg">Produtos / Packs (Importar)</h2>
                    <span class="text-sm text-gray-500">Podes importar vários</span>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                    <button v-for="item in catalog" :key="item.id" type="button" @click="openImport(item)"
                        class="border rounded p-4 text-left hover:bg-gray-50">
                        <div class="flex items-center justify-between">
                            <div class="font-semibold">{{ item.name }}</div>
                            <div class="text-xs px-2 py-1 rounded bg-gray-100 capitalize">{{ item.type }}</div>
                        </div>
                        <div class="text-sm text-gray-500 mt-1" v-if="item.short_description">
                            {{ item.short_description }}
                        </div>
                    </button>
                </div>

                <div v-if="form.imports.length" class="pt-4 border-t space-y-3">
                    <h3 class="font-semibold">Importados no orçamento</h3>

                    <div v-for="(imp, idx) in form.imports" :key="idx"
                        class="border rounded p-4 flex justify-between items-start">
                        <div>
                            <div class="font-semibold">{{ imp.name }} <span class="text-xs text-gray-500 capitalize">({{
                                    imp.type }})</span></div>
                            <div class="text-sm text-gray-600" v-if="imp.type === 'pack'">
                                Linhas importadas: {{ imp.pack_items?.length || 0 }}
                            </div>
                            <div class="text-sm text-gray-600" v-if="imp.info_fields?.length">
                                Info adicional: {{ imp.info_fields.length }} campo(s)
                            </div>
                        </div>

                        <button type="button" @click="removeImport(idx)" class="text-red-600 hover:underline text-sm">
                            Remover
                        </button>
                    </div>
                </div>
            </div>

            <!-- VALORES -->
            <div class="bg-white p-6 rounded shadow space-y-4">
                <h2 class="font-semibold text-lg">Valores</h2>

                <div>
                    <label class="block text-sm font-medium mb-1">Desenvolvimento (€)</label>
                    <input v-model="form.price_development" type="number" step="0.01"
                        class="w-full border rounded p-2" />
                </div>

                <div class="border rounded p-4">
                    <label class="flex items-center gap-2 font-medium">
                        <input type="checkbox" v-model="form.maintenance_enabled" />
                        Manutenção mensal
                    </label>

                    <div v-if="form.maintenance_enabled" class="mt-3">
                        <label class="block text-sm font-medium mb-1">Valor mensal (€ / mês)</label>
                        <input v-model="form.price_maintenance_monthly" type="number" step="0.01"
                            class="w-full border rounded p-2" />
                    </div>
                </div>

                <div class="border rounded p-4 space-y-3">
                    <label class="flex items-center gap-2 font-medium">
                        <input type="checkbox" v-model="form.include_domain" />
                        Incluir domínio
                    </label>

                    <div v-if="form.include_domain" class="grid grid-cols-1 md:grid-cols-2 gap-3">
                        <div>
                            <label class="block text-sm mb-1">1º ano (€ / ano)</label>
                            <input v-model="form.price_domain_first_year" type="number" step="0.01"
                                class="w-full border rounded p-2" />
                        </div>
                        <div>
                            <label class="block text-sm mb-1">anos seguintes (€ / ano)</label>
                            <input v-model="form.price_domain_other_years" type="number" step="0.01"
                                class="w-full border rounded p-2" />
                        </div>
                    </div>
                </div>

                <div class="border rounded p-4 space-y-3">
                    <label class="flex items-center gap-2 font-medium">
                        <input type="checkbox" v-model="form.include_hosting" />
                        Incluir alojamento
                    </label>

                    <div v-if="form.include_hosting" class="grid grid-cols-1 md:grid-cols-2 gap-3">
                        <div>
                            <label class="block text-sm mb-1">1º ano (€ / ano)</label>
                            <input v-model="form.price_hosting_first_year" type="number" step="0.01"
                                class="w-full border rounded p-2" />
                        </div>
                        <div>
                            <label class="block text-sm mb-1">anos seguintes (€ / ano)</label>
                            <input v-model="form.price_hosting_other_years" type="number" step="0.01"
                                class="w-full border rounded p-2" />
                        </div>
                    </div>
                </div>

                <div class="text-right font-semibold text-lg">
                    Total estimado (inicial): {{ totalEstimated.toFixed(2).replace('.', ',') }} €
                </div>
            </div>

            <!-- PRAZOS -->
            <div class="bg-white p-6 rounded shadow">
                <h2 class="font-semibold text-lg mb-2">Prazos & Condições</h2>
                <textarea v-model="form.terms" rows="8" class="w-full border rounded p-2 font-mono"></textarea>
            </div>

            <div class="flex justify-end">
                <button class="bg-[#015557] text-white px-6 py-2 rounded hover:bg-[#014244]"
                    :disabled="form.processing">
                    Guardar Projeto & Orçamento
                </button>
            </div>
        </form>

        <!-- MODAL IMPORT -->
        <div v-if="importOpen" class="fixed inset-0 bg-black/50 flex items-center justify-center p-4">
            <div class="bg-white rounded shadow max-w-2xl w-full p-6 space-y-4">
                <div class="flex justify-between items-start">
                    <div>
                        <div class="text-lg font-semibold">Importar: {{ selected?.name }}</div>
                        <div class="text-sm text-gray-500 capitalize">Tipo: {{ selected?.type }}</div>
                    </div>
                    <button type="button" class="text-gray-500 hover:text-gray-900" @click="importOpen = false">✕</button>
                </div>

                <div v-if="selected?.type === 'pack'" class="space-y-2">
                    <div class="font-semibold">Linhas do pack (seleciona o que queres importar)</div>

                    <div v-for="(line, i) in selected.pack_items" :key="i"
                        class="border rounded p-3 flex items-center justify-between">
                        <label class="flex items-center gap-2">
                            <input type="checkbox" :checked="selectedPackLines.includes(i)" @change="toggleLine(i)" />
                            <span class="font-medium">{{ line.hours }} horas</span>
                        </label>

                        <div class="text-sm text-gray-600">
                            {{ Number(line.normal_price).toFixed(2).replace('.', ',') }} €
                            →
                            <span class="font-semibold text-[#015557]">{{
                                Number(line.pack_price).toFixed(2).replace('.', ',')
                                }} €</span>
                            · {{ line.validity_months }} meses
                            <span v-if="line.featured"
                                class="ml-2 text-xs px-2 py-1 rounded bg-[#015557] text-white">MAIS
                                VENDIDO</span>
                        </div>
                    </div>
                </div>

                <div class="flex justify-end gap-2 pt-3 border-t">
                    <button type="button" class="px-4 py-2 border rounded" @click="importOpen = false">Cancelar</button>
                    <button type="button" class="px-4 py-2 rounded bg-[#015557] text-white" @click="confirmImport">
                        Importar
                    </button>
                </div>
            </div>
        </div>

    </BaseLayout>
</template>
