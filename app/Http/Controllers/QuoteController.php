<?php

namespace App\Http\Controllers;

use App\Models\Quote;
use App\Models\Installment;
use App\Support\CompanySettings;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\RedirectResponse;
use PhpOffice\PhpWord\IOFactory;
use PhpOffice\PhpWord\PhpWord;

class QuoteController extends Controller
{
    public function index()
    {
        $quotes = Quote::with('project.client')
            ->whereHas('project', function ($query) {
                $query->whereNotIn('status', ['concluido', 'cancelado']);
            })
            ->latest()
            ->paginate(15);

        $baseQuery = Quote::query()
            ->join('projects', 'projects.id', '=', 'quotes.project_id')
            ->whereNotIn('projects.status', ['concluido', 'cancelado']);

        $pipelineBaseTotal = (float) (clone $baseQuery)
            ->selectRaw('SUM(COALESCE(quotes.price_development, 0)) as total')
            ->value('total');

        $adjudicationsTotal = (float) (clone $baseQuery)
            ->whereNotNull('quotes.adjudication_percent')
            ->where('quotes.adjudication_percent', '>', 0)
            ->selectRaw('SUM(COALESCE(quotes.price_development, 0) * (quotes.adjudication_percent / 100)) as total')
            ->value('total');

        $installmentsTotal = (float) Installment::query()
            ->join('projects', 'projects.id', '=', 'installments.project_id')
            ->leftJoin('invoices', 'invoices.project_id', '=', 'projects.id')
            ->whereNotIn('projects.status', ['concluido', 'cancelado'])
            ->where(function ($query) {
                $query->whereNull('invoices.id')
                    ->orWhere('invoices.status', '!=', 'pago');
            })
            ->selectRaw('SUM(COALESCE(installments.amount, 0)) as total')
            ->value('total');

        $installmentsByProject = Installment::query()
            ->join('projects', 'projects.id', '=', 'installments.project_id')
            ->whereNotIn('projects.status', ['concluido', 'cancelado'])
            ->selectRaw('installments.project_id, SUM(COALESCE(installments.amount, 0)) as total')
            ->groupBy('installments.project_id')
            ->pluck('total', 'installments.project_id');

        return Inertia::render('Quotes/Index', [
            'quotes' => $quotes,
            'pipelineBaseTotal' => $pipelineBaseTotal,
            'adjudicationsTotal' => $adjudicationsTotal,
            'installmentsTotal' => $installmentsTotal,
            'installmentsByProject' => $installmentsByProject,
            'pipelineTotal' => max(0, $pipelineBaseTotal - $adjudicationsTotal - $installmentsTotal),
        ]);
    }

    public function show(Quote $quote)
    {
        $quote->load('project.client');
        return Inertia::render('Quotes/Show', compact('quote'));
    }

    public function updateAdjudication(Request $request, Quote $quote): RedirectResponse
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

        return back();
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

        $project = $quote->project;
        $client = $project?->client;
        $company = CompanySettings::get();

        $sanitize = function ($text) {
            $text = (string) $text;
            $text = str_replace('&', 'e', $text);
            $text = preg_replace('/[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F]/u', '', $text);
            return $text;
        };
        $money = fn ($value) => number_format((float) $value, 2, ',', '.') . ' €';

        $brand = '015557';
        $lightBg = 'F5F7F7';
        $border = 'D9E0E1';
        $title1 = ['bold' => true, 'size' => 20, 'color' => $brand];
        $title2 = ['bold' => true, 'size' => 14, 'color' => $brand];
        $phpWord->addTitleStyle(1, $title1);
        $phpWord->addTitleStyle(2, $title2);

        $section = $phpWord->addSection([
            'marginTop' => 900,
            'marginBottom' => 900,
            'marginLeft' => 900,
            'marginRight' => 900,
        ]);

        $noBorderTable = ['borderSize' => 0, 'borderColor' => 'FFFFFF', 'cellMargin' => 0, 'width' => 100 * 50];

        $header = $section->addHeader();
        $headerTable = $header->addTable($noBorderTable);
        $headerTable->addRow();
        $left = $headerTable->addCell(9000, ['bgColor' => $brand, 'valign' => 'center', 'borderSize' => 0, 'borderColor' => 'FFFFFF']);
        $right = $headerTable->addCell(4000, ['bgColor' => $brand, 'valign' => 'center', 'borderSize' => 0, 'borderColor' => 'FFFFFF']);
        $left->addText($sanitize('WireDevelop'), ['bold' => true, 'color' => 'FFFFFF', 'size' => 16]);
        $left->addText($sanitize('Soluções Digitais e Desenvolvimento Web'), ['color' => 'FFFFFF', 'size' => 9]);
        $right->addText($sanitize($company['email'] ?? 'geral@wiredevelop.pt'), ['color' => 'FFFFFF', 'size' => 9], ['align' => 'right']);
        $right->addText($sanitize($company['phone'] ?? '963 286 319'), ['color' => 'FFFFFF', 'size' => 9], ['align' => 'right']);

