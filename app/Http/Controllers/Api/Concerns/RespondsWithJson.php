<?php

namespace App\Http\Controllers\Api\Concerns;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Pagination\AbstractPaginator;

trait RespondsWithJson
{
    protected function success(array $data = [], ?string $message = null, int $status = 200): JsonResponse
    {
        return response()->json([
            'message' => $message,
            'data' => $data,
        ], $status);
    }

    protected function error(string $message, array $errors = [], int $status = 422): JsonResponse
    {
        return response()->json([
            'message' => $message,
            'errors' => $errors,
        ], $status);
    }

    protected function paginated(
        Request $request,
        AbstractPaginator $paginator,
        array $data,
        ?string $message = null,
        array $extra = []
    ): JsonResponse {
        return response()->json([
            'message' => $message,
            'data' => $data,
            'meta' => array_merge([
                'current_page' => $paginator->currentPage(),
                'from' => $paginator->firstItem(),
                'last_page' => $paginator->lastPage(),
                'path' => $paginator->path(),
                'per_page' => $paginator->perPage(),
                'to' => $paginator->lastItem(),
                'total' => $paginator->total(),
            ], $extra),
        ]);
    }
}
