# ── Test transactions microservicio ──────────────────────────────────────────
# Ejecutar con: .\test-transactions.ps1
# Requisitos: docker compose up -d  +  npm run start:dev accounts  +  npm run start:dev transactions

$base = "http://localhost:3000"

function Write-Section($title) {
    Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
}

function Invoke-Api($method, $path, $body = $null) {
    $params = @{
        Method      = $method
        Uri         = "$base$path"
        ContentType = "application/json"
        ErrorAction = "Stop"
    }
    if ($body) { $params.Body = ($body | ConvertTo-Json) }
    try {
        Invoke-RestMethod @params
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        $msg    = $_.ErrorDetails.Message
        Write-Host "  HTTP $status — $msg" -ForegroundColor Red
        return $null
    }
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Section "1. Crear cuentas de prueba"

$cuentaA = Invoke-Api POST "/accounts" @{ owner = "Alice"; balance = 500 }
$cuentaB = Invoke-Api POST "/accounts" @{ owner = "Bob";   balance = 100 }

if (-not $cuentaA -or -not $cuentaB) {
    Write-Host "Error creando cuentas. ¿Está corriendo accounts?" -ForegroundColor Red
    exit 1
}

Write-Host "  Cuenta Alice → ID: $($cuentaA.id)  Saldo: `$$($cuentaA.balance)" -ForegroundColor Green
Write-Host "  Cuenta Bob   → ID: $($cuentaB.id)  Saldo: `$$($cuentaB.balance)" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
Write-Section "2. Transferencia válida (Alice → Bob, `$200)"

$r = Invoke-Api POST "/accounts/transfer" @{
    fromAccountId = $cuentaA.id
    toAccountId   = $cuentaB.id
    amount        = 200
}
Write-Host "  Respuesta: $($r | ConvertTo-Json -Compress)" -ForegroundColor Yellow
Write-Host "  Esperando que transactions procese el evento..." -ForegroundColor DarkGray
Start-Sleep -Seconds 2

$a = Invoke-Api GET "/accounts/$($cuentaA.id)"
$b = Invoke-Api GET "/accounts/$($cuentaB.id)"
Write-Host "  Alice saldo actual: `$$($a.balance)  (esperado: `$300)" -ForegroundColor $(if ($a.balance -eq 300) { "Green" } else { "Red" })
Write-Host "  Bob   saldo actual: `$$($b.balance)  (esperado: `$300)" -ForegroundColor $(if ($b.balance -eq 300) { "Green" } else { "Red" })

# ─────────────────────────────────────────────────────────────────────────────
Write-Section "3. Transferencia con saldo insuficiente (Alice intenta enviar `$400)"

$r2 = Invoke-Api POST "/accounts/transfer" @{
    fromAccountId = $cuentaA.id
    toAccountId   = $cuentaB.id
    amount        = 400
}
Write-Host "  Respuesta: $($r2 | ConvertTo-Json -Compress)" -ForegroundColor Yellow
Start-Sleep -Seconds 2

$a2 = Invoke-Api GET "/accounts/$($cuentaA.id)"
Write-Host "  Alice saldo (debe mantenerse en `$300): `$$($a2.balance)" -ForegroundColor $(if ($a2.balance -eq 300) { "Green" } else { "Red" })
Write-Host "  (Revisa logs de transactions: debe aparecer RECHAZADA: Saldo insuficiente)" -ForegroundColor DarkGray

# ─────────────────────────────────────────────────────────────────────────────
Write-Section "4. Transferencia con cuenta inexistente"

$r3 = Invoke-Api POST "/accounts/transfer" @{
    fromAccountId = $cuentaA.id
    toAccountId   = "00000000-0000-0000-0000-000000000000"
    amount        = 10
}
Write-Host "  Respuesta: $($r3 | ConvertTo-Json -Compress)" -ForegroundColor Yellow
Start-Sleep -Seconds 2
Write-Host "  (Revisa logs de transactions: debe aparecer RECHAZADA: Cuenta de destino no encontrada)" -ForegroundColor DarkGray

# ─────────────────────────────────────────────────────────────────────────────
Write-Section "5. Estado final de cuentas"

$final_a = Invoke-Api GET "/accounts/$($cuentaA.id)"
$final_b = Invoke-Api GET "/accounts/$($cuentaB.id)"
Write-Host "  Alice: `$$($final_a.balance)" -ForegroundColor White
Write-Host "  Bob:   `$$($final_b.balance)" -ForegroundColor White

Write-Host "`n✓ Script finalizado. Revisa los logs de transactions para ver transfer.completed / transfer.failed`n" -ForegroundColor Cyan
