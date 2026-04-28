<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { useForm } from '@inertiajs/vue3'
import { watch } from 'vue'

const form = useForm({
    name: '',
    company: '',
    email: '',
    phone: '',
    vat: '',
    address: '',
    hourly_rate: '',
    notes: '',
    create_portal_user: false,
    portal_email: '',
    portal_password: '',
})

function submit() {
    form.post('/clients')
}

function generateTemporaryPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
    let password = ''

    for (let i = 0; i < 12; i += 1) {
        password += chars[Math.floor(Math.random() * chars.length)]
    }

    form.portal_password = password
}

watch(() => form.email, (value) => {
    if (!form.portal_email) {
        form.portal_email = value
    }
})
</script>

<template>
    <BaseLayout>
        <template #title>Novo Cliente</template>

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

                <div class="mb-6 rounded-lg border border-gray-200 p-4">
                    <label class="flex items-center gap-2 font-medium">
                        <input v-model="form.create_portal_user" type="checkbox" />
                        Criar acesso para cliente
                    </label>

                    <div v-if="form.create_portal_user" class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                        <div>
                            <label>Email de acesso *</label>
                            <input v-model="form.portal_email" type="email" class="input" required />
                        </div>

                        <div>
                            <label>Senha temporária</label>
                            <div class="flex gap-2">
                                <input v-model="form.portal_password" class="input" placeholder="Vazio = gerar automática" />
                                <button type="button" class="bg-gray-100 px-3 py-2 rounded border" @click="generateTemporaryPassword">
                                    Gerar
                                </button>
                            </div>
                            <p class="mt-1 text-xs text-gray-500">O cliente terá de alterar esta senha no 1º login.</p>
                        </div>
                    </div>
                </div>

                <button class="bg-[#015557] text-white px-4 py-2 rounded">
                    Guardar
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
