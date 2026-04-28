<script setup>
defineProps({
    variant: {
        type: String,
        default: 'split'
    }
})
</script>

<template>
    <div
        class="min-h-screen px-4 py-8"
        :class="variant === 'brand' ? 'bg-[#015557]' : 'bg-gradient-to-br from-slate-100 via-white to-emerald-50'"
    >
        <div
            class="mx-auto w-full overflow-hidden rounded-2xl bg-white shadow-xl ring-1 ring-black/5"
            :class="variant === 'brand' ? 'max-w-xl' : 'max-w-5xl'"
        >
            <div v-if="variant === 'split'" class="grid lg:grid-cols-2">
                <div class="hidden lg:flex flex-col justify-between bg-[#015557] p-10 text-white">
                    <div>
                        <div class="text-2xl font-semibold">WireDevelop CRM</div>
                        <p class="mt-3 text-sm text-white/80">
                            Gestao clara de clientes, projetos e faturacao.
                        </p>
                    </div>
                    <p class="text-xs text-white/70">Acesso seguro e rapido.</p>
                </div>

                <div class="p-8 sm:p-10">
                    <slot />
                </div>
            </div>

            <div v-else class="p-8 sm:p-10">
                <slot />
            </div>
        </div>
    </div>
</template>