        $footer = $section->addFooter();
        $footerTable = $footer->addTable($noBorderTable);
        $footerTable->addRow();
        $fLeft = $footerTable->addCell(9000, ['bgColor' => $lightBg, 'valign' => 'center', 'borderSize' => 0, 'borderColor' => 'FFFFFF']);
        $fRight = $footerTable->addCell(4000, ['bgColor' => $lightBg, 'valign' => 'center', 'borderSize' => 0, 'borderColor' => 'FFFFFF']);
        $fLeft->addText($sanitize('WireDevelop'), ['color' => $brand, 'size' => 9]);
        $fRight->addPreserveText($sanitize('Página {PAGE} de {NUMPAGES}'), ['color' => $brand, 'size' => 9], ['align' => 'right']);

        $paraJust = ['alignment' => 'both', 'lineHeight' => 1.5, 'spaceAfter' => 120];
        $paraCenter = ['alignment' => 'center', 'spaceAfter' => 160];

        $section->addText($sanitize('ORÇAMENTO'), ['bold' => true, 'size' => 24, 'color' => $brand], $paraCenter);
        $section->addText($sanitize($project->name ?? 'Projeto'), ['bold' => true, 'size' => 14], $paraCenter);
        $section->addTextBreak(1);

        $section->addTitle($sanitize('Informação'), 2);
        $section->addText($sanitize('Projeto: ' . ($project->name ?? '—')), [], $paraJust);
        $clientLine = 'Cliente: ' . ($client->name ?? '—');
        if (!empty($client?->company)) {
            $clientLine .= ' - ' . $client->company;
        }
        $section->addText($sanitize($clientLine), [], $paraJust);
        $typeLine = 'Tipo: ' . ($quote->project_type ?? '—');
        if (!empty($quote->technologies)) {
            $typeLine .= ' - Tecnologias: ' . $quote->technologies;
        }
        $section->addText($sanitize($typeLine), [], $paraJust);
        $section->addTextBreak(1);

        if (!empty($quote->description)) {
            $section->addTitle($sanitize('Descrição'), 2);
            foreach (preg_split("/\\r\\n|\\r|\\n/", $quote->description) as $line) {
                $section->addText($sanitize($line), [], $paraJust);
            }
            $section->addTextBreak(1);
        }

        $section->addTitle($sanitize('Plano de Desenvolvimento'), 2);
        $tableStyle = ['borderSize' => 6, 'borderColor' => $border, 'cellMargin' => 80];
        $devTable = $section->addTable($tableStyle);
        $devTable->addRow();
        $devTable->addCell(9000, ['bgColor' => $brand])->addText($sanitize('Funcionalidade'), ['bold' => true, 'color' => 'FFFFFF']);
        $devTable->addCell(2000, ['bgColor' => $brand])->addText($sanitize('Horas'), ['bold' => true, 'color' => 'FFFFFF']);
        foreach (($quote->development_items ?? []) as $item) {
            $devTable->addRow();
            $devTable->addCell(9000)->addText($sanitize((string) ($item['feature'] ?? '—')));
            $devTable->addCell(2000)->addText($sanitize((string) ($item['hours'] ?? '0')), [], ['alignment' => 'right']);
        }
        $devTable->addRow();
        $devTable->addCell(9000)->addText($sanitize('Total de horas'), ['bold' => true]);
        $devTable->addCell(2000)->addText($sanitize((string) ($quote->development_total_hours ?? 0)), ['bold' => true], ['alignment' => 'right']);
        $section->addTextBreak(1);

        $dev = (float) ($quote->price_development ?? 0);
        $packs = (float) ($quote->products_total ?? 0);
        $domainFirstYear = ($quote->include_domain ?? false)
            ? (float) ($quote->price_domain_first_year ?? 0)
            : 0;
        $domainOtherYears = ($quote->include_domain ?? false)
            ? (float) ($quote->price_domain_other_years ?? 0)
            : 0;
        $hostingFirstYear = ($quote->include_hosting ?? false)
            ? (float) ($quote->price_hosting_first_year ?? 0)
            : 0;
        $hostingOtherYears = ($quote->include_hosting ?? false)
            ? (float) ($quote->price_hosting_other_years ?? 0)
            : 0;
        $maintMonthly = (float) ($quote->price_maintenance_monthly ?? 0);
        $maintFixed = (float) ($quote->price_maintenance_fixed ?? 0);
        $baseTotal = $dev + $packs + $domainFirstYear + $hostingFirstYear;

