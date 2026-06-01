<?php
namespace App\Models;
use Illuminate\Database\Eloquent\Model;
use App\Models\Scopes\BranchScoped;
class Sprocket extends Model
{
    protected $table = 'sprockets';
    protected $fillable = ['name'];
    protected static function booted(): void
    {
        static::addGlobalScope(new BranchScoped);
    }
}
