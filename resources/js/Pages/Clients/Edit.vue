<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { useForm, usePage } from '@inertiajs/vue3'

const client = usePage().props.client

const form = useForm({
    name: client.name,
    company: client.company,
    email: client.email,
    phone: client.phone,
    vat: client.vat,
    address: client.address,
    hourly_rate: client.hourly_rate,
    notes: client.notes,
})

function submit() {
    form.put(`/clients/${client.id}`)
}
</script>

<template>
    <BaseLayout>
        <template #title>Editar Cliente</template>

        <div class="bg-white p-6 rounded shadow w-full max-w-2xl">
            <form @submit.prevent="submit">

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                    <div>
                        <label>Nome *</label>
                        <input v-model="form.name" class="input" required />
                    </div>

                    <div>
                        <label>Empresa</label>
                        <input v-model="form.company" class="input" />
                    </div>

                    <div>
                        <label>Email</label>
                        <input v-model="form.email" class="input" />
                    </div>

                    <div>
                        <label>Telefone</label>
                        <input v-model="form.phone" class="input" />
                    </div>

                    <div>
                        <label>NIF / VAT</label>
                        <input v-model="form.vat" class="input" />
                    </div>

                    <div>
                        <label>Morada</label>
                        <input v-model="form.address" class="input" />
                    </div>

                    <div>
                        <label>Valor/hora</label>
                        <input v-model.number="form.hourly_rate" type="number" step="0.01" min="0" class="input" />
                    </div>
                </div>

                <div class="mb-4">
                    <label>Notas</label>
                    <textarea v-model="form.notes" class="input"></textarea>
                </div>

                <button class="bg-[#015557] text-white px-4 py-2 rounded">
                    Atualizar
                </button>
            </form>
        </div>
    </BaseLayout>
</template>

<style scoped>
.input {
    @apply w-full border rounded px-3 py-2;
}
</style>
