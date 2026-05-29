<?php

namespace App\Http\Controllers;

use App\Models\Example;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class ExampleController extends Controller
{
    public function index(): JsonResponse
    {
        return response()->json([
            'data' => Example::query()->paginate(15),
        ]);
    }

    public function show(Example $example): JsonResponse
    {
        return response()->json(['data' => $example]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
        ]);
        $example = Example::create($validated);
        return response()->json(['data' => $example], 201);
    }
}
