# Supabase Migrations

This folder holds SQL migration files for the TRYP Supabase backend.

Naming convention:
- `000001_description.sql`
- `000002_description.sql`

Apply migrations using the Supabase CLI:

```bash
supabase db remote set <your-project-ref>
supabase db push
```

Add new migrations here as the schema evolves.
