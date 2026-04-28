<script setup>
import { onMounted, ref, watch } from 'vue'

const props = defineProps({
    modelValue: { type: String, default: '' },
    placeholder: { type: String, default: '' },
    minHeight: { type: String, default: '120px' },
})

const emit = defineEmits(['update:modelValue'])

const editorRef = ref(null)
const lastHtml = ref('')

const hasHtmlTags = (value) => /<\s*[\w-]+[^>]*>/.test(value || '')

const escapeHtml = (value) =>
    (value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;')

const decodeHtmlEntities = (value) => {
    if (!value) return ''
    const textarea = document.createElement('textarea')
    textarea.innerHTML = value
    return textarea.value
}

const normalizeToHtml = (value) => {
    if (!value) return ''
    if (hasHtmlTags(value)) return value
    if (value.includes('&lt;') && /&lt;\s*[\w-]+[^&]*&gt;/.test(value)) {
        const decoded = decodeHtmlEntities(value)
        if (hasHtmlTags(decoded)) return decoded
    }
    return escapeHtml(value).replace(/\r\n|\r|\n/g, '<br>')
}

const setHtml = (html) => {
    if (!editorRef.value) return
    if (editorRef.value.innerHTML !== html) {
        editorRef.value.innerHTML = html
    }
}

const sync = () => {
    if (!editorRef.value) return
    let html = editorRef.value.innerHTML
    if (html.includes('&lt;') && /&lt;\s*[\w-]+[^&]*&gt;/.test(html)) {
        const decoded = decodeHtmlEntities(html)
        if (hasHtmlTags(decoded)) {
            setHtml(decoded)
            html = decoded
        }
    }
    if (html === '<br>' || html === '<div><br></div>') {
        html = ''
    }
    lastHtml.value = html
    emit('update:modelValue', html)
}

const exec = (cmd, value = null) => {
    document.execCommand(cmd, false, value)
    editorRef.value?.focus()
    sync()
}

const insertList = (listTag) => {
    const selection = window.getSelection()
    if (!selection || selection.rangeCount === 0) return

    editorRef.value?.focus()
    document.execCommand(listTag === 'ol' ? 'insertOrderedList' : 'insertUnorderedList')

    const anchor = selection.anchorNode
    const anchorEl = anchor
        ? (anchor.nodeType === 1 ? anchor : anchor.parentElement)
        : null

    if (anchorEl && anchorEl.closest && anchorEl.closest('ul,ol')) {
        sync()
        return
    }

    const range = selection.getRangeAt(0)
    const contents = range.extractContents()
    const text = contents.textContent || ''
    const lines = text.split(/\r\n|\r|\n/).map(l => l.trim()).filter(l => l !== '')

    const listEl = document.createElement(listTag)
    if (lines.length === 0) {
        const li = document.createElement('li')
        li.appendChild(document.createElement('br'))
        listEl.appendChild(li)
    } else {
        lines.forEach((line) => {
            const li = document.createElement('li')
            li.appendChild(document.createTextNode(line))
            listEl.appendChild(li)
        })
    }

    range.insertNode(listEl)
    const firstLi = listEl.querySelector('li')
    if (firstLi) {
        range.setStart(firstLi, 0)
        range.collapse(true)
        selection.removeAllRanges()
        selection.addRange(range)
    }

    sync()
}

const insertHtmlAtCursor = (html) => {
    const selection = window.getSelection()
    if (!selection || selection.rangeCount === 0) {
        editorRef.value.innerHTML += html
        return
    }

    const range = selection.getRangeAt(0)
    range.deleteContents()

    const container = document.createElement('div')
    container.innerHTML = html

    const fragment = document.createDocumentFragment()
    let node
    let lastNode = null
    while ((node = container.firstChild)) {
        lastNode = fragment.appendChild(node)
    }

    range.insertNode(fragment)

    if (lastNode) {
        range.setStartAfter(lastNode)
        range.collapse(true)
        selection.removeAllRanges()
        selection.addRange(range)
    }
}

const onPaste = (event) => {
    event.preventDefault()

    const clipboard = event.clipboardData
    const html = clipboard.getData('text/html')
    if (html) {
        insertHtmlAtCursor(html)
        sync()
        return
    }

    const text = clipboard.getData('text/plain')
    if (text) {
        if (hasHtmlTags(text)) {
            insertHtmlAtCursor(text)
            sync()
            return
        }
        const escaped = escapeHtml(text).replace(/\r\n|\r|\n/g, '<br>')
        insertHtmlAtCursor(escaped)
        sync()
    }
}

const onInput = () => sync()

const insertLink = () => {
    const url = window.prompt('URL')
    if (!url) return
    exec('createLink', url)
}

onMounted(() => {
    setHtml(normalizeToHtml(props.modelValue))
    lastHtml.value = editorRef.value?.innerHTML || ''
})

watch(
    () => props.modelValue,
    (value) => {
        if (value === lastHtml.value) return
        setHtml(normalizeToHtml(value))
    }
)
</script>

<template>
    <div class="w-full">
        <div class="flex flex-wrap gap-1 border rounded-t p-1 bg-gray-50">
            <button type="button" class="px-2 py-1 text-sm border rounded bg-white hover:bg-gray-100"
                @click="exec('bold')" title="Negrito">
                <strong>B</strong>
            </button>
            <button type="button" class="px-2 py-1 text-sm border rounded bg-white hover:bg-gray-100"
                @click="exec('italic')" title="Itálico">
                <em>I</em>
            </button>
            <button type="button" class="px-2 py-1 text-sm border rounded bg-white hover:bg-gray-100"
                @click="exec('underline')" title="Sublinhado">
                <span class="underline">U</span>
            </button>
            <button type="button" class="px-2 py-1 text-sm border rounded bg-white hover:bg-gray-100"
                @click="insertList('ul')" title="Lista">
                • Lista
            </button>
            <button type="button" class="px-2 py-1 text-sm border rounded bg-white hover:bg-gray-100"
                @click="insertList('ol')" title="Lista numerada">
                1. Lista
            </button>
            <button type="button" class="px-2 py-1 text-sm border rounded bg-white hover:bg-gray-100"
                @click="exec('formatBlock', 'blockquote')" title="Citação">
                “Citação”
            </button>
            <button type="button" class="px-2 py-1 text-sm border rounded bg-white hover:bg-gray-100"
                @click="insertLink" title="Inserir link">
                Link
            </button>
            <button type="button" class="px-2 py-1 text-sm border rounded bg-white hover:bg-gray-100"
                @click="exec('removeFormat')" title="Limpar formatação">
                Limpar
            </button>
        </div>
        <div
            ref="editorRef"
            class="w-full border border-t-0 rounded-b p-2 focus:outline-none rte"
            :style="{ minHeight }"
            contenteditable="true"
            :data-placeholder="placeholder"
            @input="onInput"
            @paste="onPaste"
        ></div>
    </div>
</template>

<style scoped>
[contenteditable][data-placeholder]:empty:before {
    content: attr(data-placeholder);
    color: #9ca3af;
}

.rte {
    font-size: 0.875rem;
    line-height: 1.25rem;
}

.rte ul,
.rte ol,
.rte li {
    all: revert;
}

.rte ul {
    list-style-type: disc !important;
    list-style-position: outside !important;
    margin: 0 0 0.5rem 0 !important;
    padding-left: 1.5rem !important;
}

.rte ol {
    list-style-type: decimal !important;
    list-style-position: outside !important;
    margin: 0 0 0.5rem 0 !important;
    padding-left: 1.5rem !important;
}

.rte li {
    display: list-item !important;
    margin: 0.125rem 0 !important;
}
.rte ul {
    list-style-type: disc !important;
    list-style-position: outside !important;
    margin: 0 0 0.5rem 0 !important;
    padding-left: 1.5rem !important;
}

.rte ol {
    list-style-type: decimal !important;
    list-style-position: outside !important;
    margin: 0 0 0.5rem 0 !important;
    padding-left: 1.5rem !important;
}

.rte li {
    display: list-item !important;
    margin: 0.125rem 0 !important;
}
</style>
