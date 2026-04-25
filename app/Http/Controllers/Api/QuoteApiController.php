<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Concerns\RespondsWithJson;
use App\Http\Controllers\Controller;
use App\Http\Resources\Api\QuoteResource;
use App\Models\Installment;
use App\Models\Quote;
use App\Support\CompanySettings;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use PhpOffice\PhpWord\IOFactory;
use PhpOffice\PhpWord\PhpWord;

class QuoteApiController extends Controller
{
    use RespondsWithJson;

    public function index(Request $request): JsonResponse
    {
        $quotes = Quote::with(['project.client', 'quoteProducts'])
            ->whereHas('project', fn ($query) => $query->whereNotIn('status', ['concluido', 'cancelado']))
            ->latest()
            ->paginate((int) $request->integer('per_page', 15));

        $baseQuery = Quote::query()
            ->join('projects', 'projects.id', '=', 'quotes.project_id')
            ->whereNotIn('projects.status', ['concluido', 'cancelado']);

        $pipelineBaseTotal = (float) (clone $baseQuery)->selectRaw('SUM(COALESCE(quotes.price_development, 0)) as total')->value('total');
        $adjudicationsTotal = (float) (clone $baseQuery)
            ->whereNotNull('quotes.adjudication_percent')
            ->where('quotes.adjudication_percent', '>', 0)
            ->selectRaw('SUM(COALESCE(quotes.price_development, 0) * (quotes.adjudication_percent / 100)) as total')
            ->value('total');
        $installmentsTotal = (float) Installment::query()
            ->join('projects', 'projects.id', '=', 'installments.project_id')
            ->leftJoin('invoices', 'invoices.project_id', '=', 'projects.id')
            ->whereNotIn('projects.status', ['concluido', 'cancelado'])
            ->where(fn ($query) => $query->whereNull('invoices.id')->orWhere('invoices.status', '!=', 'pago'))
            ->selectRaw('SUM(COALESCE(installments.amount, 0)) as total')
            ->value('total');

        $installmentsByProject = Installment::query()
            ->join('projects', 'projects.id', '=', 'installments.project_id')
            ->whereNotIn('projects.status', ['concluido', 'cancelado'])
            ->selectRaw('installments.project_id, SUM(COALESCE(installments.amount, 0)) as total')
            ->groupBy('installments.project_id')
            ->pluck('total', 'installments.project_id');

        return $this->paginated($request, $quotes, QuoteResource::collection($quotes->getCollection())->resolve(), null, [
            'pipeline_base_total' => $pipelineBaseTotal,
            'adjudications_total' => $adjudicationsTotal,
            'installments_total' => $installmentsTotal,
            'installments_by_project' => $installmentsByProject,
            'pipeline_total' => max(0, $pipelineBaseTotal - $adjudicationsTotal - $installmentsTotal),
        ]);
    }

    public function show(Quote $quote): JsonResponse
    {
        $quote->load(['project.client', 'quoteProducts']);

        return $this->success([
            'quote' => new QuoteResource($quote),
        ]);
    }

    public function updateAdjudication(Request $request, Quote $quote): JsonResponse
    {
        $data = $request->validate([
            'adjudication_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'adjudication_paid_at' => ['nullable', 'date'],
        ]);

        $percent = $data['adjudication_percent'];
        if ($percent !== null && $percent <= 0) {
            $percent = null;
        }

        $quote->adjudication_percent = $percent;
        $quote->adjudication_paid_at = $percent ? ($data['adjudication_paid_at'] ?? now()->toDateString()) : null;
        $quote->save();

        return $this->success([
            'quote' => new QuoteResource($quote->fresh(['project.client', 'quoteProducts'])),
        ], 'Adjudicação atualizada com sucesso.');
    }

    public function pdf(Quote $quote)
    {
        return $this->generatePdf($quote);
    }

    public function docx(Quote $quote)
    {
        $quote->load(['project.client', 'quoteProducts']);

        $phpWord = new PhpWord();
        $phpWord->setDefaultFontName('Calibri');
        $phpWord->setDefaultFontSize(11);

        $section = $phpWord->addSection();
        $section->addText('ORÇAMENTO');
        $section->addText($quote->project?->name ?? 'Projeto');
        $section->addText(strip_tags((string) $quote->description));

        return response()->streamDownload(function () use ($phpWord) {
            $writer = IOFactory::createWriter($phpWord, 'Word2007');
            $writer->save('php://output');
        }, "Orcamento-{$quote->id}.docx", [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ]);
    }

    public function publicView(string $token): JsonResponse
    {
        $quote = Quote::where('public_token', $token)->with(['project.client', 'quoteProducts'])->firstOrFail();

        return $this->success([
            'quote' => new QuoteResource($quote),
        ]);
    }

    public function publicPdf(string $token)
    {
        $quote = Quote::where('public_token', $token)->with('project.client')->firstOrFail();

        return $this->generatePdf($quote);
    }

    private function generatePdf(Quote $quote)
    {
        $quote->load(['project.client', 'quoteProducts']);

        $pdf = Pdf::loadView('pdf.quote', [
            'quote' => $quote,
            'project' => $quote->project,
            'client' => $quote->project->client,
            'company' => CompanySettings::get(),
        ])->setPaper('a4', 'portrait');

        return $pdf->stream("Orcamento-{$quote->id}.pdf");
    }
}
