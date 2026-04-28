<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { Head, useForm, Link, router } from '@inertiajs/vue3'
import { ref } from 'vue'

const props = defineProps({
    product: Object
})

const form = useForm({
    type: props.product.type ?? 'product',
    name: props.product.name ?? '',
    price: props.product.price ?? '',
    short_description: props.product.short_description ?? '',
    content_html: props.product.content_html ?? '',
    pack_items: props.product.pack_items ?? [],
    info_fields: props.product.info_fields ?? []
})

/* ========= PACK ========= */
const addPackItem = () => {
    form.pack_items.push({
        hours: '',
        normal_price: '',
        pack_price: '',
        validity_months: '',
        featured: false
    })
}

const removePackItem = (index) => {
    form.pack_items.splice(index, 1)
}

/* ========= INFO FIELDS ========= */
const newFieldType = ref('text')

const addInfoField = () => {
    form.info_fields.push({
        type: newFieldType.value,
        label: '',
        value: newFieldType.value === 'boolean' ? false : ''
    })
}

const removeInfoField = (index) => {
    form.info_fields.splice(index, 1)
}

const submit = () => {
    form.put(`/products/${props.product.id}`, {
        preserveScroll: true
    })
}

const destroyThis = () => {
    if (!confirm(`Apagar "${form.name}"? Isto não tem volta.`)) return
    router.delete(`/products/${props.product.id}`)
}
</script>

<template>

    <Head :title="`Editar: ${form.name || 'Produto / Pack'}`" />

    <BaseLayout>
        <template #title>Editar Produto / Pack</template>

        <form @submit.prevent="submit" class="bg-white p-6 rounded shadow space-y-8 max-w-5xl">

            <div class="flex justify-between items-center">
                <div>
                    <h2 class="text-xl font-semibold">{{ form.name || '—' }}</h2>
                    <p class="text-sm text-gray-500">Editar informação, linhas de pack e campos dinâmicos.</p>
                </div>

                <div class="flex gap-2">
                    <a :href="`/products/${props.product.id}/pdf`" target="_blank" class="px-4 py-2 border rounded">
                        PDF
                    </a>

                    <button type="button" @click="destroyThis" class="px-4 py-2 border rounded text-red-600">
                        Apagar
                    </button>
                </div>
            </div>

            <!-- TIPO (não deixo trocar no edit por segurança; se quiseres, eu abro) -->
            <div>
                <label class="block text-sm font-medium mb-1">Tipo</label>
                <input class="w-full border rounded p-2 bg-gray-50" :value="form.type" disabled />
            </div>

            <!-- NOME -->
            <div>
                <label class="block text-sm font-medium mb-1">Nome</label>
                <input v-model="form.name" class="w-full border rounded p-2" required />
            </div>

            <!-- PREÇO (APENAS PRODUTO) -->
            <div v-if="form.type === 'product'">
                <label class="block text-sm font-medium mb-1">Preço</label>
                <input v-model="form.price" type="number" step="0.01" class="w-full border rounded p-2" />
            </div>

            <!-- DESCRIÇÃO CURTA -->
            <div>
                <label class="block text-sm font-medium mb-1">Descrição curta</label>
                <textarea v-model="form.short_description" class="w-full border rounded p-2" />
            </div>

            <!-- CONTEÚDO HTML -->
            <div>
                <label class="block text-sm font-medium mb-1">Conteúdo</label>
                <textarea v-model="form.content_html" class="w-full border rounded p-2 h-40"
                    placeholder="Conteúdo detalhado (HTML permitido)" />
                <p class="text-xs text-gray-500 mt-1">
                    Isto serve para descrição completa: página pública, PDF, e propostas. É o “texto de venda” do
                    produto/pack.
                </p>
            </div>

            <!-- CONFIGURAÇÃO DO PACK -->
            <div v-if="form.type === 'pack'" class="border-t pt-6 space-y-4">

                <div class="flex justify-between items-center">
                    <h3 class="font-semibold text-lg">Opções do Pack</h3>
                    <button type="button" @click="addPackItem" class="text-blue-600 hover:underline">
                        + Adicionar linha
                    </button>
                </div>

                <div v-for="(item, i) in form.pack_items" :key="i" class="grid grid-cols-6 gap-3 border p-4 rounded">
                    <input v-model="item.hours" placeholder="Horas" class="border p-2 rounded" />
                    <input v-model="item.normal_price" placeholder="Preço normal" class="border p-2 rounded" />
                    <input v-model="item.pack_price" placeholder="Preço pack" class="border p-2 rounded" />
                    <input v-model="item.validity_months" placeholder="Validade (meses)" class="border p-2 rounded" />

                    <label class="flex items-center gap-2 text-sm">
                        <input type="checkbox" v-model="item.featured" />
                        Destaque
                    </label>

                    <button type="button" @click="removePackItem(i)" class="text-red-600 text-sm">
                        Remover
                    </button>
                </div>

                <p v-if="!form.pack_items.length" class="text-sm text-gray-500">
                    Adiciona pelo menos uma linha ao pack.
                </p>
            </div>

            <!-- CAMPOS INFORMATIVOS -->
            <div class="border-t pt-6 space-y-4">
                <h3 class="font-semibold text-lg">Informação adicional</h3>

                <div class="flex gap-3 items-end">
                    <select v-model="newFieldType" class="border p-2 rounded">
                        <option value="text">Texto</option>
                        <option value="textarea">Textarea</option>
                        <option value="html">HTML</option>
                        <option value="boolean">Sim / Não</option>
                    </select>

                    <button type="button" @click="addInfoField" class="bg-gray-200 px-4 py-2 rounded">
                        Criar campo
                    </button>
                </div>

                <div v-for="(field, i) in form.info_fields" :key="i" class="space-y-2 border p-4 rounded">
                    <div class="flex justify-between items-center">
                        <p class="text-sm font-medium">Campo {{ i + 1 }} ({{ field.type }})</p>
                        <button type="button" class="text-red-600 text-sm" @click="removeInfoField(i)">Remover</button>
                    </div>

                    <input v-model="field.label" class="border p-2 rounded w-full" placeholder="Label" />

                    <input v-if="field.type === 'text'" v-model="field.value" class="border p-2 rounded w-full" />

                    <textarea v-if="field.type === 'textarea'" v-model="field.value"
                        class="border p-2 rounded w-full" />

                    <textarea v-if="field.type === 'html'" v-model="field.value"
                        class="border p-2 rounded w-full h-32" />

                    <label v-if="field.type === 'boolean'" class="flex items-center gap-2">
                        <input type="checkbox" v-model="field.value" />
                        Sim
                    </label>
                </div>
            </div>

            <!-- AÇÕES -->
            <div class="flex justify-end gap-3 border-t pt-6">
                <Link href="/products" class="px-4 py-2 border rounded">
                Voltar
                </Link>

                <button type="submit" class="bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700">
                    Guardar alterações
                </button>
            </div>

        </form>
    </BaseLayout>
</template>
