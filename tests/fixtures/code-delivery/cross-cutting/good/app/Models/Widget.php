<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use App\Models\Scopes\BranchScoped;
class Widget extends Model
{
    protected $table = 'widgets';
    protected $fillable = ['name'];
    protected static function booted(): void
    {
        static::addGlobalScope(new BranchScoped);
    }
}
