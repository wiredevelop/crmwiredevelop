<script setup>
import GuestLayout from '@/Layouts/GuestLayout.vue'
import InputError from '@/Components/InputError.vue'
import InputLabel from '@/Components/InputLabel.vue'
import PrimaryButton from '@/Components/PrimaryButton.vue'
import TextInput from '@/Components/TextInput.vue'
import { Head, useForm } from '@inertiajs/vue3'

const form = useForm({
    password: '',
    password_confirmation: '',
})

const submit = () => {
    form.put(route('password.force.update'), {
        onFinish: () => form.reset('password', 'password_confirmation'),
    })
}
</script>

<template>
    <GuestLayout variant="brand">
        <Head title="Alterar senha" />

        <div class="mb-6">
            <p class="text-xs uppercase tracking-widest text-[#015557]">WireDevelop CRM</p>
            <h1 class="mt-2 text-2xl font-semibold text-gray-900">Alterar senha temporária</h1>
            <p class="mt-2 text-sm text-gray-500">Antes de continuar, define uma nova senha para esta conta.</p>
        </div>

        <form @submit.prevent="submit" class="space-y-4">
            <div>
                <InputLabel for="password" value="Nova senha" />
                <TextInput id="password" type="password" v-model="form.password" required class="mt-1 w-full" />
                <InputError :message="form.errors.password" class="mt-2" />
            </div>

            <div>
                <InputLabel for="password_confirmation" value="Confirmar nova senha" />
                <TextInput id="password_confirmation" type="password" v-model="form.password_confirmation" required class="mt-1 w-full" />
                <InputError :message="form.errors.password_confirmation" class="mt-2" />
            </div>

            <PrimaryButton :disabled="form.processing" class="w-full justify-center">
                Guardar nova senha
            </PrimaryButton>
        </form>
    </GuestLayout>
</template>