        $valuesWrapper = $section->addTable($noBorderTable);
        $valuesWrapper->addRow(null, ['cantSplit' => true]);
        $valuesCell = $valuesWrapper->addCell(12000, ['borderSize' => 0, 'borderColor' => 'FFFFFF']);

        $valuesCell->addText($sanitize('Valores'), $title2);
        $valueTable = $valuesCell->addTable($tableStyle);
        $valueTable->addRow();
        $valueTable->addCell(9000, ['bgColor' => 'FFFFFF'])->addText($sanitize('Desenvolvimento'));
        $valueTable->addCell(2000, ['bgColor' => 'FFFFFF'])->addText($sanitize($money($dev)), [], ['alignment' => 'right']);
        if ($packs > 0) {
            $valueTable->addRow();
            $valueTable->addCell(9000)->addText($sanitize('Produtos / Packs'));
            $valueTable->addCell(2000)->addText($sanitize($money($packs)), [], ['alignment' => 'right']);
        }
        if ($quote->include_domain) {
            $valueTable->addRow();
            $valueTable->addCell(9000)->addText($sanitize('Domínio (1º ano)'));
            $valueTable->addCell(2000)->addText($sanitize($money($domainFirstYear)), [], ['alignment' => 'right']);
            $valueTable->addRow();
            $valueTable->addCell(9000)->addText($sanitize('Domínio (anos seguintes)'));
            $valueTable->addCell(2000)->addText($sanitize($money($domainOtherYears)), [], ['alignment' => 'right']);
        }
        if ($quote->include_hosting) {
            $valueTable->addRow();
            $valueTable->addCell(9000)->addText($sanitize('Alojamento (1º ano)'));
            $valueTable->addCell(2000)->addText($sanitize($money($hostingFirstYear)), [], ['alignment' => 'right']);
            $valueTable->addRow();
            $valueTable->addCell(9000)->addText($sanitize('Alojamento (anos seguintes)'));
            $valueTable->addCell(2000)->addText($sanitize($money($hostingOtherYears)), [], ['alignment' => 'right']);
        }
        if ($maintFixed > 0) {
            $valueTable->addRow();
            $valueTable->addCell(9000)->addText($sanitize('Manutenção fixa'));
            $valueTable->addCell(2000)->addText($sanitize($money($maintFixed)), [], ['alignment' => 'right']);
        }
        if ($maintMonthly > 0) {
            $valueTable->addRow();
            $valueTable->addCell(9000)->addText($sanitize('Manutenção mensal (opcional)'));
            $valueTable->addCell(2000)->addText($sanitize($money($maintMonthly)), [], ['alignment' => 'right']);
        }
        $valueTable->addRow();
        $valueTable->addCell(9000, ['bgColor' => $lightBg])->addText($sanitize('Total'), ['bold' => true]);
        $valueTable->addCell(2000, ['bgColor' => $lightBg])->addText($sanitize($money($baseTotal)), ['bold' => true], ['alignment' => 'right']);
        $section->addTextBreak(1);

        if (!empty($quote->terms)) {
            $section->addTitle($sanitize('Prazos e Condições'), 2);
            foreach (preg_split("/\\r\\n|\\r|\\n/", $quote->terms) as $line) {
                $section->addText($sanitize($line), [], $paraJust);
            }
            $section->addTextBreak(1);
        }

        if ($quote->quoteProducts && $quote->quoteProducts->count()) {
            $section->addTitle($sanitize('Produtos / Packs Recomendados'), 2);
            foreach ($quote->quoteProducts as $qp) {
                $section->addText($sanitize(($qp->name ?? 'Produto') . ' (' . strtoupper($qp->type ?? '') . ')'), ['bold' => true], $paraJust);
                if ($qp->type === 'pack' && is_array($qp->pack_items)) {
                    $packTable = $section->addTable($tableStyle);
                    $packTable->addRow();
                    $packTable->addCell(2000, ['bgColor' => $brand])->addText($sanitize('Horas'), ['bold' => true, 'color' => 'FFFFFF']);
                    $packTable->addCell(3500, ['bgColor' => $brand])->addText($sanitize('Preço normal'), ['bold' => true, 'color' => 'FFFFFF']);
                    $packTable->addCell(3000, ['bgColor' => $brand])->addText($sanitize('Preço pack'), ['bold' => true, 'color' => 'FFFFFF']);
                    $packTable->addCell(2500, ['bgColor' => $brand])->addText($sanitize('Validade'), ['bold' => true, 'color' => 'FFFFFF']);
                    foreach ($qp->pack_items as $item) {
                        $packTable->addRow();
                        $packTable->addCell(2000)->addText($sanitize(($item['hours'] ?? 0) . 'h'));
                        $packTable->addCell(3500)->addText($sanitize($money($item['normal_price'] ?? 0)), [], ['alignment' => 'right']);
                        $packTable->addCell(3000)->addText($sanitize($money($item['pack_price'] ?? 0)), [], ['alignment' => 'right']);
                        $packTable->addCell(2500)->addText($sanitize(($item['validity_months'] ?? 0) . ' meses'));
                    }
                }
                if (is_array($qp->info_fields) && count($qp->info_fields)) {
                    $section->addText($sanitize('Informação adicional'), ['bold' => true]);
                    foreach ($qp->info_fields as $field) {
                        $label = $field['label'] ?? '';
                        $value = $field['value'] ?? '';
                        $section->addText($sanitize(trim($label . ': ' . $value)), [], $paraJust);
                    }
                }
                $section->addTextBreak(1);
            }
        }

