---
name: 02-features-plan
description: Plan Laravel feature implementation
prev_step: references/laravel/01-analyze-code.md
next_step: references/laravel/03-execution.md
---

# 02 - Features Plan (Laravel)

**Plan Laravel feature implementation (APEX Phase P).**

## When to Use

- After analysis phase complete
- Before writing any code
- For complex features requiring multiple files

---

## Laravel Feature Components

### Typical Feature Structure

```text
Feature: User Profile API
├── Migration          # Database changes
├── Model              # Eloquent model + relations
├── DTO                # Data transfer object
├── Service            # Business logic
├── Controller         # HTTP layer (thin)
├── FormRequest        # Validation rules
├── Resource           # API transformation
├── Policy             # Authorization
└── Test               # Feature + Unit tests
```

---

## Task Breakdown

### Task Template

```markdown
## Feature: [Name]

### Database Layer
- [ ] Create migration for [table]
- [ ] Update Model with relations/casts

### Business Logic
- [ ] Create [Feature]DTO
- [ ] Create [Feature]Service
- [ ] Register in AppServiceProvider

### HTTP Layer
- [ ] Create [Feature]Controller
- [ ] Create [Feature]Request (validation)
- [ ] Create [Feature]Resource (API)

### Authorization
- [ ] Create [Feature]Policy
- [ ] Register in AuthServiceProvider

### Tests
- [ ] Feature test for API endpoints
- [ ] Unit test for Service
```

---

## File Size Estimation

### File-size ceiling: `FUSE_SOLID_MAX_LINES` (default `200`)

| Component | Planning rule |
| --- | --- |
| Controller | Keep focused on HTTP orchestration |
| Model | Keep focused on domain state and relationships |
| Service | Keep focused on one business responsibility |
| FormRequest | Keep focused on one input contract |
| Resource | Keep focused on one representation |
| Migration | Keep focused on one schema change |
| Policy | Keep focused on one authorization concern |

### If Exceeds Limit

```text
Any file over FUSE_SOLID_MAX_LINES -> Split by responsibility
Controller with multiple resources -> Split by resource
Service with multiple responsibilities -> Extract focused services
Model with unrelated concerns -> Extract traits or collaborators
```

---

## Artisan Generation Commands

### Create All Components

```bash
# Migration
php artisan make:migration create_posts_table

# Model with all options
php artisan make:model Post -mfsc
# -m migration, -f factory, -s seeder, -c controller

# Controller types
php artisan make:controller PostController --api
php artisan make:controller PostController --invokable

# Request & Resource
php artisan make:request StorePostRequest
php artisan make:resource PostResource

# Policy
php artisan make:policy PostPolicy --model=Post

# Service (manual or custom command)
# app/Services/PostService.php
```

---

## Planning Checklist

### Database Design

```text
[ ] Table schema defined
[ ] Foreign keys planned
[ ] Indexes identified
[ ] Soft deletes needed?
[ ] Timestamps needed?
```

### API Design

```text
[ ] Endpoints defined (RESTful)
[ ] Request validation rules
[ ] Response structure (Resource)
[ ] Status codes mapped
[ ] Error responses planned
```

### Authorization

```text
[ ] Who can create?
[ ] Who can read?
[ ] Who can update?
[ ] Who can delete?
[ ] Special permissions?
```

---

## Example Plan

### Feature: Blog Posts API

```markdown
### Phase 1: Database
- [ ] Migration: posts table
  - id, user_id, title, slug, content, status, published_at
- [ ] Model: Post with User relation

### Phase 2: Business Logic
- [ ] CreatePostDTO (title, content, status)
- [ ] PostService (create, update, publish)

### Phase 3: HTTP Layer
- [ ] PostController (index, store, show, update, destroy)
- [ ] StorePostRequest (title required, content required)
- [ ] UpdatePostRequest (title optional, content optional)
- [ ] PostResource (id, title, author, created_at)

### Phase 4: Authorization
- [ ] PostPolicy (create, update, delete)

### Phase 5: Tests
- [ ] PostControllerTest (CRUD operations)
- [ ] PostServiceTest (business logic)

Estimated files: 10
Estimated lines: ~400 total
```

---

## SOLID Considerations

### Single Responsibility

```text
Controller: HTTP only
Service: Business logic only
Repository: Data access only
DTO: Data transfer only
```

### Interface Segregation

```text
Split large interfaces:
- UserReadRepositoryInterface
- UserWriteRepositoryInterface
```

---

## Validation Checklist

```text
[ ] All components identified
[ ] File sizes estimated within `FUSE_SOLID_MAX_LINES`
[ ] Artisan commands listed
[ ] Dependencies mapped
[ ] Test coverage planned
[ ] SOLID principles considered
```

---

## Task Phase

Phase: `features-plan`. Do not create or write `.cursor/apex/task.json`: on Cursor no tool syncs it (the harness task sync is Claude-only). State the phase in your REPORT; tracking lives in the agents' REPORTs and `docs/decisions.md`.

---

## Next Phase

Proceed to `03-execution.md`
