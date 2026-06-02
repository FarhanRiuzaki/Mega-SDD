<?php
// import_request.php — 2-step maker->checker import LC request wizard.
$step = $_POST['step'] ?? '1';
if ($step == '1') {
    // Stage 1 (Maker) collects the LC details, then advances to step 2.
    $lc_number   = $_POST['lc_number'];
    $amount      = $_POST['amount'];
    $beneficiary = $_POST['beneficiary'];
    echo '<form method="post"><input type="hidden" name="step" value="2"></form>';
} elseif ($step == '2') {
    // Stage 2 (Checker) reviews and decides.
    $approval_note = $_POST['approval_note'];
    $decision      = $_POST['decision'];
    $checked_at    = date('Y-m-d');   // computed, NOT a request field
    echo '<form method="post" action="finalize.php"></form>';
}
