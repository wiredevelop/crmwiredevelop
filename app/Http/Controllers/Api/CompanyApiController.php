<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Models\Setting;
use App\Support\CompanySettings;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CompanyApiController extends Controller
{
    use RespondsWithJson;

    public function index(): JsonResponse
    {
        return $this->success([
            'company' => CompanySettings::get(),
        ]);
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['nullable', 'string', 'max:255'],
            'vat' => ['nullable', 'string', 'max:50'],
            'address' => ['nullable', 'string', 'max:255'],
            'city' => ['nullable', 'string', 'max:100'],
            'postal_code' => ['nullable', 'string', 'max:40'],
            'country' => ['nullable', 'string', 'max:100'],
            'email' => ['nullable', 'string', 'max:255'],
            'phone' => ['nullable', 'string', 'max:50'],
            'website' => ['nullable', 'string', 'max:255'],
            'iban' => ['nullable', 'string', 'max:80'],
            'bank_name' => ['nullable', 'string', 'max:120'],
            'swift' => ['nullable', 'string', 'max:80'],
            'client_checkout_method' => ['required', 'in:stripe,manual'],
            'payment_notes' => ['nullable', 'string', 'max:2000'],
            'payment_methods' => ['nullable', 'array'],
            'payment_methods.*.label' => ['nullable', 'string', 'max:80'],
            'payment_methods.*.value' => ['nullable', 'string', 'max:255'],
        ]);

        Setting::updateOrCreate(['key' => 'company_data'], ['value' => json_encode($data)]);

        return $this->success([
            'company' => CompanySettings::get(),
        ], 'Dados da empresa guardados.');
    }
}
