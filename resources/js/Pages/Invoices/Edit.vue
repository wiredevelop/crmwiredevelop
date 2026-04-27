<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { useForm, usePage } from '@inertiajs/vue3'
import { computed } from 'vue'

const { invoice, items } = usePage().props

const form = useForm({
    payment_method: invoice.payment_method ?? '',
    payment_account: invoice.payment_account ?? '',
    items: Array.isArray(items) && items.length
        ? items.map((item) => ({
            description: item.description ?? '',
            quantity: item.quantity ?? 1,
            unit_price: item.unit_price ?? 0
        }))
        : [
            {
                description: invoice.project?.name || 'Servico',
                quantity: 1,
                unit_price: invoice.total ?? 0
            }
        ]
})

const addItem = () => {
    form.items.push({
        description: '',
        quantity: 1,
        unit_price: 0
    })
}

const removeItem = (index) => {
    form.items.splice(index, 1)
}

const total = computed(() =>
    form.items.reduce((sum, item) => {
        const qty = parseFloat(item.quantity) || 0
        const price = parseFloat(item.unit_price) || 0
        return sum + qty * price
    }, 0)
)
</script>

<template>
    <BaseLayout>
        <template #title>Pagamento do Documento</template>

        <form @submit.prevent="form.put(route('invoices.update', invoice.id))"
            class="bg-white p-6 rounded shadow max-w-3xl mx-auto space-y-6">

            <div>
                <h2 class="text-lg font-semibold">Itens do documento</h2>
                <p class="text-sm text-gray-500">Podes agregar vários itens no mesmo documento.</p>

                <div class="mt-4 space-y-3">
                    <div v-for="(item, index) in form.items" :key="index"
                        class="grid grid-cols-1 md:grid-cols-6 gap-3">
                        <input v-model="item.description"
                            class="input md:col-span-3"
                            placeholder="Descricao" />
                        <input v-model.number="item.quantity" type="number" min="0.01" step="0.01"
                            class="input md:col-span-1" />
                        <input v-model.number="item.unit_price" type="number" min="0" step="0.01"
                            class="input md:col-span-2" />
                        <div class="md:col-span-6 text-right">
                            <button type="button" class="text-xs text-red-600 hover:underline"
                                @click="removeItem(index)" v-if="form.items.length > 1">
                                Remover
                            </button>
                        </div>
                    </div>
                </div>

                <button type="button" class="mt-3 text-sm text-[#015557] hover:underline" @click="addItem">
                    + Adicionar linha
                </button>

                <div class="mt-4 text-right text-sm font-semibold">
                    Total: {{ total.toFixed(2) }} €
                </div>
            </div>

            <div>
                <label>Método de Pagamento</label>
                <select v-model="form.payment_method" class="input">
                    <option value="">Selecionar…</option>
                    <option value="transferencia">Transferência Bancária</option>
                    <option value="mbway">MB Way</option>
                    <option value="multibanco">Multibanco</option>
                    <option value="paypal">PayPal</option>
                    <option value="revolut">Revolut</option>
                </select>
            </div>

            <div>
                <label>Conta onde foi pago</label>
                <input v-model="form.payment_account" class="input"
                    placeholder="Ex: Santander Empresa, Revolut Business…" />
            </div>

            <button class="bg-[#015557] text-white px-4 py-2 rounded">
                Guardar
            </button>

        </form>
    </BaseLayout>
</template>

<style scoped>
.input {
    @apply w-full border rounded px-3 py-2 text-sm;
}
</style>
