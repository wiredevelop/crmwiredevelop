<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Quote extends Model
{
    use HasFactory;

    protected $casts = [
        'development_items' => 'array',
        'include_domain' => 'boolean',
        'include_hosting' => 'boolean',
        'adjudication_percent' => 'float',
        'adjudication_paid_at' => 'date',
    ];

    protected $fillable = [
        'project_id',
        'project_type',
        'technologies',
        'description',

        'development_items',
        'development_total_hours',

        'price_development',
        'adjudication_percent',
        'adjudication_paid_at',

        'include_domain',
        'include_hosting',

        'price_domain_first_year',
        'price_domain_other_years',
        'price_hosting_first_year',
        'price_hosting_other_years',

        // usados no PDF
        'price_domains',
        'price_hosting',

        'price_maintenance_monthly',
        'price_maintenance_fixed',

        'terms',
    ];

    public function project()
    {
        return $this->belongsTo(Project::class);
    }

    public function quoteProducts()
    {
        return $this->hasMany(QuoteProduct::class)->orderBy('order');
    }

    protected static function booted()
    {
        static::creating(function ($quote) {
            if (!$quote->public_token) {
                $quote->public_token = bin2hex(random_bytes(16));
            }
        });
    }
}
