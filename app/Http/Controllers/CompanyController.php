<?php

namespace App\Http\Controllers;

use App\Models\Setting;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class CompanyController extends Controller
{
    public function index(): Response
    {
        $company = \App\Support\CompanySettings::get();

        return Inertia::render('Company/Index', [
            'company' => is_array($company) ? $company : [],
        ]);
    }

    public function update(Request $request): RedirectResponse
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

        Setting::updateOrCreate(
            ['key' => 'company_data'],
            ['value' => json_encode($data)]
        );

        return back()->with('success', 'Dados da empresa guardados.');
    }
}
