<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { Link, router, usePage } from '@inertiajs/vue3'
import { ref, watch } from 'vue'

const props = usePage().props
const clients = props.clients.data
const pagination = props.clients

// Filtros
const search = ref(props.filters?.search || '')
const filterCompany = ref(props.filters?.company || '')
const filterEmail = ref(props.filters?.email || '')
const filterVat = ref(props.filters?.vat || '')

let debounceTimeout = null

watch([search, filterCompany, filterEmail, filterVat], () => {
    clearTimeout(debounceTimeout)

    debounceTimeout = setTimeout(() => {
        router.get(
            '/clients',
            {
                search: search.value,
                company: filterCompany.value,
                email: filterEmail.value,
                vat: filterVat.value,
            },
            {
                preserveState: false,
                replace: true,
            }
        )
    }, 300)
})

function typeBadge(client) {
    return client.company
        ? { label: 'Empresa', color: 'bg-blue-100 text-blue-700 border-blue-300' }
        : { label: 'Particular', color: 'bg-green-100 text-green-700 border-green-300' }
}
</script>

<template>
    <BaseLayout>
        <template #title>Clientes</template>

        <!-- Header -->
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-6">
            <h1 class="text-2xl font-semibold">Clientes</h1>

            <Link href="/clients/create"
                class="bg-[#015557] text-white px-4 py-2 rounded hover:bg-[#014147]">
                + Novo Cliente
            </Link>
        </div>

        <!-- Filtros -->
        <div class="bg-white rounded shadow p-4 mb-4 space-y-4">
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <input v-model="search" placeholder="Pesquisar nome..." class="input" />
                <input v-model="filterCompany" placeholder="Empresa" class="input" />
                <input v-model="filterEmail" placeholder="Email" class="input" />
                <input v-model="filterVat" placeholder="NIF" class="input" />
            </div>
        </div>

        <!-- Tabela -->
        <div class="bg-white rounded shadow overflow-x-auto">
            <table class="min-w-[900px] w-full text-left border-collapse">
                <thead>
                    <tr class="bg-gray-50 border-b">
                        <th class="py-2 px-3">Nome</th>
                        <th class="py-2 px-3">Tipo</th>
                        <th class="py-2 px-3">Empresa</th>
                        <th class="py-2 px-3">Email</th>
                        <th class="py-2 px-3">NIF</th>
                        <th class="py-2 px-3">Telefone</th>
                        <th class="py-2 px-3 w-24"></th>
                    </tr>
                </thead>

                <tbody v-if="clients.length">
                    <tr v-for="c in clients" :key="c.id" class="border-b hover:bg-gray-50">
                        <td class="py-2 px-3 font-medium">
                            <Link :href="`/clients/${c.id}`" class="text-[#015557] hover:underline">
                                {{ c.name }}
                            </Link>
                        </td>
                        <td class="py-2 px-3">
                            <span class="px-2 py-1 text-xs rounded border"
                                :class="typeBadge(c).color">
                                {{ typeBadge(c).label }}
                            </span>
                        </td>
                        <td class="py-2 px-3">{{ c.company || '—' }}</td>
                        <td class="py-2 px-3">{{ c.email || '—' }}</td>
                        <td class="py-2 px-3">{{ c.vat || '—' }}</td>
                        <td class="py-2 px-3">{{ c.phone || '—' }}</td>

                        <td class="py-2 px-3 text-right space-x-2">
                            <Link :href="`/clients/${c.id}/edit`" class="text-blue-600 hover:underline">Editar</Link>
                            <Link as="button" method="delete" :href="`/clients/${c.id}`" class="text-red-600 hover:underline">
                                Apagar
                            </Link>
                        </td>
                    </tr>
                </tbody>

                <tbody v-else>
                    <tr>
                        <td colspan="7" class="py-6 text-center text-gray-500">
                            Nenhum cliente encontrado com esses filtros.
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>

        <!-- Paginação -->
        <div class="mt-4 flex flex-wrap justify-center gap-2">
            <Link
                v-for="link in pagination.links"
                :key="link.label"
                :href="link.url || ''"
                v-html="link.label"
                :class="[
                    'px-3 py-1 rounded border',
                    link.active ? 'bg-[#015557] text-white border-[#015557]' : 'bg-white hover:bg-gray-100'
                ]"
            />
        </div>
    </BaseLayout>
</template>

<style scoped>
.input {
    @apply w-full border rounded px-3 py-2;
}
</style>
