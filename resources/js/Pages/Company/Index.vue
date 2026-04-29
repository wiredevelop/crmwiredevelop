<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { Head, useForm, usePage } from '@inertiajs/vue3'
import { computed } from 'vue'

const page = usePage()
const company = page.props.company || {}

const form = useForm({
    name: company.name || '',
    vat: company.vat || '',
    address: company.address || '',
    city: company.city || '',
    postal_code: company.postal_code || '',
    country: company.country || '',
    email: company.email || '',
    phone: company.phone || '',
    website: company.website || '',
    iban: company.iban || '',
    bank_name: company.bank_name || '',
    swift: company.swift || '',
    client_checkout_method: company.client_checkout_method || 'stripe',
    payment_notes: company.payment_notes || '',
    payment_methods: Array.isArray(company.payment_methods) ? company.payment_methods : []
})

const submit = () => {
    form.post('/company', { preserveScroll: true })
}

const paymentMethods = computed(() => form.payment_methods)

const addMethod = () => {
    form.payment_methods.push({ label: '', value: '' })
}

const removeMethod = (index) => {
    form.payment_methods.splice(index, 1)
}
</script>

<template>
    <Head title="Dados da Empresa" />

    <BaseLayout>
        <template #title>Dados da Empresa</template>

        <div class="bg-white rounded shadow p-6 max-w-3xl">
            <h1 class="text-2xl font-semibold">Dados da Empresa</h1>
            <p class="text-sm text-gray-500 mt-2">
                Estes dados aparecem no rodape dos PDFs e na secao de pagamento.
            </p>

            <form @submit.prevent="submit" class="mt-6 space-y-5">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label class="block text-sm font-medium mb-1">Nome da empresa</label>
                        <input v-model="form.name" class="w-full border rounded px-3 py-2 text-sm" />
                    </div>
                    <div>
                        <label class="block text-sm font-medium mb-1">NIF / VAT</label>
                        <input v-model="form.vat" class="w-full border rounded px-3 py-2 text-sm" />
                    </div>
                    <div>
                        <label class="block text-sm font-medium mb-1">Email</label>
                        <input v-model="form.email" class="w-full border rounded px-3 py-2 text-sm" />
                    </div>
                    <div>
                        <label class="block text-sm font-medium mb-1">Telefone</label>
                        <input v-model="form.phone" class="w-full border rounded px-3 py-2 text-sm" />
                    </div>
                    <div>
                        <label class="block text-sm font-medium mb-1">Website</label>
                        <input v-model="form.website" class="w-full border rounded px-3 py-2 text-sm" />
                    </div>
                    <div>
                        <label class="block text-sm font-medium mb-1">Pais</label>
                        <input v-model="form.country" class="w-full border rounded px-3 py-2 text-sm" />
                    </div>
                    <div class="md:col-span-2">
                        <label class="block text-sm font-medium mb-1">Morada</label>
                        <input v-model="form.address" class="w-full border rounded px-3 py-2 text-sm" />
                    </div>
                    <div>
                        <label class="block text-sm font-medium mb-1">Cidade</label>
                        <input v-model="form.city" class="w-full border rounded px-3 py-2 text-sm" />
                    </div>
                    <div>
                        <label class="block text-sm font-medium mb-1">Codigo postal</label>
                        <input v-model="form.postal_code" class="w-full border rounded px-3 py-2 text-sm" />
                    </div>
                </div>

                <div class="border-t pt-5">
                    <h2 class="text-lg font-semibold mb-3">Dados para pagamento</h2>
                    <div class="mb-4">
                        <label class="block text-sm font-medium mb-1">Método em destaque no checkout</label>
                        <select v-model="form.client_checkout_method" class="w-full border rounded px-3 py-2 text-sm">
                            <option value="stripe">Stripe</option>
                            <option value="manual">Manual</option>
                        </select>
                        <p class="mt-1 text-xs text-gray-500">
                            Os dois métodos podem coexistir. Esta opção só define qual deles fica destacado primeiro quando ambos estiverem configurados.
                        </p>
                    </div>
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                            <label class="block text-sm font-medium mb-1">IBAN</label>
                            <input v-model="form.iban" class="w-full border rounded px-3 py-2 text-sm" />
                        </div>
                        <div>
                            <label class="block text-sm font-medium mb-1">Banco</label>
                            <input v-model="form.bank_name" class="w-full border rounded px-3 py-2 text-sm" />
                        </div>
                        <div>
                            <label class="block text-sm font-medium mb-1">SWIFT / BIC</label>
                            <input v-model="form.swift" class="w-full border rounded px-3 py-2 text-sm" />
                        </div>
                    </div>
                    <div class="mt-4">
                        <label class="block text-sm font-medium mb-1">Notas de pagamento</label>
                        <textarea v-model="form.payment_notes" rows="3"
                            class="w-full border rounded px-3 py-2 text-sm"></textarea>
                    </div>
                    <div class="mt-6">
                        <div class="flex items-center justify-between mb-2">
                            <label class="block text-sm font-medium">Metodos de pagamento adicionais</label>
                            <button type="button" class="text-sm text-[#015557] hover:underline" @click="addMethod">
                                + Adicionar metodo
                            </button>
                        </div>

                        <div v-if="paymentMethods.length" class="space-y-3">
                            <div
                                v-for="(method, index) in paymentMethods"
                                :key="index"
                                class="grid grid-cols-1 md:grid-cols-3 gap-3"
                            >
                                <input
                                    v-model="method.label"
                                    placeholder="Ex: MB WAY, PayPal"
                                    class="w-full border rounded px-3 py-2 text-sm"
                                />
                                <input
                                    v-model="method.value"
                                    placeholder="Detalhes / conta"
                                    class="w-full border rounded px-3 py-2 text-sm md:col-span-2"
                                />
                                <div class="md:col-span-3 text-right">
                                    <button
                                        type="button"
                                        class="text-xs text-red-600 hover:underline"
                                        @click="removeMethod(index)"
                                    >
                                        Remover
                                    </button>
                                </div>
                            </div>
                        </div>
                        <p v-else class="text-xs text-gray-500">Sem metodos adicionais.</p>
                    </div>
                </div>

                <div class="flex justify-end">
                    <button type="submit"
                        class="bg-[#015557] text-white px-4 py-2 rounded hover:bg-[#014548] disabled:opacity-50"
                        :disabled="form.processing">
                        Guardar dados
                    </button>
                </div>
            </form>
        </div>
    </BaseLayout>
</template>
