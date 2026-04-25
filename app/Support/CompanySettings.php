<?php

namespace App\Support;

use App\Models\Setting;

class CompanySettings
{
    public static function get(): array
    {
        $value = Setting::where('key', 'company_data')->value('value');

        if (!$value) {
            return self::defaults();
        }

        $decoded = json_decode($value, true);

        $data = is_array($decoded) ? $decoded : [];

        $merged = array_merge(self::defaults(), $data);

        foreach (['vat', 'address'] as $key) {
            if (self::shouldHide($merged[$key] ?? null)) {
                $merged[$key] = null;
            }
        }

        return $merged;
    }

    private static function defaults(): array
    {
        return [
            'name' => 'WireDevelop',
            'vat' => null,
            'address' => null,
            'city' => '',
            'postal_code' => '',
            'country' => '',
            'email' => 'geral@wiredevelop.pt',
            'phone' => '963286319',
            'website' => 'www.wiredevelop.pt',
            'iban' => 'LT123123123123123123',
            'bank_name' => 'Revolut Bank',
            'swift' => 'REVBK',
            'payment_notes' => '',
            'payment_methods' => [],
        ];
    }

    private static function shouldHide($value): bool
    {
        if (!is_string($value)) {
            return empty($value);
        }

        $normalized = trim($value);
        if ($normalized === '') {
            return true;
        }

        $upper = function_exists('mb_strtoupper')
            ? mb_strtoupper($normalized, 'UTF-8')
            : strtoupper($normalized);

        return in_array($upper, ['NAO', 'NÃO', 'NAO MOSTRA', 'NÃO MOSTRA'], true);
    }
}
