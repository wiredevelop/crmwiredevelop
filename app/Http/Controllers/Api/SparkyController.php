<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\SparkyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SparkyController extends Controller
{
    public function ask(Request $request, SparkyService $sparky): JsonResponse
    {
        $validated = $request->validate([
            'question' => 'required|string|max:1000',
            'history' => 'array|max:20',
            'history.*.role' => 'required|in:user,assistant',
            'history.*.content' => 'required|string|max:2000',
        ]);

        try {
            $answer = $sparky->ask($validated['question'], $validated['history'] ?? [], $request->user());

            return response()->json(['answer' => $answer]);
        } catch (\RuntimeException $e) {
            return response()->json(['error' => $e->getMessage()], 502);
        }
    }
}
