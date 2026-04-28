<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { usePage } from '@inertiajs/vue3'
import { ref } from 'vue'

const page = usePage()
const props = page.props
const client = props.client ?? {}
const objects = props.objects ?? []
const revealedPasswords = ref({})

function togglePassword(id) {
    revealedPasswords.value[id] = !revealedPasswords.value[id]
}

async function copyText(value) {
    if (!value) return

    try {
        await navigator.clipboard.writeText(value)
    } catch (error) {
        console.error('Copy failed:', error)
    }
}

function badgeStatus(status) {
    const labels = {
        planeamento: 'Planeamento',
        em_andamento: 'Em andamento',
        aguardar_conteudos: 'Aguardar conteúdos',
        em_revisao: 'Em revisão',
        concluido: 'Concluído',
        pausado: 'Pausado',
        cancelado: 'Cancelado',
    }

    const colors = {
        concluido: 'bg-emerald-100 text-emerald-800 border-emerald-300',
        em_andamento: 'bg-blue-100 text-blue-800 border-blue-300',
        em_revisao: 'bg-amber-100 text-amber-800 border-amber-300',
        aguardar_conteudos: 'bg-orange-100 text-orange-800 border-orange-300',
        pausado: 'bg-gray-100 text-gray-700 border-gray-300',
        cancelado: 'bg-red-100 text-red-700 border-red-300',
        planeamento: 'bg-slate-100 text-slate-700 border-slate-300',
    }

    return {
        label: labels[status] ?? (status || 'Sem estado'),
        color: colors[status] ?? 'bg-slate-100 text-slate-700 border-slate-300',
    }
}
</script>

<template>
    <BaseLayout>
        <template #title>Objetos</template>

        <div class="mb-6">
            <h1 class="text-2xl font-semibold">Objetos</h1>
            <p class="mt-1 text-sm text-gray-500">
                {{ client.name }}<span v-if="client.company"> · {{ client.company }}</span>
            </p>
        </div>

        <div v-if="objects.length" class="space-y-4">
            <details v-for="object in objects" :key="object.id" class="overflow-hidden rounded-lg border bg-white shadow-sm">
                <summary class="cursor-pointer list-none p-5">
                    <div class="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
                        <div>
                            <h2 class="text-xl font-semibold uppercase tracking-wide">{{ object.name }}</h2>
                            <p class="mt-1 text-sm text-gray-500">{{ object.credentials_count ?? object.credentials?.length ?? 0 }} senha(s)</p>
                            <p v-if="object.notes" class="mt-2 text-sm text-gray-600 whitespace-pre-line">{{ object.notes }}</p>
                        </div>

                        <div class="flex flex-col gap-2 text-sm lg:items-end">
                            <div v-if="object.project" class="flex flex-wrap items-center gap-2">
                                <span class="text-gray-500">Projeto:</span>
                                <span class="font-medium text-gray-800">{{ object.project.name }}</span>
                                <span class="rounded-full border px-2 py-1 text-xs" :class="badgeStatus(object.project.status).color">
                                    {{ badgeStatus(object.project.status).label }}
                                </span>
                            </div>
                            <a :href="`/clients/${client.id}/credential-objects/${object.id}/export`" class="text-[#015557] hover:underline">
                                Exportar
                            </a>
                        </div>
                    </div>
                </summary>

                <div class="border-t p-5">
                    <div v-if="object.credentials?.length" class="overflow-x-auto">
                        <table class="min-w-[920px] w-full text-left text-sm">
                            <thead>
                                <tr class="border-b bg-gray-50">
                                    <th class="px-3 py-2">Serviço</th>
                                    <th class="px-3 py-2">Utilizador</th>
                                    <th class="px-3 py-2">Senha</th>
                                    <th class="px-3 py-2">URL</th>
                                    <th class="px-3 py-2">Notas</th>
                                    <th class="px-3 py-2">Criado</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr v-for="credential in object.credentials" :key="credential.id" class="border-b align-top">
                                    <td class="px-3 py-3 font-medium">{{ credential.label }}</td>
                                    <td class="px-3 py-3">{{ credential.username || '—' }}</td>
                                    <td class="px-3 py-3">
                                        <div class="flex flex-wrap items-center gap-2">
                                            <span class="break-all font-mono text-xs">{{ revealedPasswords[credential.id] ? credential.password : '******' }}</span>
                                            <button type="button" class="text-xs text-blue-600 hover:underline" @click="togglePassword(credential.id)">
                                                {{ revealedPasswords[credential.id] ? 'Ocultar' : 'Mostrar' }}
                                            </button>
                                            <button type="button" class="text-xs text-blue-600 hover:underline" @click="copyText(credential.password)">
                                                Copiar
                                            </button>
                                        </div>
                                    </td>
                                    <td class="px-3 py-3">
                                        <a v-if="credential.url" :href="credential.url" target="_blank" class="break-all text-blue-600 hover:underline">
                                            {{ credential.url }}
                                        </a>
                                        <span v-else>—</span>
                                    </td>
                                    <td class="px-3 py-3 whitespace-pre-line">{{ credential.notes || '—' }}</td>
                                    <td class="px-3 py-3">{{ credential.created_at ? new Date(credential.created_at).toLocaleDateString('pt-PT') : '—' }}</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>

                    <p v-else class="text-sm text-gray-500">Sem senhas neste objeto.</p>
                </div>
            </details>
        </div>

        <div v-else class="rounded-lg border border-dashed bg-white p-10 text-center text-gray-500">
            Ainda não existem objetos associados a este cliente.
        </div>
    </BaseLayout>
</template>
