<?php

namespace App\Http\Controllers;

use App\Models\Ride;
use Illuminate\Http\Request;

abstract class Controller
{
    protected function authorizeRideDriver(Request $request, Ride $ride): void
    {
        abort_if($ride->driver_id !== $request->user()->id, 403, 'Somente o motorista da carona pode executar esta ação.');
    }
}
