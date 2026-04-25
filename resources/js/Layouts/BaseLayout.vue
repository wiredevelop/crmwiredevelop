<script setup>
import { Link, usePage } from '@inertiajs/vue3'
import { ref } from 'vue'

const user = usePage().props.auth?.user
const sidebarOpen = ref(false)
</script>

<template>
    <div class="min-h-screen bg-gray-100">
        <div v-if="sidebarOpen" class="fixed inset-0 bg-black/40 z-30 lg:hidden" @click="sidebarOpen = false"></div>

        <div class="lg:flex lg:h-screen lg:overflow-hidden">
            <!-- SIDEBAR -->
            <aside
                class="fixed inset-y-0 left-0 z-40 w-64 bg-[#015557] text-white flex flex-col shadow-xl transform transition-transform duration-200 lg:static lg:translate-x-0 lg:h-screen lg:overflow-y-auto"
                :class="sidebarOpen ? 'translate-x-0' : '-translate-x-full'"
            >
                <div class="px-6 py-4 text-2xl font-bold border-b border-white/20 flex items-center justify-between">
                    <span>WireDevelop CRM</span>
                    <button type="button" class="lg:hidden text-white/80 hover:text-white" @click="sidebarOpen = false">
                        ✕
                    </button>
                </div>

                <nav class="flex-1 px-4 py-6 space-y-1">
                    <Link href="/dashboard" class="block px-4 py-2 rounded hover:bg-white/10">Dashboard</Link>
                    <Link href="/interventions" class="block px-4 py-2 rounded hover:bg-white/10">Intervenções</Link>
                    <Link href="/clients" class="block px-4 py-2 rounded hover:bg-white/10">Clientes</Link>
                    <Link href="/projects" class="block px-4 py-2 rounded hover:bg-white/10">Projetos</Link>
                    <Link href="/finance" class="block px-4 py-2 rounded hover:bg-white/10">Financeiro</Link>
                    <Link href="/settings" class="block px-4 py-2 rounded hover:bg-white/10">Definições</Link>
                </nav>
            </aside>

            <!-- CONTEÚDO -->
            <div class="flex-1 flex flex-col min-w-0 lg:h-screen lg:ml-0">
                <!-- NAVBAR -->
                <header class="h-14 bg-white shadow flex justify-between items-center px-4 sm:px-6">
                    <div class="flex items-center gap-3">
                        <button type="button" class="lg:hidden text-gray-600" @click="sidebarOpen = true">
                            ☰
                        </button>
                        <h1 class="text-lg sm:text-xl font-semibold text-gray-800">
                            <slot name="title">Dashboard</slot>
                        </h1>
                    </div>

                    <div class="flex items-center space-x-3 sm:space-x-4">
                        <span class="text-gray-700 text-sm sm:text-base">{{ user?.name }}</span>

                        <Link
                            method="post"
                            href="/logout"
                            as="button"
                            class="text-red-500 hover:underline text-sm sm:text-base"
                        >
                            Logout
                        </Link>
                    </div>
                </header>

                <!-- MAIN -->
                <main class="flex-1 p-4 sm:p-6 overflow-y-auto overflow-x-auto">
                    <slot />
                </main>
            </div>
        </div>
    </div>
</template>
