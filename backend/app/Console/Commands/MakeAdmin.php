<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

/**
 * Promove usuários a administrador pelo e-mail.
 * Sem argumento, usa ADMIN_EMAILS (lista separada por vírgula), executado no start do container.
 * Não rebaixa ninguém: remover um e-mail da lista não retira o papel de admin.
 */
#[Signature('users:make-admin {email? : E-mail do usuário (padrão: ADMIN_EMAILS)}')]
#[Description('Promove usuários a administrador')]
class MakeAdmin extends Command
{
    public function handle(): int
    {
        $emails = $this->argument('email')
            ? [$this->argument('email')]
            : config('urimove.admin_emails');

        if ($emails === []) {
            $this->line('Nenhum e-mail informado (ADMIN_EMAILS vazio).');

            return self::SUCCESS;
        }

        foreach ($emails as $email) {
            $user = User::whereRaw('lower(email) = ?', [mb_strtolower($email)])->first();

            if (! $user) {
                // Não revela no log se o e-mail existe ou não além do necessário para o operador.
                $this->warn("Usuário não encontrado: {$email}");

                continue;
            }

            if (! $user->isAdmin()) {
                $user->forceFill(['role' => User::ROLE_ADMIN])->save();
            }

            $this->info("Administrador: {$email}");
        }

        return self::SUCCESS;
    }
}
