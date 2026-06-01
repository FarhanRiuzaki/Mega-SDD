@extends('layouts.app')

@section('title', 'View Import LC')

@section('content')
<div class="container-fluid">
    <div class="row">
        <div class="col-md-8">
            <div class="card">
                <div class="card-body">
                    <h4 class="card-title">Import LC Detail</h4>

                    <div class="mb-3">
                        <label class="form-label text-muted small">Customer</label>
                        <div class="fw-semibold">{{ $model->customer->name ?? '-' }}</div>
                    </div>

                    <div class="mb-3">
                        <label class="form-label text-muted small">Branch</label>
                        <div class="fw-semibold">{{ $model->branch->name ?? '-' }}</div>
                    </div>

                    <div class="mb-3">
                        <label class="form-label text-muted small">Amount</label>
                        <div class="fw-semibold">{{ $model->currency }} {{ number_format($model->amount, 2) }}</div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
@endsection

@push('scripts')
<script>
    document.addEventListener('DOMContentLoaded', function () {
        const btn = document.getElementById('delete-btn');
        if (btn) {
            btn.addEventListener('click', function () {
                Swal.fire({
                    title: 'Delete this record?',
                    icon: 'warning',
                    showCancelButton: true,
                }).then(function (result) {
                    if (result.isConfirmed) {
                        document.getElementById('delete-form').submit();
                    }
                });
            });
        }
    });
</script>
@endpush
