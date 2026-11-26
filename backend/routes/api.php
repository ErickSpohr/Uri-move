<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BlockController;
use App\Http\Controllers\Api\CampusController;
use App\Http\Controllers\Api\ChatUnreadController;
use App\Http\Controllers\Api\CourseController;
use App\Http\Controllers\Api\DeviceTokenController;
use App\Http\Controllers\Api\FavoriteRouteController;
use App\Http\Controllers\Api\MessageController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\PasswordResetController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\PushSubscriptionController;
use App\Http\Controllers\Api\RatingController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\RideChatController;
use App\Http\Controllers\Api\RideController;
use App\Http\Controllers\Api\RideLocationController;
use App\Http\Controllers\Api\RideRequestController;
use App\Http\Controllers\Api\VehicleController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {

    // ------------------------- Autenticação -------------------------
    Route::prefix('auth')->group(function () {
        Route::post('/forgot-password', [PasswordResetController::class, 'forgot'])->middleware('throttle:3,1');
        Route::post('/reset-password', [PasswordResetController::class, 'reset'])->middleware('throttle:6,1');
        Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:send-code');
        Route::post('/verify-email', [AuthController::class, 'verifyEmail'])->middleware('throttle:verify-email');
        Route::post('/resend-code', [AuthController::class, 'resendCode'])->middleware('throttle:send-code');
        Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:login');
        Route::post('/logout', [AuthController::class, 'logout'])->middleware('auth:sanctum');
    });

    // ------------------------- Dados públicos -------------------------
    Route::get('/campuses', [CampusController::class, 'index']);
    Route::get('/courses', [CourseController::class, 'index']);
    Route::get('/rides', [RideController::class, 'index']);
    Route::get('/users/{user}', [ProfileController::class, 'show']);
    Route::get('/users/{user}/photo', [ProfileController::class, 'photo']);

    // ------------------------- Rotas autenticadas -------------------------
    Route::middleware('auth:sanctum')->group(function () {

        // Perfil
        Route::get('/me', [ProfileController::class, 'me']);
        Route::put('/me', [ProfileController::class, 'update']);
        Route::get('/me/rides', [ProfileController::class, 'myRides']);
        Route::get('/me/rides/joined', [ProfileController::class, 'joinedRides']);
        Route::get('/me/requests', [ProfileController::class, 'myRequests']);

        // Veículos
        Route::get('/vehicles', [VehicleController::class, 'index']);
        Route::post('/vehicles', [VehicleController::class, 'store']);
        Route::put('/vehicles/{vehicle}', [VehicleController::class, 'update']);
        Route::delete('/vehicles/{vehicle}', [VehicleController::class, 'destroy']);

        // Caronas
        Route::post('/rides', [RideController::class, 'store']);
        Route::get('/rides/{ride}', [RideController::class, 'show']);
        Route::post('/rides/{ride}/start', [RideController::class, 'start']);
        Route::post('/rides/{ride}/complete', [RideController::class, 'complete']);
        Route::post('/rides/{ride}/cancel', [RideController::class, 'cancel']);
        Route::get('/rides/{ride}/quote', [RideController::class, 'quote'])->middleware('throttle:30,1');
        Route::get('/rides/{ride}/location', [RideLocationController::class, 'show']);
        Route::put('/rides/{ride}/location', [RideLocationController::class, 'update'])->middleware('throttle:12,1');
        Route::delete('/rides/{ride}/location', [RideLocationController::class, 'destroy']);

        // Solicitações de carona
        Route::get('/rides/{ride}/requests', [RideRequestController::class, 'index']);
        Route::post('/rides/{ride}/requests', [RideRequestController::class, 'store']);
        Route::patch('/rides/{ride}/requests/{rideRequest}', [RideRequestController::class, 'respond']);
        Route::delete('/rides/{ride}/requests/{rideRequest}', [RideRequestController::class, 'destroy']);

        // Chat
        Route::get('/rides/{ride}/chat', [RideChatController::class, 'index']);
        Route::post('/rides/{ride}/chat', [RideChatController::class, 'store'])->middleware('throttle:60,1');
        Route::get('/rides/{ride}/messages', [MessageController::class, 'index']);
        Route::post('/rides/{ride}/messages', [MessageController::class, 'store']);
        Route::patch('/messages/{message}/read', [MessageController::class, 'markRead']);
        Route::get('/chats/unread', ChatUnreadController::class);

        // Avaliações
        Route::post('/ratings', [RatingController::class, 'store']);
        Route::get('/users/{user}/ratings', [RatingController::class, 'userRatings']);
        Route::get('/rides/{ride}/participants', [RatingController::class, 'participants']);

        // Denúncias
        Route::post('/reports', [ReportController::class, 'store']);
        Route::get('/reports/mine', [ReportController::class, 'mine']);

        // Notificações
        Route::get('/push/public-key', [PushSubscriptionController::class, 'publicKey']);
        Route::post('/push/subscriptions', [PushSubscriptionController::class, 'store'])->middleware('throttle:20,1');
        Route::delete('/push/subscriptions', [PushSubscriptionController::class, 'destroy']);
        Route::post('/push/devices', [DeviceTokenController::class, 'store'])->middleware('throttle:20,1');
        Route::delete('/push/devices', [DeviceTokenController::class, 'destroy']);
        Route::post('/push/devices/test', [DeviceTokenController::class, 'test'])->middleware('throttle:5,1');
        Route::get('/notifications', [NotificationController::class, 'index']);
        Route::get('/notifications/unread-count', [NotificationController::class, 'unreadCount']);
        Route::patch('/notifications/read-all', [NotificationController::class, 'markAllRead']);
        Route::patch('/notifications/{notification}/read', [NotificationController::class, 'markRead']);
        Route::delete('/notifications/{notification}', [NotificationController::class, 'destroy']);

        // Rotas favoritas
        Route::get('/favorite-routes', [FavoriteRouteController::class, 'index']);
        Route::post('/favorite-routes', [FavoriteRouteController::class, 'store']);
        Route::delete('/favorite-routes/{favoriteRoute}', [FavoriteRouteController::class, 'destroy']);

        // Bloqueios
        Route::get('/blocks', [BlockController::class, 'index']);
        Route::post('/blocks', [BlockController::class, 'store']);
        Route::delete('/blocks', [BlockController::class, 'destroy']);
    });

    // ------------------------- Administração -------------------------
    Route::middleware(['auth:sanctum', 'auth.admin'])->prefix('admin')->group(function () {
        Route::get('/reports', [ReportController::class, 'adminIndex']);
        Route::patch('/reports/{report}/status', [ReportController::class, 'updateStatus']);
    });
});
