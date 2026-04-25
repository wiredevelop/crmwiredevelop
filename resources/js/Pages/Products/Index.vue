<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { Head, Link, router } from '@inertiajs/vue3'

const props = defineProps({
    products: Array,
    type: String
})

const destroyProduct = (product) => {
    if (!confirm(`Apagar "${product.name}"? Isto não tem volta.`)) return

    router.delete(`/products/${product.id}`, {
        preserveScroll: true
    })
}

const togglePaymentMethods = (product) => {
    router.patch(`/products/${product.id}/payment-methods`, {
        show_payment_methods: !product.show_payment_methods
    }, {
        preserveScroll: true
    })
}
</script>

<template>

    <Head title="Produtos / Packs" />

    <BaseLayout>
        <template #title>Produtos / Packs</template>

        <div class="bg-white p-6 rounded shadow space-y-4">

            <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                <div>
                    <h2 class="text-xl font-semibold">Produtos / Packs</h2>
                    <p class="text-sm text-gray-500">Catálogo interno para propostas, packs e páginas públicas.</p>
                </div>

                <div class="flex gap-2">
                    <Link href="/products?type=product" class="px-3 py-2 border rounded"
                        :class="!type || type === 'product' ? 'bg-gray-100' : ''">
                    Produtos
                    </Link>

                    <Link href="/products?type=pack" class="px-3 py-2 border rounded"
                        :class="type === 'pack' ? 'bg-gray-100' : ''">
                    Packs
                    </Link>

                    <Link href="/products/create" class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
                    + Criar
                    </Link>
                </div>
            </div>

            <p v-if="!products.length" class="text-gray-500">
                Nenhum produto ou pack disponível.
            </p>

            <div v-else class="overflow-x-auto">
                <table class="min-w-[720px] w-full border">
                    <thead class="bg-gray-100">
                        <tr>
                            <th class="p-2 text-left">Nome</th>
                            <th class="p-2 text-center">Tipo</th>
                            <th class="p-2 text-center">Preço</th>
                            <th class="p-2 text-center">Estado</th>
                            <th class="p-2 text-right">Ações</th>
                        </tr>
                    </thead>

                    <tbody>
                        <tr v-for="product in products" :key="product.id" class="border-t">
                            <td class="p-2 font-medium">{{ product.name }}</td>

                            <td class="p-2 text-center capitalize">{{ product.type }}</td>

                            <td class="p-2 text-center">
                                {{ product.price ? product.price + ' €' : '—' }}
                            </td>

                            <td class="p-2 text-center">
                                <span :class="product.active ? 'text-green-600' : 'text-red-600'">
                                    {{ product.active ? 'Ativo' : 'Inativo' }}
                                </span>
                            </td>

                            <td class="p-2 text-right">
                                <div class="flex items-center justify-end gap-3">
                                    <button type="button" title="Métodos de pagamento no PDF"
                                        @click="togglePaymentMethods(product)"
                                        class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors"
                                        :class="product.show_payment_methods ? 'bg-emerald-500' : 'bg-gray-300'">
                                        <span class="sr-only">Métodos de pagamento no PDF</span>
                                        <span class="inline-block h-5 w-5 transform rounded-full bg-white transition-transform"
                                            :class="product.show_payment_methods ? 'translate-x-5' : 'translate-x-1'"></span>
                                    </button>

                                <a :href="`/products/${product.id}/pdf`" target="_blank"
                                    class="text-gray-700 hover:underline">
                                    PDF
                                </a>

                                <Link :href="`/products/${product.id}/edit`" class="text-blue-600 hover:underline">
                                Editar
                                </Link>

                                <button type="button" @click="destroyProduct(product)" class="text-red-600 hover:underline">
                                    Apagar
                                </button>
                                </div>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>

        </div>
    </BaseLayout>
</template>
