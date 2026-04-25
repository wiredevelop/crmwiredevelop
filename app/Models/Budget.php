<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Budget extends Model
{
    use HasFactory;

    protected $fillable = [
        'project_id',
        'type',
        'technologies',
        'description_html',
        'development_table',
        'development_total_hours',
        'prices',
        'terms_html',
    ];

    protected $casts = [
        'technologies'            => 'array',
        'development_table'       => 'array',
        'prices'                  => 'array',
        'development_total_hours' => 'integer',
    ];

    /**
     * Projeto associado a este orçamento.
     */
    public function project()
    {
        return $this->belongsTo(Project::class);
    }
}