        if (!empty($company)) {
            // Keep the whole payment block together on the same page
            $paymentTable = $section->addTable($noBorderTable);
            $paymentTable->addRow(null, ['cantSplit' => true]);
            $paymentCell = $paymentTable->addCell(12000, ['borderSize' => 0, 'borderColor' => 'FFFFFF']);

            $paymentCell->addText($sanitize('Dados para pagamento'), $title2);

            if (!empty($company['email'])) $paymentCell->addText($sanitize('Email: ' . $company['email']), [], $paraJust);
            if (!empty($company['phone'])) $paymentCell->addText($sanitize('Telefone: ' . $company['phone']), [], $paraJust);
            if (!empty($company['website'])) $paymentCell->addText($sanitize($company['website']), [], $paraJust);
            if (!empty($company['payment_methods']) && is_array($company['payment_methods'])) {
                $paymentCell->addText($sanitize('Metodos:'), ['bold' => true], $paraJust);
                foreach ($company['payment_methods'] as $method) {
                    if (!empty($method['label']) || !empty($method['value'])) {
                        $paymentCell->addText($sanitize(($method['label'] ?? 'Metodo') . ': ' . ($method['value'] ?? '')), [], $paraJust);
                    }
                }
            }
            if (!empty($company['payment_notes'])) {
                foreach (preg_split("/\\r\\n|\\r|\\n/", $company['payment_notes']) as $line) {
                    $paymentCell->addText($sanitize($line), [], $paraJust);
                }
            }
            if (!empty($company['iban'])) $paymentCell->addText($sanitize('IBAN: ' . $company['iban']), [], $paraJust);
            if (!empty($company['bank_name'])) $paymentCell->addText($sanitize('Banco: ' . $company['bank_name']), [], $paraJust);
            if (!empty($company['swift'])) $paymentCell->addText($sanitize('SWIFT/BIC: ' . $company['swift']), [], $paraJust);
        }

        $filename = "Orcamento-{$quote->id}.docx";

