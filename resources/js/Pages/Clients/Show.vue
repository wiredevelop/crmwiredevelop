<script setup>
import InputError from '@/Components/InputError.vue'
import Modal from '@/Components/Modal.vue'
import PrimaryButton from '@/Components/PrimaryButton.vue'
import SecondaryButton from '@/Components/SecondaryButton.vue'
import BaseLayout from '@/Layouts/BaseLayout.vue'
import { Link, useForm, usePage } from '@inertiajs/vue3'
import { computed, ref, watch } from 'vue'

const page = usePage()
const props = page.props
const client = props.client
const projects = props.projects ?? []
const invoices = props.invoices ?? []
const notes = ref(props.notes ?? [])
const credentialObjects = computed(() => props.credentialObjects ?? [])
const transferTargets = computed(() => props.transferTargets ?? [])
const authUser = props.auth?.user ?? {}
const flash = props.flash ?? {}
const isClientUser = authUser.role === 'client'
const portalUser = computed(() => client.user ?? null)
const selectedObject = ref(null)
const showTransferModal = ref(false)
const showPromoteModal = ref(false)

const noteForm = useForm({
    note: '',
})

const portalForm = useForm({
    portal_email: portalUser.value?.email ?? client.email ?? '',
    portal_password: '',
})

const objectForm = useForm({
    name: '',
    notes: '',
})

const credentialForm = useForm({
    object_id: '',
    label: '',
    username: '',
    password: '',
    url: '',
    notes: '',
})

const transferForm = useForm({
    target_client_id: '',
})

const promoteForm = useForm({
    name: '',
    company: '',
    email: '',
    phone: '',
    vat: '',
    address: '',
    hourly_rate: '',
    notes: '',
    portal_email: '',
    portal_password: '',
})

const revealedPasswords = ref({})
const selectedObjectProjectText = computed(() => {
    const project = selectedObject.value?.project

    if (!project) {
        return 'Este objeto não tem projeto associado.'
    }

    return `O projeto "${project.name}" também será movido para o cliente de destino.`
})

watch(() => promoteForm.email, (value) => {
    if (!promoteForm.portal_email) {
        promoteForm.portal_email = value
    }
})

function addNote() {
    if (!noteForm.note.trim()) return

    noteForm.post(`/clients/${client.id}/notes`, {
        preserveScroll: true,
        onSuccess: () => {
            notes.value = [...notes.value, {
                text: noteForm.note,
                created_at: new Date().toISOString(),
            }]
            noteForm.reset()
        },
    })
}

function addObject() {
    if (!objectForm.name.trim()) return

    objectForm.post(`/clients/${client.id}/credential-objects`, {
        preserveScroll: true,
        onSuccess: () => {
            objectForm.reset()
        },
    })
}

function addCredential() {
    if (!credentialForm.object_id || !credentialForm.label.trim() || !credentialForm.password.trim()) return

    credentialForm.post(`/clients/${client.id}/credentials`, {
        preserveScroll: true,
        onSuccess: () => {
            credentialForm.reset()
        },
    })
}

function generateTemporaryPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
    let password = ''

    for (let i = 0; i < 12; i += 1) {
        password += chars[Math.floor(Math.random() * chars.length)]
    }

    portalForm.portal_password = password
}

function generatePromotionTemporaryPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
    let password = ''

    for (let i = 0; i < 12; i += 1) {
        password += chars[Math.floor(Math.random() * chars.length)]
    }

    promoteForm.portal_password = password
}

function createPortalUser() {
    portalForm.post(`/clients/${client.id}/portal-user`, {
        preserveScroll: true,
    })
}

function regenerateTemporaryPassword(deliveryMode) {
    if (deliveryMode === 'email' && !(portalUser.value?.email || portalForm.portal_email || client.email)) {
        alert('Este cliente não tem email disponível para envio.')
        return
    }

    useForm({
        delivery_mode: deliveryMode,
    }).post(`/clients/${client.id}/temporary-password`, {
        preserveScroll: true,
    })
}

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

function openTransferModal(object) {
    selectedObject.value = object
    transferForm.reset()
    transferForm.clearErrors()
    showTransferModal.value = true
}

