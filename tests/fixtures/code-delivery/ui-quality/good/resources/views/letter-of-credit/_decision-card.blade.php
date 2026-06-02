{{-- FPP-2 fixture: a non-trivial PARTIAL (basename starts with _). It is @include'd into a
     parent that owns @extends + the responsive grid, so required_elements (layout-extends,
     responsive) must NOT be required of it. It carries NO scaffold tells (humanized labels,
     resolved relations, formatted money) so scaffold_tells must not fire either. --}}
<div class="card">
  <div class="card-body">
    <h5 class="card-title">Decision Required</h5>
    <p class="text-muted">Stage {{ $stageLabel }} — step {{ $step }} of {{ $total }}</p>
    <dl class="row">
      <dt class="col-4">Applicant</dt>
      <dd class="col-8">{{ $model->customer?->name ?? '—' }}</dd>
      <dt class="col-4">Amount</dt>
      <dd class="col-8">{{ number_format((float) $model->amount, 2) }} {{ $model->currency_code }}</dd>
      <dt class="col-4">Status</dt>
      <dd class="col-8"><span class="badge bg-label-primary">{{ $model->workflow_state ?? '—' }}</span></dd>
    </dl>
    @if ($transitions->isEmpty())
      <div class="alert alert-secondary">Workflow ini sudah selesai.</div>
    @else
      <div class="d-flex gap-2">
        @foreach ($transitions as $t)
          <button type="button" class="btn btn-primary" data-action="{{ $t->action }}">{{ $t->label }}</button>
        @endforeach
      </div>
    @endif
  </div>
</div>
