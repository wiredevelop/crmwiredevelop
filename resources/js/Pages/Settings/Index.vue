<script setup>
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { Head, useForm, usePage } from '@inertiajs/vue3'
import Webpass from '@laragear/webpass'
import { computed } from 'vue'

const page = usePage()
const form = useForm({
    sales_goal_year: page.props.salesGoal ?? '',
    terminal_surcharge_percent: page.props.terminalSurchargePercent ?? 0,
    terminal_surcharge_fixed: page.props.terminalSurchargeFixed ?? 0
})

const flash = computed(() => page.props.flash ?? {})

const ideForm = useForm({})

const ideStatus = computed(() => page.props.ideStatus ?? { state: 'unknown' })
const ideLabelMap = {
    active: 'Ativa',
    inactive: 'Inativa',
    failed: 'Falhada',
    activating: 'A ativar',
    deactivating: 'A desativar'
}
const ideLabel = computed(() => ideLabelMap[ideStatus.value.state] ?? 'Desconhecido')
const submitSalesGoal = () => {
    form.post('/settings/sales-goal', {
        preserveScroll: true
    })
}


const toggleIde = () => {
    ideForm.post('/settings/ide-toggle', {
        preserveScroll: true
    })
}

const registerPasskey = async () => {
    try {
        if (Webpass.isUnsupported()) {
            alert('O teu navegador não suporta Passkeys / WebAuthn.')
            return
        }

        const { success, error } = await Webpass.attest(
            '/webauthn/register/options',
            '/webauthn/register'
        )

        if (!success) {
            console.error(error)
            alert('Não foi possível registar a Passkey.')
            return
        }

        alert('Passkey registada com sucesso!')
    } catch (e) {
        console.error(e)
        alert('Erro ao registar a Passkey.')
    }
}
</script>

<template>

    <Head title="Definições" />

    <BaseLayout>
        <template #title>Definições</template>

        <div class="space-y-6">
            <div v-if="flash.success" class="bg-green-100 border border-green-200 text-green-800 px-4 py-2 rounded">
                {{ flash.success }}
            </div>
            <div v-if="flash.error" class="bg-red-100 border border-red-200 text-red-800 px-4 py-2 rounded">
                {{ flash.error }}
            </div>
            <div class="bg-white p-6 rounded shadow">
                <h2 class="text-xl font-semibold mb-2">Definições do Sistema</h2>
                <p class="text-gray-500">Configurações gerais do CRM.</p>
            </div>

            <div class="bg-white p-6 rounded shadow">
                <h2 class="text-xl font-semibold mb-2">Meta de Vendas e Terminal</h2>
                <p class="text-gray-500 mb-4">Define a meta anual e a sobretaxa manual usada para repercutir a taxa Stripe no cliente.</p>

                <form @submit.prevent="submitSalesGoal" class="flex flex-col gap-4">
                    <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
                        <div class="w-full">
                        <label class="block text-sm font-medium text-gray-700 mb-1">Meta anual (€)</label>
                        <input
                            v-model="form.sales_goal_year"
                            type="number"
                            min="0"
                            step="0.01"
                            placeholder="60000"
                            class="w-full border rounded px-3 py-2 text-sm"
                        />
                    </div>
                        <div class="w-full">
                            <label class="block text-sm font-medium text-gray-700 mb-1">Sobretaxa terminal (%)</label>
                            <input
                                v-model="form.terminal_surcharge_percent"
                                type="number"
                                min="0"
                                step="0.01"
                                placeholder="1.50"
                                class="w-full border rounded px-3 py-2 text-sm"
                            />
                        </div>
                        <div class="w-full">
                            <label class="block text-sm font-medium text-gray-700 mb-1">Sobretaxa terminal fixa (€)</label>
                            <input
                                v-model="form.terminal_surcharge_fixed"
                                type="number"
                                min="0"
                                step="0.01"
                                placeholder="0.25"
                                class="w-full border rounded px-3 py-2 text-sm"
                            />
                        </div>
                    </div>

                    <button
                        type="submit"
                        class="bg-[#015557] text-white px-4 py-2 rounded hover:bg-[#014548] disabled:opacity-50"
                        :disabled="form.processing"
                    >
                        Guardar definições
                    </button>
                </form>
            </div>


            <div class="bg-white p-6 rounded shadow">
                <h2 class="text-xl font-semibold mb-2">IDE</h2>
                <p class="text-gray-500 mb-4">Estado: {{ ideLabel }}</p>

                <button
                    @click="toggleIde"
                    class="bg-[#015557] text-white px-4 py-2 rounded hover:bg-[#014548] disabled:opacity-50"
                    :disabled="ideForm.processing"
                >
                    Ativar / Desativar IDE
                </button>
            </div>

            <div class="bg-white p-6 rounded shadow mt-6">
                <h2 class="text-xl font-semibold mb-4">Segurança</h2>
                <p class="text-gray-500 mb-4">
                    Ative login com Impressão Digital / FaceID.
                </p>

                <button @click="registerPasskey" class="bg-black text-white px-4 py-2 rounded hover:bg-gray-800">
                    Registar Passkey (Impressão Digital / FaceID)
                </button>
            </div>
        </div>
    </BaseLayout>
</template>
