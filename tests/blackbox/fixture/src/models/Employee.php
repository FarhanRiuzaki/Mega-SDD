<?php

class Employee
{
    public int $id;
    public string $email;
    public string $role; // maker | checker
    public float $leaveBalance;

    public function isChecker(): bool
    {
        return $this->role === 'checker';
    }
}
