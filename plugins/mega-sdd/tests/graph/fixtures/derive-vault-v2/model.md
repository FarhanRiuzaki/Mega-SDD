# Data Model

## Entities (DBML)

```dbml
// Purpose: System user account
Table user {
  id bigint [pk, increment]
  email varchar [unique]
  name varchar
  created_at timestamp [default: `now()`]
  updated_at timestamp
}

Table leave_request {
  id bigint [pk, increment]
  user_id bigint
  status varchar
  indexes {
    (user_id)
  }
}

Ref: leave_request.user_id > user.id
```

## Entity descriptions

### leave_request

- **Purpose**: Leave request lifecycle
- **Key fields**: user_id, status

## Retention

- Leave rows are retained 7 years.
