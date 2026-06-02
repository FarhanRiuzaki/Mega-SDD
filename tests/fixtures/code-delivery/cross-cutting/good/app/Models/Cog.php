<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use App\Models\Scopes\BranchScoped;
class Cog extends Model
{
    protected $table = 'cogs';
    protected $fillable = ['name'];
    protected static function booted(): void
    {
        static::addGlobalScope(new BranchScoped);
    }
}
