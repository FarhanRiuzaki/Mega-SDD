<?php

class LeaveRequest
{
    public int $id;
    public int $employeeId;
    public string $startDate;
    public string $endDate;
    public string $status; // draft | submitted | approved | rejected
    public ?int $approvedBy = null;
}