function closeTransferModal() {
    showTransferModal.value = false
    selectedObject.value = null
    transferForm.reset()
    transferForm.clearErrors()
}

function submitTransferObject() {
    if (!selectedObject.value) return

    transferForm.post(`/clients/${client.id}/credential-objects/${selectedObject.value.id}/transfer`, {
        preserveScroll: true,
        onSuccess: () => {
            closeTransferModal()
        },
    })
}

function openPromoteModal(object) {
    selectedObject.value = object
    promoteForm.reset()
    promoteForm.clearErrors()
    promoteForm.name = object.name ?? ''
    promoteForm.notes = object.notes ?? ''
    showPromoteModal.value = true
}

function closePromoteModal() {
    showPromoteModal.value = false
    selectedObject.value = null
    promoteForm.reset()
    promoteForm.clearErrors()
}

function submitPromoteObject() {
    if (!selectedObject.value) return

    promoteForm.post(`/clients/${client.id}/credential-objects/${selectedObject.value.id}/promote`, {
        preserveScroll: true,
        onSuccess: () => {
            closePromoteModal()
        },
    })
}

function badgeStatus(status) {
    if (status === 'concluido') {
        return 'bg-green-100 text-green-700 border-green-300'
    }
    if (status === 'pendente') {
        return 'bg-yellow-100 text-yellow-700 border-yellow-300'
    }
    return 'bg-gray-100 text-gray-700 border-gray-300'
}
</script>

