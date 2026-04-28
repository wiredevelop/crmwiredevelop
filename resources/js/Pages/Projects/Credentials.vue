<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { Link, useForm, usePage } from '@inertiajs/vue3'
import { computed, ref } from 'vue'

const page = usePage()
const props = page.props
const project = props.project
const credentials = computed(() => props.credentials ?? [])
const visiblePasswords = ref({})

const credentialForm = useForm({
    label: '',
    username: '',
    password: '',
    url: '',
    notes: '',
})

function addCredential() {
    if (!credentialForm.label.trim() || !credentialForm.password.trim()) return

    credentialForm.post(`/projects/${project.id}/credentials`, {
        preserveScroll: true,
        onSuccess: () => {
            credentialForm.reset()
        }
    })
}

function togglePassword(id) {
    visiblePasswords.value[id] = !visiblePasswords.value[id]
}

async function copyCredential(cred) {
    if (!cred?.password) return

    try {
        await navigator.clipboard.writeText(cred.password)
    } catch (error) {
        console.error('Copy failed:', error)
    }
}
</script>

<template>
    <BaseLayout>
        <template #title>Acessos - {{ project.name }}</template>

        <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between mb-6">
            <div>
                <h1 class="text-2xl font-semibold">{{ project.name }}</h1>
                <p class="text-sm text-gray-500">
                    Cliente: {{ project.client?.name || '—' }}
                </p>
            </div>
            <Link :href="`/clients/${project.client_id}`" class="text-sm text-[#015557] hover:underline">
                Voltar ao cliente
            </Link>
        </div>

        <div class="bg-white shadow rounded p-6 mb-6">
            <div class="flex flex-col gap-2 lg:flex-row lg:items-center lg:justify-between mb-4">
                <h2 class="text-xl font-semibold">Acessos e Senhas</h2>
                <p class="text-sm text-gray-500">Guarde acessos, URLs e notas por projeto.</p>
            </div>

            <form @submit.prevent="addCredential" class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
                <div>
                    <label>Serviço *</label>
                    <input v-model="credentialForm.label" class="input" required />
                </div>

                <div>
                    <label>Utilizador</label>
                    <input v-model="credentialForm.username" class="input" />
                </div>

                <div>
                    <label>Senha *</label>
                    <input v-model="credentialForm.password" type="password" class="input" required />
                </div>

                <div>
                    <label>URL</label>
                    <input v-model="credentialForm.url" type="url" class="input" placeholder="https://..." />
                </div>

                <div class="md:col-span-2">
                    <label>Notas</label>
                    <textarea v-model="credentialForm.notes" rows="3" class="input"></textarea>
                </div>

                <div class="md:col-span-2 flex justify-end">
                    <button type="submit" class="bg-[#015557] text-white px-4 py-2 rounded">
                        Guardar Acesso
                    </button>
                </div>
            </form>

            <div v-if="credentials.length" class="overflow-x-auto">
                <table class="min-w-[900px] w-full text-left text-sm">
                    <thead>
                    <tr class="bg-gray-50 border-b">
                        <th class="py-2 px-2">Serviço</th>
                        <th class="py-2 px-2">Utilizador</th>
                        <th class="py-2 px-2">Senha</th>
                        <th class="py-2 px-2">URL</th>
                        <th class="py-2 px-2">Notas</th>
                        <th class="py-2 px-2">Criado</th>
                        <th class="py-2 px-2 w-20"></th>
                    </tr>
                    </thead>
                    <tbody>
                    <tr v-for="cred in credentials" :key="cred.id" class="border-b hover:bg-gray-50">
                        <td class="py-2 px-2 font-medium">{{ cred.label }}</td>
                        <td class="py-2 px-2">{{ cred.username || '—' }}</td>
                        <td class="py-2 px-2">
                            <div class="flex items-center gap-2">
                                <span class="font-mono text-xs break-all">
                                    {{ visiblePasswords[cred.id] ? cred.password : '******' }}
                                </span>
                                <button type="button"
                                        class="text-xs text-blue-600 hover:underline"
                                        @click="togglePassword(cred.id)">
                                    {{ visiblePasswords[cred.id] ? 'Ocultar' : 'Mostrar' }}
                                </button>
                                <button
                                    type="button"
                                    class="text-xs text-blue-600 hover:underline"
                                    @click="copyCredential(cred)"
                                >
                                    Copiar
                                </button>
                            </div>
                        </td>
                        <td class="py-2 px-2">
                            <a v-if="cred.url" :href="cred.url" target="_blank"
                               class="text-blue-600 hover:underline break-all">
                                {{ cred.url }}
                            </a>
                            <span v-else>—</span>
                        </td>
                        <td class="py-2 px-2">
                            <span class="whitespace-pre-line">{{ cred.notes || '—' }}</span>
                        </td>
                        <td class="py-2 px-2">
                            {{ cred.created_at ? new Date(cred.created_at).toLocaleDateString('pt-PT') : '—' }}
                        </td>
                        <td class="py-2 px-2 text-right">
                            <Link as="button" method="delete"
                                  :href="`/projects/${project.id}/credentials/${cred.id}`"
                                  class="text-red-600 hover:underline text-xs">
                                Apagar
                            </Link>
                        </td>
                    </tr>
                    </tbody>
                </table>
            </div>

            <p v-else class="text-gray-500 text-sm">Sem credenciais guardadas.</p>
        </div>
    </BaseLayout>
</template>

<style scoped>
.input {
    @apply w-full border rounded px-3 py-2;
}
</style>
