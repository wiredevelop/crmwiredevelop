<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class QuoteResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'project_id' => $this->project_id,
            'project_type' => $this->project_type,
            'technologies' => $this->technologies,
            'description' => $this->description,
            'development_items' => $this->development_items,
            'development_total_hours' => $this->development_total_hours,
            'price_development' => $this->price_development,
            'adjudication_percent' => $this->adjudication_percent,
            'adjudication_paid_at' => $this->adjudication_paid_at,
            'include_domain' => (bool) $this->include_domain,
            'include_hosting' => (bool) $this->include_hosting,
            'price_domain_first_year' => $this->price_domain_first_year,
            'price_domain_other_years' => $this->price_domain_other_years,
            'price_hosting_first_year' => $this->price_hosting_first_year,
            'price_hosting_other_years' => $this->price_hosting_other_years,
            'price_domains' => $this->price_domains,
            'price_hosting' => $this->price_hosting,
            'price_maintenance_monthly' => $this->price_maintenance_monthly,
            'price_maintenance_fixed' => $this->price_maintenance_fixed,
            'terms' => $this->terms,
            'public_token' => $this->public_token,
            'project' => $this->when(
                $this->relationLoaded('project') && $this->project,
                fn () => new ProjectResource($this->project)
            ),
            'quote_products' => QuoteProductResource::collection($this->whenLoaded('quoteProducts')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
