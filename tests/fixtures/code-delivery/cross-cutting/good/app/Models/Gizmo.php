<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use App\Models\Scopes\BranchScoped;
class Gizmo extends Model
{
    protected $table = 'gizmos';
    protected $fillable = ['name'];
    protected static function booted(): void
    {
        static::addGlobalScope(new BranchScoped);
    }
}
