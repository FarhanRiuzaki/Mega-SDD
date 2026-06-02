<?php
namespace App\Models;
use Illuminate\Foundation\Auth\User as Authenticatable;
class User extends Authenticatable
{
    protected $table = 'users';
    protected $fillable = ['name', 'branch_id'];
    // scope SOURCE: branch_id drives BranchScoped onto OTHER models; User must not self-scope
}
