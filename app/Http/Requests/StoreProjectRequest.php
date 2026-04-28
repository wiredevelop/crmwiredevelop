<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreProjectRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'client_id' => ['required', 'integer', 'exists:clients,id'],
            'name' => ['required', 'string', 'max:255'],
            'type' => ['required', 'string', 'max:255'],
            'custom_type' => ['nullable', 'string', 'max:255'],
            'status' => ['required', 'string', 'max:255'],

            'technologies' => ['nullable', 'string'],
            'description' => ['nullable', 'string'],

            'development_items' => ['required', 'array'],
            'development_items.*.feature' => ['required', 'string'],
            'development_items.*.hours' => ['required', 'numeric'],
            'development_total_hours' => ['required', 'numeric'],

            'price_development' => ['required', 'numeric', 'min:0'],

            // manutenção mensal (opcional)
            'price_maintenance_monthly' => ['nullable', 'numeric', 'min:0'],

            // toggles
            'include_domain' => ['nullable', 'boolean'],
            'include_hosting' => ['nullable', 'boolean'],

            'price_domain_first_year' => ['nullable', 'numeric', 'min:0'],
            'price_domain_other_years' => ['nullable', 'numeric', 'min:0'],
            'price_hosting_first_year' => ['nullable', 'numeric', 'min:0'],
            'price_hosting_other_years' => ['nullable', 'numeric', 'min:0'],

            'terms' => ['nullable', 'string'],

            // imports
            'imports' => ['nullable', 'array'],
            'imports.*.product_id' => ['nullable', 'integer'],
            'imports.*.type' => ['required', 'in:product,pack'],
            'imports.*.name' => ['required', 'string', 'max:255'],
            'imports.*.slug' => ['nullable', 'string', 'max:255'],
            'imports.*.short_description' => ['nullable', 'string'],
            'imports.*.content_html' => ['nullable', 'string'],
            'imports.*.price' => ['nullable', 'numeric'],

            'imports.*.pack_items' => ['nullable', 'array'],
            'imports.*.pack_items.*.hours' => ['nullable', 'numeric'],
            'imports.*.pack_items.*.normal_price' => ['nullable', 'numeric'],
            'imports.*.pack_items.*.pack_price' => ['nullable', 'numeric'],
            'imports.*.pack_items.*.validity_months' => ['nullable', 'numeric'],
            'imports.*.pack_items.*.featured' => ['nullable', 'boolean'],

            'imports.*.info_fields' => ['nullable', 'array'],
            'imports.*.info_fields.*.type' => ['required', 'in:text,textarea,html,boolean'],
            'imports.*.info_fields.*.label' => ['nullable', 'string', 'max:255'],
            'imports.*.info_fields.*.value' => ['nullable'],
        ];
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'include_domain' => filter_var($this->input('include_domain'), FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) ?? false,
            'include_hosting' => filter_var($this->input('include_hosting'), FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) ?? false,
        ]);
    }

    public function messages(): array
    {
        return [
            'client_id.required' => 'Selecciona um cliente.',
            'client_id.exists' => 'O cliente selecionado é inválido.',

            'name.required' => 'Indica o nome do projeto.',
            'type.required' => 'Seleciona o tipo de projeto.',

            'custom_type.required_if' => 'Quando escolhes "Outros", tens de especificar o tipo.',

            'development_items.required' => 'Adiciona pelo menos uma funcionalidade.',
            'development_items.*.feature.required' => 'A funcionalidade é obrigatória.',
            'development_items.*.hours.required' => 'Indica as horas para cada funcionalidade.',

            'price_development.required' => 'Indica o valor do desenvolvimento.',
            'terms.required' => 'Os prazos e condições são obrigatórios.',
        ];
    }
}
