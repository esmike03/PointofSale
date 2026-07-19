<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\Api\DeviceController;
use App\Http\Controllers\Api\SyncController;
use App\Http\Controllers\Api\InventoryController;
use App\Http\Controllers\Api\SupplierController;
use App\Http\Controllers\Api\ManagementController;
use App\Http\Controllers\Api\SalesController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn () => ['status' => 'ok', 'service' => 'pos-api']);
Route::middleware('throttle:10,1')->group(function () {
    Route::post('/auth/register', [AuthController::class, 'register']);
    Route::post('/auth/login', [AuthController::class, 'login']);
});

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);
    Route::get('/products', [ProductController::class, 'index']);
    Route::post('/products', [ProductController::class, 'store']);
    Route::post('/products/{productId}/archive', [ProductController::class, 'archive']);
    Route::post('/products/{productId}/restore', [ProductController::class, 'restore']);
    Route::get('/sales/receipt/{receiptNumber}', [SalesController::class, 'showByReceipt']);
    Route::post('/devices/register', [DeviceController::class, 'register']);
    Route::get('/suppliers', [SupplierController::class, 'index']);
    Route::post('/suppliers', [SupplierController::class, 'store']);
    Route::get('/management/users', [ManagementController::class, 'users']);
    Route::post('/management/users', [ManagementController::class, 'createUser']);
    Route::put('/management/users/{userId}', [ManagementController::class, 'updateUser']);
    Route::post('/management/users/{userId}/deactivate', [ManagementController::class, 'deactivateUser']);
    Route::post('/management/users/{userId}/reactivate', [ManagementController::class, 'reactivateUser']);
    Route::get('/management/audit-logs', [ManagementController::class, 'auditLogs']);
    Route::get('/inventory', [InventoryController::class, 'index']);
    Route::get('/inventory/movements', [InventoryController::class, 'movements']);
    Route::get('/inventory/low-stock', [InventoryController::class, 'lowStock']);
    Route::post('/inventory/receive', [InventoryController::class, 'receive']);
    Route::post('/inventory/adjust', [InventoryController::class, 'adjust']);
    Route::post('/inventory/transfer', [InventoryController::class, 'transfer']);
    Route::post('/inventory/count', [InventoryController::class, 'count']);
    Route::post('/sync/push', [SyncController::class, 'push']);
    Route::get('/sync/pull', [SyncController::class, 'pull']);
});
