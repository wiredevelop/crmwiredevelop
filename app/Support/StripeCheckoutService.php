<?php

namespace App\Support;

use App\Models\Client;
use App\Models\PackItem;
use App\Models\Product;
use Stripe\Checkout\Session;
use Stripe\Customer;
use Stripe\StripeClient;

class StripeCheckoutService
{
    public function createPackCheckoutSession(
        Client $client,
        Product $product,
        PackItem $packItem,
        int $quantity,
        string $successUrl,
        string $cancelUrl
    ): Session {
        $stripe = $this->client();
        $customer = $this->ensureCustomer($stripe, $client);
        $unitAmount = (int) round(((float) $packItem->pack_price) * 100);

        return $stripe->checkout->sessions->create([
            'mode' => 'payment',
            'customer' => $customer->id,
            'success_url' => $successUrl,
            'cancel_url' => $cancelUrl,
            'billing_address_collection' => 'required',
            'tax_id_collection' => ['enabled' => true],
            'customer_update' => [
                'name' => 'auto',
                'address' => 'auto',
            ],
            'line_items' => [[
                'quantity' => $quantity,
                'price_data' => [
                    'currency' => 'eur',
                    'unit_amount' => $unitAmount,
                    'product_data' => [
                        'name' => $this->productLabel($product, $packItem),
                        'metadata' => [
                            'client_id' => (string) $client->id,
                            'product_id' => (string) $product->id,
                            'pack_item_id' => (string) $packItem->id,
                        ],
                    ],
                ],
            ]],
            'metadata' => [
                'client_id' => (string) $client->id,
                'product_id' => (string) $product->id,
                'pack_item_id' => (string) $packItem->id,
                'quantity' => (string) $quantity,
                'source' => 'flutter_wallet',
            ],
        ]);
    }

    private function ensureCustomer(StripeClient $stripe, Client $client): Customer
    {
        if ($client->stripe_customer_id) {
            /** @var Customer $customer */
            $customer = $stripe->customers->retrieve($client->stripe_customer_id, []);

            return $customer;
        }

        /** @var Customer $customer */
        $customer = $stripe->customers->create([
            'name' => $client->billing_name ?: $client->name,
            'email' => $client->billing_email ?: $client->email,
            'phone' => $client->billing_phone ?: $client->phone,
            'address' => $this->customerAddress($client),
            'metadata' => [
                'client_id' => (string) $client->id,
                'company' => (string) ($client->company ?? ''),
            ],
        ]);

        $client->forceFill(['stripe_customer_id' => $customer->id])->save();

        return $customer;
    }

    private function customerAddress(Client $client): ?array
    {
        if (! $client->billing_address && ! $client->billing_postal_code && ! $client->billing_city && ! $client->billing_country) {
            return null;
        }

        return [
            'line1' => $client->billing_address,
            'postal_code' => $client->billing_postal_code,
            'city' => $client->billing_city,
            'country' => $client->billing_country,
        ];
    }

    private function productLabel(Product $product, PackItem $packItem): string
    {
        $label = $product->name;
        if ($packItem->hours) {
            $label .= ' - '.$packItem->hours.'h';
        }

        return $label;
    }

    private function client(): StripeClient
    {
        return new StripeClient([
            'api_key' => (string) config('services.stripe.secret_key'),
            'stripe_version' => (string) config('services.stripe.api_version'),
        ]);
    }
}
