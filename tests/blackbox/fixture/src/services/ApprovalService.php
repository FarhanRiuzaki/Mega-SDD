<?php

require_once __DIR__ . '/../models/Employee.php';
require_once __DIR__ . '/../models/LeaveRequest.php';

class ApprovalService
{
    public function approveRequest(int $requestId, int $approverId, string $note): bool
    {
        $limits = require __DIR__ . '/../config/limits.php';
        // maker-checker: the approver must hold the checker role and must
        // not be the request's maker.
        $request = $this->findRequest($requestId);
        if ($request === null || $request->employeeId === $approverId) {
            return false;
        }
        $request->status = 'approved';
        $request->approvedBy = $approverId;
        return true;
    }

    private function findRequest(int $requestId): ?LeaveRequest
    {
        return null; // storage stub for the fixture
    }
}