<template>
    <BaseLayout>
        <template #title>{{ client.name }}</template>

        <div class="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between mb-6">
            <div>
                <h1 class="text-2xl font-semibold">{{ client.name }}</h1>
                <p class="text-sm text-gray-500" v-if="client.company || client.email">
                    {{ client.company || 'Cliente' }}<span v-if="client.email"> · {{ client.email }}</span>
                </p>
            </div>

            <div v-if="!isClientUser" class="flex flex-wrap gap-2">
                <Link :href="`/clients/${client.id}/edit`" class="px-3 py-1 bg-blue-600 text-white rounded">Editar</Link>
                <Link as="button" method="post" :href="`/clients/${client.id}/duplicate`" class="px-3 py-1 bg-yellow-500 text-white rounded">Duplicar</Link>
                <Link :href="`/projects/create?client=${client.id}`" class="px-3 py-1 bg-green-600 text-white rounded">Novo Projeto</Link>
                <Link as="button" method="delete" :href="`/clients/${client.id}`" class="px-3 py-1 bg-red-600 text-white rounded">Apagar</Link>
            </div>
        </div>

        <div v-if="flash.temporaryPassword" class="mb-6 rounded-lg border border-emerald-200 bg-emerald-50 p-4">
            <p class="font-medium text-emerald-900">Senha temporária de {{ flash.temporaryPasswordClient || client.name }}</p>
            <p class="mt-1 text-sm text-emerald-800">Login: {{ flash.temporaryPasswordEmail || portalUser?.email || '—' }}</p>
            <div class="mt-3 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <code class="rounded bg-white px-3 py-2 text-sm text-gray-900">{{ flash.temporaryPassword }}</code>
                <button type="button" class="rounded border border-emerald-300 bg-white px-3 py-2 text-sm text-emerald-800" @click="copyText(flash.temporaryPassword)">
                    Copiar senha
                </button>
            </div>
        </div>

        <div class="grid grid-cols-1 xl:grid-cols-3 gap-6 mb-8">
            <div class="bg-white shadow rounded p-6 xl:col-span-2">
                <h2 class="text-xl font-semibold mb-4">Dados do Cliente</h2>

                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
                    <div><strong>Nome:</strong> {{ client.name }}</div>
                    <div><strong>Empresa:</strong> {{ client.company || '—' }}</div>
                    <div><strong>Email:</strong> {{ client.email || '—' }}</div>
                    <div><strong>Telefone:</strong> {{ client.phone || '—' }}</div>
                    <div><strong>NIF:</strong> {{ client.vat || '—' }}</div>
                    <div><strong>Morada:</strong> {{ client.address || '—' }}</div>
                    <div class="sm:col-span-2">
                        <strong>Notas:</strong>
                        <p class="text-gray-600 whitespace-pre-line mt-1">{{ client.notes || '—' }}</p>
                    </div>
                </div>
            </div>

            <div class="bg-white shadow rounded p-6">
                <h2 class="text-xl font-semibold mb-4">Acesso Portal</h2>

                <div v-if="portalUser" class="space-y-3 text-sm">
                    <div><strong>Email de acesso:</strong> {{ portalUser.email }}</div>
                    <div><strong>Estado:</strong> {{ portalUser.must_change_password ? 'A aguardar troca de senha' : 'Ativo' }}</div>
                    <div v-if="!isClientUser" class="flex flex-wrap gap-2 pt-2">
                        <button type="button" class="rounded bg-[#015557] px-3 py-2 text-white" @click="regenerateTemporaryPassword('copy')">
                            Gerar e copiar senha
                        </button>
                        <button type="button" class="rounded border border-[#015557] px-3 py-2 text-[#015557]" @click="regenerateTemporaryPassword('email')">
                            Gerar e enviar email
                        </button>
                    </div>
                </div>

                <form v-else-if="!isClientUser" @submit.prevent="createPortalUser" class="space-y-4">
                    <div>
                        <label>Email de acesso *</label>
                        <input v-model="portalForm.portal_email" type="email" class="input" required />
                    </div>

                    <div>
                        <label>Senha temporária</label>
                        <div class="flex gap-2">
                            <input v-model="portalForm.portal_password" class="input" placeholder="Vazio = gerar automática" />
                            <button type="button" class="rounded border bg-gray-100 px-3 py-2" @click="generateTemporaryPassword">
                                Gerar
                            </button>
                        </div>
                    </div>

                    <button type="submit" class="rounded bg-[#015557] px-4 py-2 text-white">Criar acesso</button>
                </form>

                <p v-else class="text-sm text-gray-500">Esta conta está associada ao cliente autenticado.</p>
            </div>
        </div>

        <div v-if="!isClientUser" class="grid grid-cols-1 xl:grid-cols-3 gap-6 mb-8">
            <div class="bg-white shadow rounded p-6">
                <h2 class="text-xl font-semibold mb-4">Notas Internas</h2>

                <div class="flex flex-col gap-2 sm:flex-row mb-4">
                    <input v-model="noteForm.note" placeholder="Adicionar nota..." class="w-full border rounded px-3 py-2" />
                    <button @click="addNote" class="bg-[#015557] text-white px-4 py-2 rounded">Guardar</button>
                </div>

                <div v-if="notes.length" class="space-y-3 max-h-64 overflow-y-auto">
                    <div v-for="(n, index) in notes" :key="index" class="border rounded p-3 bg-gray-50">
                        <p class="text-sm whitespace-pre-line">{{ n.text }}</p>
                        <p class="text-xs text-gray-500 mt-1">{{ n.created_at }}</p>
                    </div>
                </div>

                <p v-else class="text-gray-500 text-sm">Sem notas internas.</p>
            </div>

            <div class="bg-white shadow rounded p-6 xl:col-span-2">
                <div class="flex flex-col gap-2 lg:flex-row lg:items-center lg:justify-between mb-4">
                    <h2 class="text-xl font-semibold">Acessos e Senhas</h2>
                    <p class="text-sm text-gray-500">Cria um objeto antes de adicionar senhas.</p>
                </div>

                <form @submit.prevent="addObject" class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
                    <div>
                        <label>Nome do objeto *</label>
                        <input v-model="objectForm.name" class="input" required />
                    </div>
                    <div>
                        <label>Notas</label>
                        <input v-model="objectForm.notes" class="input" />
                    </div>
                    <div class="md:col-span-2 flex justify-end">
                        <button type="submit" class="bg-[#015557] text-white px-4 py-2 rounded">Criar Objeto</button>
                    </div>
                </form>

                <form @submit.prevent="addCredential" class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
                    <div>
                        <label>Objeto *</label>
                        <select v-model="credentialForm.object_id" class="input" required :disabled="!credentialObjects.length">
                            <option value="">Selecionar objeto</option>
                            <option v-for="object in credentialObjects" :key="object.id" :value="object.id">{{ object.name }}</option>
                        </select>
                    </div>
                    <div>
                        <label>Serviço *</label>
                        <input v-model="credentialForm.label" class="input" required :disabled="!credentialObjects.length" />
                    </div>
                    <div>
                        <label>Utilizador</label>
                        <input v-model="credentialForm.username" class="input" :disabled="!credentialObjects.length" />
                    </div>
                    <div>
                        <label>Senha *</label>
                        <input v-model="credentialForm.password" type="password" class="input" required :disabled="!credentialObjects.length" />
                    </div>
                    <div>
                        <label>URL</label>
                        <input v-model="credentialForm.url" type="url" class="input" placeholder="https://..." :disabled="!credentialObjects.length" />
                    </div>
                    <div class="md:col-span-2">
                        <label>Notas</label>
                        <textarea v-model="credentialForm.notes" rows="3" class="input" :disabled="!credentialObjects.length"></textarea>
                    </div>
                    <div class="md:col-span-2 flex justify-end">
                        <button type="submit" class="bg-[#015557] text-white px-4 py-2 rounded" :disabled="!credentialObjects.length">Guardar Senha</button>
                    </div>
                </form>

                <div v-if="credentialObjects.length" class="space-y-4">
                    <details v-for="object in credentialObjects" :key="object.id" class="border rounded">
                        <summary class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between p-4 cursor-pointer">
                            <div>
                                <p class="font-medium">{{ object.name }}</p>
                                <p v-if="object.notes" class="text-xs text-gray-500">{{ object.notes }}</p>
                                <p v-if="object.project" class="text-xs text-[#015557]">Projeto ligado: {{ object.project.name }}</p>
                                <p class="text-xs text-gray-400">{{ object.credentials?.length || 0 }} senha(s)</p>
                            </div>
                            <div class="flex items-center gap-3 text-xs">
                                <a :href="`/clients/${client.id}/credential-objects/${object.id}/export`" class="text-[#015557] hover:underline" @click.stop>Exportar</a>
                                <button type="button" class="text-amber-700 hover:underline" @click.stop="openTransferModal(object)">Transferir</button>
                                <button type="button" class="text-blue-700 hover:underline" @click.stop="openPromoteModal(object)">Promover</button>
                                <Link as="button" method="delete" :href="`/clients/${client.id}/credential-objects/${object.id}`" class="text-red-600 hover:underline" @click.stop>Apagar objeto</Link>
                            </div>
                        </summary>

                        <div class="border-t p-4">
                            <div v-if="object.credentials && object.credentials.length" class="overflow-x-auto">
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
                                        <tr v-for="cred in object.credentials" :key="cred.id" class="border-b hover:bg-gray-50">
                                            <td class="py-2 px-2 font-medium">{{ cred.label }}</td>
                                            <td class="py-2 px-2">{{ cred.username || '—' }}</td>
                                            <td class="py-2 px-2">
                                                <div class="flex items-center gap-2">
                                                    <span class="font-mono text-xs break-all">{{ revealedPasswords[cred.id] ? cred.password : '******' }}</span>
                                                    <button type="button" class="text-xs text-blue-600 hover:underline" @click="togglePassword(cred.id)">
                                                        {{ revealedPasswords[cred.id] ? 'Ocultar' : 'Mostrar' }}
                                                    </button>
                                                    <button type="button" class="text-xs text-blue-600 hover:underline" @click="copyText(cred.password)">
                                                        Copiar
                                                    </button>
                                                </div>
                                            </td>
                                            <td class="py-2 px-2">
                                                <a v-if="cred.url" :href="cred.url" target="_blank" class="text-blue-600 hover:underline break-all">{{ cred.url }}</a>
                                                <span v-else>—</span>
                                            </td>
                                            <td class="py-2 px-2"><span class="whitespace-pre-line">{{ cred.notes || '—' }}</span></td>
                                            <td class="py-2 px-2">{{ cred.created_at ? new Date(cred.created_at).toLocaleDateString('pt-PT') : '—' }}</td>
                                            <td class="py-2 px-2 text-right">
                                                <Link as="button" method="delete" :href="`/clients/${client.id}/credentials/${cred.id}`" class="text-red-600 hover:underline text-xs">Apagar</Link>
                                            </td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>

                            <p v-else class="text-gray-500 text-sm">Sem senhas neste objeto.</p>
                        </div>
                    </details>
                </div>

                <p v-else class="text-gray-500 text-sm">Sem objetos criados.</p>
            </div>
        </div>

        <div class="bg-white shadow rounded p-6 mb-6">
            <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between mb-4">
                <h2 class="text-xl font-semibold">Projetos</h2>
                <Link href="/projects" class="text-sm text-[#015557] hover:underline">Ver todos</Link>
            </div>

            <div v-if="projects.length" class="overflow-x-auto">
                <table class="min-w-[720px] w-full text-left text-sm">
                    <thead>
                        <tr class="bg-gray-50 border-b">
                            <th class="py-2 px-2">Nome</th>
                            <th class="py-2 px-2">Estado</th>
                            <th class="py-2 px-2">Criado em</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr v-for="p in projects" :key="p.id" class="border-b hover:bg-gray-50">
                            <td class="py-2 px-2">{{ p.name }}</td>
                            <td class="py-2 px-2">
                                <span class="px-2 py-1 text-xs rounded border" :class="badgeStatus(p.status)">{{ p.status }}</span>
                            </td>
                            <td class="py-2 px-2">{{ p.created_at }}</td>
                        </tr>
                    </tbody>
                </table>
            </div>

            <p v-else class="text-gray-500 text-sm">Sem projetos registados.</p>
        </div>

        <div class="bg-white shadow rounded p-6 mb-6">
            <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between mb-4">
                <h2 class="text-xl font-semibold">Documentos</h2>
                <Link href="/invoices" class="text-sm text-[#015557] hover:underline">Ver todas</Link>
            </div>

            <div v-if="invoices.length" class="overflow-x-auto">
                <table class="min-w-[640px] w-full text-left text-sm">
                    <thead>
                        <tr class="bg-gray-50 border-b">
                            <th class="py-2 px-2">#</th>
                            <th class="py-2 px-2">Data</th>
                            <th class="py-2 px-2">Valor</th>
                            <th class="py-2 px-2">Estado</th>
                            <th class="py-2 px-2 w-20"></th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr v-for="i in invoices" :key="i.id" class="border-b hover:bg-gray-50">
                            <td class="py-2 px-2">{{ i.number }}</td>
                            <td class="py-2 px-2">{{ i.issued_at }}</td>
                            <td class="py-2 px-2">{{ i.total }} €</td>
                            <td class="py-2 px-2">
                                <span class="px-2 py-1 text-xs rounded border" :class="i.status === 'pago' ? 'bg-green-100 text-green-700 border-green-300' : 'bg-red-100 text-red-700 border-red-300'">
                                    {{ i.status }}
                                </span>
                            </td>
                            <td class="py-2 px-2 text-right">
                                <Link :href="`/invoices/${i.id}/pdf`" class="text-blue-600 hover:underline text-xs" target="_blank">PDF</Link>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>

            <p v-else class="text-gray-500 text-sm">Sem documentos registados.</p>
        </div>

        <Modal :show="showTransferModal" max-width="lg" @close="closeTransferModal">
            <div class="p-6">
                <h3 class="text-lg font-semibold text-gray-900">Transferir objeto</h3>
                <p class="mt-2 text-sm text-gray-600">
                    {{ selectedObject ? `Vai transferir "${selectedObject.name}" para outro cliente.` : '' }}
                </p>
                <p class="mt-1 text-sm text-[#015557]">{{ selectedObjectProjectText }}</p>

                <div class="mt-4">
                    <label>Cliente de destino *</label>
                    <select v-model="transferForm.target_client_id" class="input mt-1" required>
                        <option value="">Selecionar cliente</option>
                        <option v-for="target in transferTargets" :key="target.id" :value="target.id">
                            {{ target.name }}{{ target.company ? ` · ${target.company}` : '' }}
                        </option>
                    </select>
                    <InputError class="mt-2" :message="transferForm.errors.target_client_id" />
                </div>

                <div class="mt-6 flex justify-end gap-3">
                    <SecondaryButton @click="closeTransferModal">Cancelar</SecondaryButton>
                    <PrimaryButton :disabled="transferForm.processing" @click="submitTransferObject">
                        Transferir
                    </PrimaryButton>
                </div>
            </div>
        </Modal>

        <Modal :show="showPromoteModal" max-width="2xl" @close="closePromoteModal">
            <div class="p-6">
                <h3 class="text-lg font-semibold text-gray-900">Promover objeto a cliente</h3>
                <p class="mt-2 text-sm text-gray-600">
                    {{ selectedObject ? `Vai criar um novo cliente a partir de "${selectedObject.name}".` : '' }}
                </p>
                <p class="mt-1 text-sm text-[#015557]">{{ selectedObjectProjectText }}</p>

                <form class="mt-4 space-y-4" @submit.prevent="submitPromoteObject">
                    <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
                        <div>
                            <label>Nome *</label>
                            <input v-model="promoteForm.name" class="input mt-1" required />
                            <InputError class="mt-2" :message="promoteForm.errors.name" />
                        </div>

                        <div>
                            <label>Empresa</label>
                            <input v-model="promoteForm.company" class="input mt-1" />
                            <InputError class="mt-2" :message="promoteForm.errors.company" />
                        </div>

                        <div>
                            <label>Email</label>
                            <input v-model="promoteForm.email" type="email" class="input mt-1" />
                            <InputError class="mt-2" :message="promoteForm.errors.email" />
                        </div>

                        <div>
                            <label>Telefone</label>
                            <input v-model="promoteForm.phone" class="input mt-1" />
                            <InputError class="mt-2" :message="promoteForm.errors.phone" />
                        </div>

                        <div>
                            <label>NIF / VAT</label>
                            <input v-model="promoteForm.vat" class="input mt-1" />
                            <InputError class="mt-2" :message="promoteForm.errors.vat" />
                        </div>

                        <div>
                            <label>Morada</label>
                            <input v-model="promoteForm.address" class="input mt-1" />
                            <InputError class="mt-2" :message="promoteForm.errors.address" />
                        </div>

                        <div>
                            <label>Valor/hora</label>
                            <input v-model="promoteForm.hourly_rate" type="number" min="0" step="0.01" class="input mt-1" />
                            <InputError class="mt-2" :message="promoteForm.errors.hourly_rate" />
                        </div>

                        <div>
                            <label>Email de acesso *</label>
                            <input v-model="promoteForm.portal_email" type="email" class="input mt-1" required />
                            <InputError class="mt-2" :message="promoteForm.errors.portal_email" />
                        </div>
                    </div>

                    <div>
                        <label>Notas</label>
                        <textarea v-model="promoteForm.notes" rows="3" class="input mt-1"></textarea>
                        <InputError class="mt-2" :message="promoteForm.errors.notes" />
                    </div>

                    <div>
                        <label>Senha temporária</label>
                        <div class="mt-1 flex gap-2">
                            <input v-model="promoteForm.portal_password" class="input" placeholder="Vazio = gerar automática" />
                            <button type="button" class="rounded border bg-gray-100 px-3 py-2 text-sm" @click="generatePromotionTemporaryPassword">
                                Gerar
                            </button>
                        </div>
                        <InputError class="mt-2" :message="promoteForm.errors.portal_password" />
                    </div>

                    <div class="flex justify-end gap-3">
                        <SecondaryButton @click="closePromoteModal">Cancelar</SecondaryButton>
                        <PrimaryButton :disabled="promoteForm.processing">Promover</PrimaryButton>
                    </div>
                </form>
            </div>
        </Modal>
    </BaseLayout>
</template>

<style scoped>
.input {
    @apply w-full border rounded px-3 py-2 text-sm;
}
</style>
