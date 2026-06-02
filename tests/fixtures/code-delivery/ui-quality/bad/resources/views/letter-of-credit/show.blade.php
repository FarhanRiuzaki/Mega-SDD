@extends('layouts.app')

@section('title', 'LetterOfCreditController List')

@section('content')
<div class="container-fluid">
    <div class="row">
        <div class="col-md-8">
            <div class="card">
                <div class="card-body">
                    <h4 class="card-title">Detail</h4>

                    <div class="mb-3">
                        <label class="form-label text-muted small">Customer Id</label>
                        <div class="fw-semibold">{{ $model->customer_id ?? '-' }}</div>
                    </div>

                    <div class="mb-3">
                        <label class="form-label text-muted small">Branch Id</label>
                        <div class="fw-semibold">{{ $model->branch_id ?? '-' }}</div>
                    </div>

                    <div class="mb-3">
                        <label class="form-label text-muted small">Amount</label>
                        <div class="fw-semibold">{{ $model->amount ?? '-' }}</div>
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
                if (confirm('Are you sure you want to delete this record?')) {
                    document.getElementById('delete-form').submit();
                }
            });
        }
    });
</script>
@endpush
