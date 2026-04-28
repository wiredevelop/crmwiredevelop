<script setup>
import Checkbox from '@/Components/Checkbox.vue'
import GuestLayout from '@/Layouts/GuestLayout.vue'
import InputError from '@/Components/InputError.vue'
import InputLabel from '@/Components/InputLabel.vue'
import PrimaryButton from '@/Components/PrimaryButton.vue'
import TextInput from '@/Components/TextInput.vue'
import { Head, Link, useForm } from '@inertiajs/vue3'
import { ref } from 'vue'
import Webpass from '@laragear/webpass'

defineProps({
    canResetPassword: Boolean,
    status: String,
})

const form = useForm({
    email: '',
    password: '',
    remember: false,
})

const brandExpanded = ref(true)

const submit = () => {
    form.post(route('login'), {
        onFinish: () => form.reset('password'),
    })
}

const loginWithPasskey = async () => {
    try {
        if (Webpass.isUnsupported()) {
            alert('O teu navegador não suporta Passkeys.')
            return
        }

        const { success, error } = await Webpass.assert(
            '/webauthn/login/options',
            '/webauthn/login'
        )

        if (!success) {
            console.error(error)
            alert('Falhou login com Passkey.')
            return
        }

        window.location.href = route('dashboard')
    } catch (e) {
        console.error(e)
        alert('Erro no login com Passkey.')
    }
}
</script>

<template>
    <GuestLayout variant="brand">
        <Head title="Login" />

        <div
            class="overflow-hidden text-center transition-all duration-500 ease-out"
            :class="brandExpanded
                ? 'max-h-[260px] opacity-100 mb-8 py-8 bg-[#015557] -mx-8 -mt-8 sm:-mx-10 sm:-mt-10 rounded-t-2xl'
                : 'max-h-0 opacity-0 mb-0 py-0 pointer-events-none'"
        >
            <button type="button" class="w-full" @click="brandExpanded = false">
                <img
                    src="/logo/logo.png"
                    alt="WireDevelop"
                    class="mx-auto h-24 sm:h-28"
                />
            </button>
        </div>

        <div class="mb-6">
            <p class="text-xs uppercase tracking-widest text-[#015557]">WireDevelop CRM</p>
            <h1 class="mt-2 text-2xl font-semibold text-gray-900">Entrar</h1>
            <p class="mt-2 text-sm text-gray-500">Acede ao painel com a tua conta.</p>
        </div>

        <div v-if="status" class="mb-4 rounded border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-700">
            {{ status }}
        </div>

        <form @submit.prevent="submit" class="space-y-4">
            <div>
                <InputLabel for="email" value="Email" />
                <TextInput id="email" type="email" v-model="form.email" required class="mt-1 w-full" />
                <InputError :message="form.errors.email" class="mt-2" />
            </div>

            <div>
                <InputLabel for="password" value="Password" />
                <TextInput id="password" type="password" v-model="form.password" required class="mt-1 w-full" />
                <InputError :message="form.errors.password" class="mt-2" />
            </div>

            <div class="flex items-center justify-between text-sm text-gray-500">
                <label class="flex items-center gap-2">
                    <Checkbox name="remember" v-model:checked="form.remember" />
                    Lembrar-me
                </label>

                <Link v-if="canResetPassword" href="/forgot-password" class="text-[#015557] hover:underline">
                    Esqueceu a password?
                </Link>
            </div>

            <PrimaryButton :disabled="form.processing" class="w-full justify-center">
                Entrar
            </PrimaryButton>

            <button
                type="button"
                @click="loginWithPasskey"
                class="w-full rounded border border-gray-200 bg-white py-2 text-sm text-gray-700 hover:border-[#015557] hover:text-[#015557]"
            >
                Entrar com Impressao Digital / FaceID
            </button>
        </form>
    </GuestLayout>
</template>
