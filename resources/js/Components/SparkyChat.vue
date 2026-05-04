<script setup>
import { ref, nextTick, watch } from 'vue'
import axios from 'axios'

const open = ref(false)
const question = ref('')
const loading = ref(false)
const messagesEl = ref(null)

const history = ref([])

const messages = ref([
    { role: 'assistant', content: 'Olá! Sou o **Sparky** ⚡ O teu assistente do WireDevelop CRM. Em que posso ajudar?' }
])

function toggle() {
    open.value = !open.value
}

async function send() {
    const q = question.value.trim()
    if (!q || loading.value) return

    messages.value.push({ role: 'user', content: q })
    question.value = ''
    loading.value = true
    await scrollBottom()

    try {
        const { data } = await axios.post('/api/v1/sparky/ask', {
            question: q,
            history: history.value,
        })

        const answer = data.answer
        messages.value.push({ role: 'assistant', content: answer })
        history.value.push({ role: 'user', content: q }, { role: 'assistant', content: answer })

        if (history.value.length > 40) {
            history.value = history.value.slice(-40)
        }
    } catch {
        messages.value.push({ role: 'assistant', content: 'Ocorreu um erro. Tenta novamente.' })
    } finally {
        loading.value = false
        await scrollBottom()
    }
}

function onKeydown(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault()
        send()
    }
}

async function scrollBottom() {
    await nextTick()
    if (messagesEl.value) {
        messagesEl.value.scrollTop = messagesEl.value.scrollHeight
    }
}

function formatMessage(text) {
    return text
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
        .replace(/\*(.*?)\*/g, '<em>$1</em>')
        .replace(/^- (.+)$/gm, '<li>$1</li>')
        .replace(/(<li>.*<\/li>)/gs, '<ul class="list-disc list-inside mt-1 space-y-0.5">$1</ul>')
        .replace(/\n/g, '<br>')
}

watch(open, async (val) => {
    if (val) await scrollBottom()
})
</script>

<template>
    <!-- Botão flutuante -->
    <div class="fixed bottom-6 right-6 z-50 flex flex-col items-end gap-3">

        <!-- Janela de chat -->
        <Transition
            enter-active-class="transition duration-200 ease-out"
            enter-from-class="opacity-0 translate-y-4 scale-95"
            enter-to-class="opacity-100 translate-y-0 scale-100"
            leave-active-class="transition duration-150 ease-in"
            leave-from-class="opacity-100 translate-y-0 scale-100"
            leave-to-class="opacity-0 translate-y-4 scale-95"
        >
            <div
                v-if="open"
                class="w-80 sm:w-96 bg-white rounded-2xl shadow-2xl border border-gray-200 flex flex-col overflow-hidden"
                style="height: 480px;"
            >
                <!-- Header -->
                <div class="bg-[#015557] text-white px-4 py-3 flex items-center justify-between">
                    <div class="flex items-center gap-2">
                        <span class="text-xl">⚡</span>
                        <div>
                            <div class="font-semibold text-sm leading-tight">Sparky</div>
                            <div class="text-xs text-white/70">Assistente WireDevelop</div>
                        </div>
                    </div>
                    <button @click="toggle" class="text-white/80 hover:text-white text-lg leading-none">✕</button>
                </div>

                <!-- Mensagens -->
                <div
                    ref="messagesEl"
                    class="flex-1 overflow-y-auto px-4 py-3 space-y-3 bg-gray-50"
                >
                    <div
                        v-for="(msg, i) in messages"
                        :key="i"
                        :class="msg.role === 'user' ? 'flex justify-end' : 'flex justify-start'"
                    >
                        <div
                            :class="[
                                'max-w-[85%] px-3 py-2 rounded-2xl text-sm leading-relaxed',
                                msg.role === 'user'
                                    ? 'bg-[#015557] text-white rounded-br-sm'
                                    : 'bg-white text-gray-800 border border-gray-200 rounded-bl-sm shadow-sm'
                            ]"
                            v-html="formatMessage(msg.content)"
                        />
                    </div>

                    <!-- Indicador de carregamento -->
                    <div v-if="loading" class="flex justify-start">
                        <div class="bg-white border border-gray-200 rounded-2xl rounded-bl-sm px-4 py-2 shadow-sm">
                            <div class="flex gap-1 items-center h-4">
                                <span class="w-1.5 h-1.5 bg-[#015557] rounded-full animate-bounce" style="animation-delay:0ms"></span>
                                <span class="w-1.5 h-1.5 bg-[#015557] rounded-full animate-bounce" style="animation-delay:150ms"></span>
                                <span class="w-1.5 h-1.5 bg-[#015557] rounded-full animate-bounce" style="animation-delay:300ms"></span>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Input -->
                <div class="border-t border-gray-200 bg-white px-3 py-2 flex gap-2 items-end">
                    <textarea
                        v-model="question"
                        @keydown="onKeydown"
                        placeholder="Pergunta ao Sparky..."
                        rows="1"
                        class="flex-1 resize-none border border-gray-300 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[#015557]/40 focus:border-[#015557] max-h-24"
                        style="min-height: 38px;"
                    />
                    <button
                        @click="send"
                        :disabled="loading || !question.trim()"
                        class="flex-shrink-0 bg-[#015557] text-white rounded-xl px-3 py-2 text-sm font-medium hover:bg-[#014446] disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
                    >
                        ➤
                    </button>
                </div>
            </div>
        </Transition>

        <!-- Botão toggle -->
        <button
            @click="toggle"
            class="w-14 h-14 rounded-full bg-[#015557] text-white shadow-lg hover:bg-[#014446] hover:scale-105 active:scale-95 transition-all flex items-center justify-center text-2xl"
            :title="open ? 'Fechar Sparky' : 'Abrir Sparky'"
        >
            <span v-if="!open">⚡</span>
            <span v-else class="text-base">✕</span>
        </button>
    </div>
</template>
