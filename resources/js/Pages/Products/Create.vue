<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { Head, useForm, Link } from '@inertiajs/vue3'
import { ref } from 'vue'

const form = useForm({
    type: 'product',
    name: '',
    price: '',                // só usado em product
    short_description: '',
    content_html: '',

    pack_items: [],           // linhas do pack
    info_fields: []           // campos informativos dinâmicos
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
        value: ''
    })
}
</script>

<template>

    <Head title="Criar Produto / Pack" />

    <BaseLayout>
        <template #title>Criar Produto / Pack</template>

        <!-- FORM -->
        <form @submit.prevent="form.post('/products')" class="bg-white p-6 rounded shadow space-y-8 max-w-5xl">

            <!-- TIPO -->
            <div>
                <label class="block text-sm font-medium mb-1">Tipo</label>
                <select v-model="form.type" class="w-full border rounded p-2">
                    <option value="product">Produto</option>
                    <option value="pack">Pack</option>
                </select>
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

                <div v-for="(field, i) in form.info_fields" :key="i" class="space-y-1 border p-4 rounded">
                    <input v-model="field.label" class="border p-2 rounded w-full" placeholder="Label" />

                    <input v-if="field.type === 'text'" v-model="field.value" class="border p-2 rounded w-full" />

                    <textarea v-if="field.type === 'textarea'" v-model="field.value"
                        class="border p-2 rounded w-full" />

                    <textarea v-if="field.type === 'html'" v-model="field.value"
                        class="border p-2 rounded w-full h-32" />

                    <label v-if="field.type === 'boolean'" class="flex items-center gap-2">
                        <input type="checkbox" v-model="field.value" />
                        Ativo
                    </label>
                </div>
            </div>

            <!-- AÇÕES -->
            <div class="flex justify-end gap-3 border-t pt-6">
                <Link href="/products" class="px-4 py-2 border rounded">
                Cancelar
                </Link>

                <button type="submit" class="bg-blue-600 text-white px-6 py-2 rounded hover:bg-blue-700">
                    Guardar
                </button>
            </div>

        </form>
    </BaseLayout>
</template>