        return response()->streamDownload(function () use ($phpWord) {
            $writer = IOFactory::createWriter($phpWord, 'Word2007');
            $writer->save('php://output');
        }, $filename, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ]);
    }

    public function partnerDocx(Quote $quote)
    {
        $quote->load(['project.client', 'quoteProducts']);

        $project = $quote->project;
        $client = $project?->client;
        $templatePath = base_path('docs/orc-site-template.docx');
        $tmpDir = storage_path('app/tmp');
        if (!is_dir($tmpDir)) {
            mkdir($tmpDir, 0755, true);
        }
        $tmpTemplate = $tmpDir . '/partner-template-' . $quote->id . '.docx';
        copy($templatePath, $tmpTemplate);

        $zip = new \ZipArchive();
        if ($zip->open($tmpTemplate) === true) {
            $xml = $zip->getFromName('word/document.xml');
            $numberingXml = $zip->getFromName('word/numbering.xml');
            $bulletNumId = $this->findBulletNumId($numberingXml);
            $headerXml = $zip->getFromName('word/header1.xml');
            if ($headerXml) {
                $headerXml = $this->normalizePartnerHeader($headerXml);
                $zip->addFromString('word/header1.xml', $headerXml);
            }
            if ($xml !== false) {
                $planLines = [];
                foreach (($quote->development_items ?? []) as $item) {
                    $feature = trim((string) ($item['feature'] ?? ''));
                    if ($feature !== '') {
                        $planLines[] = $feature;
                    }
                }

                $values = [];
                $dev = (float) ($quote->price_development ?? 0);
                if ($dev > 0) $values[] = 'Desenvolvimento: ' . $this->formatMoneyPt($dev);
                if ($quote->include_domain) {
                    $values[] = 'Domínio (anual): ' . $this->formatMoneyPt((float) ($quote->price_domain_first_year ?? 0));
                }
                if ($quote->include_hosting) {
                    $values[] = 'Alojamento (1º ano): ' . $this->formatMoneyPt((float) ($quote->price_hosting_first_year ?? 0));
                    $values[] = 'Alojamento (anos seguintes): ' . $this->formatMoneyPt((float) ($quote->price_hosting_other_years ?? 0));
                }

                $payload = [
                    'quote_title' => 'ORÇAMENTO ' . ($project->name ?? ''),
                    'project_type_line' => 'DESENVOLVIMENTO ' . mb_strtoupper((string) ($quote->project_type ?? '')),
                    'quote_date' => $this->formatDatePt($quote->created_at ?? now()),
                    'description' => $this->splitToParagraphs($quote->description ?? ''),
                    'development_plan' => $planLines,
                    'values' => $values,
                    'terms' => $this->splitToListItems($quote->terms ?? ''),
                ];

                $xml = $this->applyPartnerTemplateData($xml, $payload, $bulletNumId);
                $zip->addFromString('word/document.xml', $xml);
            }
            $zip->close();
        }

        $filename = "Orcamento-Parceiro-{$quote->id}.docx";

        return response()->download($tmpTemplate, $filename, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ])->deleteFileAfterSend(true);
    }

    private function applyPartnerTemplateData(string $xml, array $data, ?string $bulletNumId): string
    {
        $dom = new \DOMDocument();
        $dom->preserveWhiteSpace = true;
        $dom->formatOutput = false;
        $dom->loadXML($xml);

        $xpath = new \DOMXPath($dom);
        $xpath->registerNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main');

        $this->applyLineHeightToAllParagraphs($xpath);
        $this->normalizeFirstBodyParagraphSpacing($xpath);
        $this->removeLeadingEmptyParagraphs($xpath);

        $textNodes = $xpath->query('//w:t');
        $nodes = [];
        foreach ($textNodes as $node) {
            $nodes[] = $node;
        }

        $this->replaceExactText($nodes, 'ORÇAMENTO GLAMMY AESTHETIC', $data['quote_title'] ?? '');
        $this->replaceExactText($nodes, 'DESENVOLVIMENTO WEBSITE', $data['project_type_line'] ?? '');

        $datePattern = '/\\d{1,2} de [A-Za-zçÇãõáéíóúÁÉÍÓÚ]+ de \\d{4}/u';
        $dateReplaced = false;
        foreach ($nodes as $node) {
            if (trim($node->nodeValue) === 'Data:') {
                $node->nodeValue = 'Data: ' . ($data['quote_date'] ?? '');
                $dateReplaced = true;
                break;
            }
        }
        foreach ($nodes as $node) {
            if (preg_match($datePattern, trim($node->nodeValue))) {
                $node->nodeValue = $dateReplaced ? '' : ($data['quote_date'] ?? '');
                $dateReplaced = true;
            }
        }

        $listPPr = $this->findListParagraphPr($xpath, $bulletNumId);

        $this->replaceSectionBetweenHeadingsWithParagraphs($xpath, 'DESCRIÇÃO', 'Plano de Desenvolvimento', $data['description'] ?? [], false, $listPPr);
        $this->replaceSectionBetweenHeadingsWithParagraphs($xpath, 'Plano de Desenvolvimento', 'VALORES', $data['development_plan'] ?? [], true, $listPPr);
        $this->replaceSectionBetweenHeadingsWithParagraphs($xpath, 'VALORES', 'PRAZOS', $data['values'] ?? [], true, $listPPr);
        $this->replaceSectionAfterHeadingWithParagraphs($xpath, 'PRAZOS', $data['terms'] ?? [], true, $listPPr);

        return $dom->saveXML();
    }

    private function applyLineHeightToAllParagraphs(\DOMXPath $xpath): void
    {
        $paragraphs = $xpath->query('//w:p');
        foreach ($paragraphs as $p) {
            $pPr = $xpath->query('w:pPr', $p)->item(0);
            if (!$pPr) {
                $pPr = $p->ownerDocument->createElementNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:pPr');
                $p->insertBefore($pPr, $p->firstChild);
            }
            $this->applyLineHeight($pPr);
        }
    }


    private function normalizeFirstBodyParagraphSpacing(\DOMXPath $xpath): void
    {
        $body = $xpath->query('//w:body')->item(0);
        if (!$body) {
            return;
        }
        $firstP = null;
        foreach ($body->childNodes as $child) {
            if ($child instanceof \DOMElement && $child->localName === 'p') {
                $firstP = $child;
                break;
            }
        }
        if (!$firstP) {
            return;
        }
        $pPr = $xpath->query('w:pPr', $firstP)->item(0);
        if (!$pPr) {
            $pPr = $firstP->ownerDocument->createElementNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:pPr');
            $firstP->insertBefore($pPr, $firstP->firstChild);
        }
        $spacing = $xpath->query('w:spacing', $pPr)->item(0);
        if (!$spacing) {
            $spacing = $firstP->ownerDocument->createElementNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:spacing');
            $pPr->appendChild($spacing);
        }
        $spacing->setAttributeNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:before', '0');
        $spacing->setAttributeNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:after', '120');
    }

    private function removeLeadingEmptyParagraphs(\DOMXPath $xpath): void
    {
        $body = $xpath->query('//w:body')->item(0);
        if (!$body) {
            return;
        }

        foreach (iterator_to_array($body->childNodes) as $child) {
            if (!($child instanceof \DOMElement) || $child->localName !== 'p') {
                continue;
            }
            $texts = $xpath->query('.//w:t', $child);
            $hasText = false;
            foreach ($texts as $t) {
                if (trim($t->nodeValue) !== '') {
                    $hasText = true;
                    break;
                }
            }
            if ($hasText) {
                break;
            }
            $body->removeChild($child);
        }
    }

    private function normalizePartnerHeader(string $xml): string
    {
        $dom = new \DOMDocument();
        $dom->preserveWhiteSpace = true;
        $dom->formatOutput = false;
        if (!@$dom->loadXML($xml)) {
            return $xml;
        }

        $xpath = new \DOMXPath($dom);
        $xpath->registerNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
        $xpath->registerNamespace('wp', 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing');
        $xpath->registerNamespace('a', 'http://schemas.openxmlformats.org/drawingml/2006/main');

        // Convert floating anchor to inline so text starts after the logo, and center it.
        $anchors = $xpath->query('//wp:anchor');
        foreach ($anchors as $anchor) {
            $inline = $dom->createElementNS('http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing', 'wp:inline');

            foreach (['distT','distB','distL','distR'] as $attr) {
                if ($anchor->hasAttribute($attr)) {
                    $inline->setAttribute($attr, $anchor->getAttribute($attr));
                }
            }

            foreach (['extent','effectExtent','docPr','cNvGraphicFramePr','graphic'] as $childName) {
                $node = null;
                foreach ($anchor->childNodes as $child) {
                    if ($child instanceof \DOMElement && $child->localName === $childName) {
                        $node = $child->cloneNode(true);
                        break;
                    }
                }
                if ($node) {
                    $inline->appendChild($node);
                }
            }

            $anchor->parentNode->replaceChild($inline, $anchor);
        }

        // Center the paragraph that contains the logo
        $logoParagraphs = $xpath->query('//w:p[w:r/w:drawing]');
        foreach ($logoParagraphs as $p) {
            $pPr = $xpath->query('w:pPr', $p)->item(0);
            if (!$pPr) {
                $pPr = $dom->createElementNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:pPr');
                $p->insertBefore($pPr, $p->firstChild);
            }
            $jc = $xpath->query('w:jc', $pPr)->item(0);
            if (!$jc) {
                $jc = $dom->createElementNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:jc');
                $pPr->appendChild($jc);
            }
            $jc->setAttributeNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:val', 'center');

            $spacing = $xpath->query('w:spacing', $pPr)->item(0);
            if (!$spacing) {
                $spacing = $dom->createElementNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:spacing');
                $pPr->appendChild($spacing);
            }
            $spacing->setAttributeNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:before', '0');
            $spacing->setAttributeNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:after', '0');
        }

        // Reduce header paragraph line height to shrink header block height.
        foreach ($logoParagraphs as $p) {
            $pPr = $xpath->query('w:pPr', $p)->item(0);
            if ($pPr) {
                $spacing = $xpath->query('w:spacing', $pPr)->item(0);
                if (!$spacing) {
                    $spacing = $dom->createElementNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:spacing');
                    $pPr->appendChild($spacing);
                }
                $spacing->setAttributeNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:line', '200');
                $spacing->setAttributeNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:lineRule', 'auto');
            }
        }

        return $dom->saveXML();
    }


    private function replaceExactText(array $nodes, string $find, string $replace): void
    {
        foreach ($nodes as $node) {
            if (trim($node->nodeValue) === $find) {
                $node->nodeValue = $replace;
                return;
            }
        }
    }

    private function findListParagraphPr(\DOMXPath $xpath, ?string $bulletNumId): ?\DOMElement
    {
        $listP = $xpath->query('//w:p[w:pPr/w:numPr]')->item(0);
        if (!$listP) {
            return null;
        }
        $pPr = $xpath->query('w:pPr', $listP)->item(0);
        if (!$pPr) {
            return null;
        }
        $clone = $pPr->cloneNode(true);
        if ($bulletNumId !== null) {
            $numId = $clone->getElementsByTagNameNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'numId')->item(0);
            if ($numId) {
                $numId->setAttributeNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:val', $bulletNumId);
            }
        }
        return $clone;
    }

    private function replaceSectionBetweenHeadingsWithParagraphs(\DOMXPath $xpath, string $startHeading, string $endHeading, array $lines, bool $listStyle, ?\DOMElement $listPPr): void
    {
        $startP = $xpath->query("//w:p[w:r/w:t[normalize-space(.)='$startHeading']]")->item(0);
        $endP = $xpath->query("//w:p[w:r/w:t[normalize-space(.)='$endHeading']]")->item(0);
        if (!$startP || !$endP) {
            return;
        }

        $doc = $startP->ownerDocument;
        $current = $startP->nextSibling;
        $stylePPr = null;
        while ($current && $current !== $endP) {
            $next = $current->nextSibling;
            if ($current->nodeName === 'w:p') {
                if (!$stylePPr) {
                    $pPr = $xpath->query('w:pPr', $current)->item(0);
                    if ($pPr) {
                        $stylePPr = $pPr->cloneNode(true);
                    }
                }
                $current->parentNode->removeChild($current);
            }
            $current = $next;
        }

        if ($listStyle && $listPPr) {
            $stylePPr = $listPPr->cloneNode(true);
        }

        foreach ($lines as $line) {
            $line = trim((string) $line);
            if ($line === '') continue;

            $p = $doc->createElementNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:p');
            if ($stylePPr) {
                $pPr = $stylePPr->cloneNode(true);
                if (!$listStyle) {
                    $numPr = $pPr->getElementsByTagNameNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'numPr')->item(0);
                    if ($numPr && $numPr->parentNode) {
                        $numPr->parentNode->removeChild($numPr);
                    }
                } else {
                    $this->applyBulletIndent($pPr);
                }
                $this->applyLineHeight($pPr);
                $p->appendChild($pPr);
            }
            $r = $doc->createElementNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:r');
            $t = $doc->createElementNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:t');
            $t->appendChild($doc->createTextNode($line));
            $r->appendChild($t);
            $p->appendChild($r);
            $endP->parentNode->insertBefore($p, $endP);
        }
    }

    private function replaceSectionAfterHeadingWithParagraphs(\DOMXPath $xpath, string $startHeading, array $lines, bool $listStyle, ?\DOMElement $listPPr): void
    {
        $startP = $xpath->query("//w:p[w:r/w:t[normalize-space(.)='$startHeading']]")->item(0);
        if (!$startP) {
            return;
        }

        $doc = $startP->ownerDocument;
        $current = $startP->nextSibling;
        $stylePPr = null;
        while ($current) {
            $next = $current->nextSibling;
            if ($current->nodeName === 'w:p') {
                if (!$stylePPr) {
                    $pPr = $xpath->query('w:pPr', $current)->item(0);
                    if ($pPr) {
                        $stylePPr = $pPr->cloneNode(true);
                    }
                }
                $current->parentNode->removeChild($current);
            }
            $current = $next;
        }

        if ($listStyle && $listPPr) {
            $stylePPr = $listPPr->cloneNode(true);
        }

        foreach ($lines as $line) {
            $line = trim((string) $line);
            if ($line === '') continue;

            $p = $doc->createElementNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:p');
            if ($stylePPr) {
                $pPr = $stylePPr->cloneNode(true);
                if (!$listStyle) {
                    $numPr = $pPr->getElementsByTagNameNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'numPr')->item(0);
                    if ($numPr && $numPr->parentNode) {
                        $numPr->parentNode->removeChild($numPr);
                    }
                } else {
                    $this->applyBulletIndent($pPr);
                }
                $this->applyLineHeight($pPr);
                $p->appendChild($pPr);
            }
            $r = $doc->createElementNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:r');
            $t = $doc->createElementNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:t');
            $t->appendChild($doc->createTextNode($line));
            $r->appendChild($t);
            $p->appendChild($r);
            $startP->parentNode->appendChild($p);
        }
    }

    private function splitToParagraphs(string $text): array
    {
        $text = $this->normalizeTextFromHtml($text);
        $lines = preg_split("/\\r\\n|\\r|\\n/", $text);
        $out = [];
        foreach ($lines as $line) {
            $line = trim($line);
            if ($line !== '') {
                $out[] = $line;
            }
        }
        return $out;
    }

    private function normalizeTextFromHtml(string $text): string
    {
        if (!preg_match('/<\\s*[\\w-]+[^>]*>/', $text)) {
            return $text;
        }

        $normalized = preg_replace('/<\\s*br\\s*\\/?\\s*>/i', "\n", $text);
        $normalized = preg_replace('/<\\s*\\/p\\s*>/i', "\n", $normalized);
        $normalized = preg_replace('/<\\s*\\/li\\s*>/i', "\n", $normalized);
        $normalized = preg_replace('/<\\s*li[^>]*>/i', "• ", $normalized);
        $normalized = strip_tags($normalized);
        $normalized = html_entity_decode($normalized, ENT_QUOTES | ENT_HTML5, 'UTF-8');

        return $normalized;
    }

    private function splitToListItems(string $text): array
    {
        $lines = preg_split("/\\r\\n|\\r|\\n/", $text);
        $out = [];
        foreach ($lines as $line) {
            $line = trim($line);
            if ($line === '') continue;
            $line = preg_replace('/^(•|\\-|\\*|–|—)\\s*/u', '', $line);
            $out[] = $line;
        }
        return $out;
    }

    private function findBulletNumId(?string $numberingXml): ?string
    {
        if (!$numberingXml) {
            return null;
        }

        $dom = new \DOMDocument();
        if (!@$dom->loadXML($numberingXml)) {
            return null;
        }

        $xpath = new \DOMXPath($dom);
        $xpath->registerNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main');

        $abstracts = [];
        foreach ($xpath->query('//w:abstractNum') as $abstract) {
            $id = $abstract->getAttribute('w:abstractNumId');
            $numFmt = $xpath->query('.//w:numFmt', $abstract)->item(0);
            if ($numFmt && $numFmt->getAttribute('w:val') === 'bullet') {
                $abstracts[] = $id;
            }
        }

        if (!$abstracts) {
            return null;
        }

        foreach ($xpath->query('//w:num') as $num) {
            $abstractId = $xpath->query('w:abstractNumId', $num)->item(0);
            if (!$abstractId) {
                continue;
            }
            $abs = $abstractId->getAttribute('w:val');
            if (in_array($abs, $abstracts, true)) {
                return $num->getAttribute('w:numId');
            }
        }

        return null;
    }

    private function applyBulletIndent(\DOMElement $pPr): void
    {
        $doc = $pPr->ownerDocument;
        $ind = null;
        foreach ($pPr->childNodes as $child) {
            if ($child instanceof \DOMElement && $child->localName === 'ind') {
                $ind = $child;
                break;
            }
        }
        if (!$ind) {
            $ind = $doc->createElementNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:ind');
            $pPr->appendChild($ind);
        }
        // Align bullets closer to left margin and align text
        $ind->setAttributeNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:left', '360');
        $ind->setAttributeNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:hanging', '180');
    }

    private function applyLineHeight(\DOMElement $pPr): void
    {
        $doc = $pPr->ownerDocument;
        $spacing = null;
        foreach ($pPr->childNodes as $child) {
            if ($child instanceof \DOMElement && $child->localName === 'spacing') {
                $spacing = $child;
                break;
            }
        }
        if (!$spacing) {
            $spacing = $doc->createElementNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:spacing');
            $pPr->appendChild($spacing);
        }
        // 1.5 line spacing -> 360 twips
        $spacing->setAttributeNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:line', '360');
        $spacing->setAttributeNS('http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'w:lineRule', 'auto');
    }

    private function formatMoneyPt(float $value): string
    {
        return number_format($value, 2, ',', '.') . ' €';
    }

    private function formatDatePt($date): string
    {
        try {
            return $date->locale('pt')->translatedFormat('j \\de F \\de Y');
        } catch (\Throwable $e) {
            return now()->locale('pt')->translatedFormat('j \\de F \\de Y');
        }
    }

    // ---------------------------
    //   LINKS PÚBLICOS
    // ---------------------------

    public function publicView(string $token)
    {
        $quote = Quote::where('public_token', $token)
            ->with('project.client')
            ->firstOrFail();

        return Inertia::render('Quotes/ShowPublic', [
            'quote' => $quote,
        ]);
    }

    public function publicPdf(string $token)
    {
        $quote = Quote::where('public_token', $token)
            ->with('project.client')
            ->firstOrFail();

        return $this->generatePdf($quote);
    }

    // ---------------------------
    //   PDF (interno e público)
    // ---------------------------

    private function generatePdf(Quote $quote)
    {
        $quote->load('project.client');

        $pdf = Pdf::loadView('pdf.quote', [
            'quote' => $quote,
            'project' => $quote->project,
            'client' => $quote->project->client,
            'company' => CompanySettings::get(),
        ])->setPaper('a4', 'portrait');

        return $pdf->stream("Orcamento-{$quote->id}.pdf");
    }
}
