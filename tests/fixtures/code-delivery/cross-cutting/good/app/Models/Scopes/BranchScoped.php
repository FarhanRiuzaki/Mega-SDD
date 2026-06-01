<?php
namespace App\Models\Scopes;
use Illuminate\Database\Eloquent\Scope;
class BranchScoped implements Scope
{
    public function apply($builder, $model) { $builder->where('branch_id', auth()->user()->branch_id); }
}
