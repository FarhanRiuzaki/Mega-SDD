<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use App\Models\Scopes\BranchScoped;
class Gadget extends Model
{
    protected $table = 'gadgets';
    protected $fillable = ['name'];
    protected static function booted(): void
    {
        static::addGlobalScope(new BranchScoped);
    }
}
