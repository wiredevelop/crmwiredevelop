<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { Link, usePage, router } from '@inertiajs/vue3'
import { ref } from 'vue'

// PROPS
const { invoices, sort, direction } = usePage().props

const list = invoices.data
const sortColumn = ref(sort || 'issued_at')
const sortDirection = ref(direction || 'desc')
const isClientUser = usePage().props.auth?.user?.role === 'client'

// Função universal de ordenação
function orderBy(column) {
    // alterna asc/desc automaticamente
    if (sortColumn.value === column) {
        sortDirection.value = sortDirection.value === 'asc' ? 'desc' : 'asc'
    } else {
        sortColumn.value = column
        sortDirection.value = 'asc'
    }

    router.get(route('invoices.index'), {
        sort: sortColumn.value,
        direction: sortDirection.value
    }, { preserveScroll: true })
}

// Atualizar status PAGO/PENDENTE
function markPaid(id) {
    router.post(route('invoices.paid', id), {}, {
        onFinish: () => router.reload({ only: ['invoices'] })
    })
}

function markPending(id) {
    router.post(route('invoices.pending', id), {}, {
        onFinish: () => router.reload({ only: ['invoices'] })
    })
}

function uninvoice(id) {
    if (!confirm('Queres desfaturar esta fatura?')) {
        return
    }

    router.post(route('invoices.uninvoice', id), {}, {
        onFinish: () => router.reload({ only: ['invoices'] })
    })
}

// Ícone ASC/DESC
function icon(column) {
    if (sortColumn.value !== column) return ''
    return sortDirection.value === 'asc' ? '▲' : '▼'
}
</script>

<template>
    <BaseLayout>
        <template #title>Documentos</template>

        <div class="bg-white rounded shadow overflow-x-auto">

            <table class="min-w-[980px] w-full text-left text-sm">
                <thead>
                    <tr class="bg-gray-50 border-b">

                        <th class="py-2 px-3 cursor-pointer" @click="orderBy('number')">
                            Número {{ icon('number') }}
                        </th>

                        <th class="py-2 px-3 cursor-pointer" @click="orderBy('client')">
                            Cliente {{ icon('client') }}
                        </th>

                        <th class="py-2 px-3 cursor-pointer" @click="orderBy('project')">
                            Projeto {{ icon('project') }}
                        </th>

                        <th class="py-2 px-3 cursor-pointer" @click="orderBy('total')">
                            Total {{ icon('total') }}
                        </th>

                        <th class="py-2 px-3 cursor-pointer" @click="orderBy('status')">
                            Estado {{ icon('status') }}
                        </th>

                        <th class="py-2 px-3 cursor-pointer" @click="orderBy('issued_at')">
                            Emitida {{ icon('issued_at') }}
                        </th>

                        <th class="py-2 px-3 cursor-pointer" @click="orderBy('due_at')">
                            Vencimento {{ icon('due_at') }}
                        </th>

                        <th class="py-2 px-3 cursor-pointer" @click="orderBy('paid_at')">
                            Pago em {{ icon('paid_at') }}
                        </th>

                        <th class="py-2 px-3 w-32 text-right">Ações</th>
                    </tr>
                </thead>

                <tbody>
                    <tr v-for="inv in list" :key="inv.id" class="border-b hover:bg-gray-50">

                        <td class="py-2 px-3">{{ inv.number }}</td>
                        <td class="py-2 px-3">{{ inv.client?.name }}</td>
                        <td class="py-2 px-3">{{ inv.project?.name }}</td>

                        <td class="py-2 px-3">{{ inv.total }} €</td>

                        <td class="py-2 px-3">
                            <span :class="inv.status === 'pago' ? 'text-green-600' : 'text-red-600'">
                                {{ inv.status }}
                            </span>
                        </td>

                        <td class="py-2 px-3">
                            {{ inv.issued_at ? new Date(inv.issued_at).toLocaleDateString('pt-PT') : '-' }}
                        </td>

                        <td class="py-2 px-3">
                            {{ inv.due_at ? new Date(inv.due_at).toLocaleDateString('pt-PT') : '-' }}
                        </td>

                        <td class="py-2 px-3">
                            {{ inv.paid_at ? new Date(inv.paid_at).toLocaleDateString('pt-PT') : '-' }}
                        </td>

                        <td class="py-2 px-3 text-right flex gap-2">

                            <a :href="route('invoices.pdf', inv.id)" class="text-blue-600 text-xs" target="_blank">
                                PDF
                            </a>

                            <Link v-if="!isClientUser" :href="route('invoices.edit', inv.id)" class="text-blue-600 text-xs">
                                Editar
                            </Link>

                            <button v-if="!isClientUser && inv.status !== 'pago'" @click="markPaid(inv.id)"
                                class="text-green-600 text-xs">
                                Pago
                            </button>

                            <button v-else-if="!isClientUser" @click="markPending(inv.id)" class="text-red-600 text-xs">
                                Pendente
                            </button>

                            <button v-if="!isClientUser && inv.status !== 'pago'" @click="uninvoice(inv.id)"
                                class="text-red-600 text-xs">
                                Desfaturar
                            </button>

                        </td>
                    </tr>
                </tbody>
            </table>

        </div>
    </BaseLayout>
</template>

<style scoped>
.cursor-pointer {
    cursor: pointer;
}
</style>
