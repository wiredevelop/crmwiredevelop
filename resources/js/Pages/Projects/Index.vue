<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { Link, usePage } from '@inertiajs/vue3'

const { projects, statusFilters, currentStatus, totalCount } = usePage().props
const list = projects.data
</script>

<template>
    <BaseLayout>
        <template #title>Projetos</template>

        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-6">
            <h1 class="text-2xl font-semibold">Projetos</h1>

            <Link href="/projects/create" class="bg-[#015557] text-white px-4 py-2 rounded">
            + Novo Projeto
            </Link>
        </div>

        <div class="flex flex-wrap gap-3 text-sm mb-4">
            <Link
                href="/projects"
                :class="!currentStatus ? 'font-semibold text-[#015557]' : 'text-gray-500 hover:text-gray-700'"
            >
                Todos ({{ totalCount }})
            </Link>
            <Link
                v-for="filter in statusFilters"
                :key="filter.value"
                :href="`/projects?status=${filter.value}`"
                :class="currentStatus === filter.value
                    ? 'font-semibold text-[#015557]'
                    : 'text-gray-500 hover:text-gray-700'"
            >
                {{ filter.label }} ({{ filter.count }})
            </Link>
        </div>

        <div class="bg-white rounded shadow overflow-x-auto">
            <table class="min-w-[900px] w-full text-left text-sm">
                <thead>
                    <tr class="bg-gray-50 border-b">
                        <th class="py-2 px-3">Projeto</th>
                        <th class="py-2 px-3">Cliente</th>
                        <th class="py-2 px-3">Tipo</th>
                        <th class="py-2 px-3">Estado</th>
                        <th class="py-2 px-3">Preço</th>
                        <th class="py-2 px-3">Criado</th>
                        <th class="py-2 px-3 w-36"></th>
                    </tr>
                </thead>

                <tbody v-if="list.length">
                    <tr v-for="p in list" :key="p.id" class="border-b hover:bg-gray-50">

                        <td class="py-2 px-3">{{ p.name }}</td>
                        <td class="py-2 px-3">{{ p.client?.name }}</td>

                        <td class="py-2 px-3">{{ p.type }}</td>
                        <td class="py-2 px-3">{{ p.status }}</td>

                        <td class="py-2 px-3">
                            {{ p.quote?.price_development ?? 0 }} €
                        </td>


                        <td class="py-2 px-3">
                            {{ new Date(p.created_at).toLocaleDateString('pt-PT') }}
                        </td>

                        <td class="py-2 px-3 text-right">
                            <div class="inline-flex items-center gap-2">
                                <div v-if="p.quote?.id" class="relative group inline-flex">
                                    <button
                                        type="button"
                                        class="text-xs text-blue-600 hover:underline"
                                    >
                                        Exportar
                                    </button>
                                    <div
                                        class="absolute right-0 top-full z-10 hidden min-w-[120px] rounded border border-gray-200 bg-white shadow group-hover:block"
                                    >
                                        <a
                                            :href="route('quotes.pdf', p.quote.id)"
                                            target="_blank"
                                            class="block px-3 py-2 text-xs text-gray-700 hover:bg-gray-50"
                                        >
                                            PDF
                                        </a>
                                        <a
                                            :href="route('quotes.docx', p.quote.id)"
                                            class="block px-3 py-2 text-xs text-gray-700 hover:bg-gray-50"
                                        >
                                            DOCX
                                        </a>
                                        <a
                                            :href="route('quotes.docx.partner', p.quote.id)"
                                            class="block px-3 py-2 text-xs text-gray-700 hover:bg-gray-50"
                                        >
                                            DOCX Parceiro
                                        </a>
                                    </div>
                                </div>
                                <Link :href="`/projects/${p.id}/edit`" class="text-blue-600 hover:underline text-xs">
                                Editar
                                </Link>
                            </div>
                        </td>

                    </tr>
                </tbody>

                <tbody v-else>
                    <tr>
                        <td colspan="7" class="py-4 text-center text-gray-500">
                            Nenhum projeto encontrado.
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>
    </BaseLayout>
</template>
