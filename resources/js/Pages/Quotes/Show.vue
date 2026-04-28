<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { Link, usePage } from '@inertiajs/vue3'

const { quote } = usePage().props

const formatDescription = (raw) => {
    if (!raw) return ''
    const hasTags = /<\\s*[\\w-]+[^>]*>/.test(raw)
    if (hasTags) return raw
    const escaped = raw
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/\"/g, '&quot;')
        .replace(/'/g, '&#39;')
    return escaped.replace(/\\r\\n|\\r|\\n/g, '<br>')
}
</script>

<template>
    <BaseLayout>
        <template #title>Orçamento</template>

        <div class="bg-white p-6 rounded shadow max-w-3xl mx-auto">

            <h1 class="text-2xl font-semibold mb-4">
                Orçamento — {{ quote.project?.name }}
            </h1>

            <p class="text-gray-600 mb-4">
                Cliente: {{ quote.project?.client?.name }}
            </p>

            <!-- PDF -->
            <Link :href="route('quotes.pdf', quote.id)" class="bg-black text-white px-4 py-2 rounded">
            📄 Download PDF
            </Link>

            <hr class="my-6">

            <h2 class="text-xl font-semibold">Descrição</h2>
            <div class="text-sm" v-html="formatDescription(quote.description)"></div>

            <h2 class="text-xl font-semibold mt-4">Desenvolvimento</h2>
            <ul class="list-disc ml-6">
                <li v-for="(item, i) in quote.development_items" :key="i">
                    {{ item.feature }} — {{ item.hours }}h
                </li>
            </ul>

            <h2 class="text-xl font-semibold mt-4">Valores</h2>
            <p>Desenvolvimento: {{ quote.price_development }} €</p>
            <p>Domínio (1º ano): {{ quote.price_domain_first_year }} €</p>
            <p>Alojamento (1º ano): {{ quote.price_hosting_first_year }} €</p>

        </div>
    </BaseLayout>
</template>
