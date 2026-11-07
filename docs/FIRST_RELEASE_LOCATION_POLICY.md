# First-release location activation policy

The first public release is restricted to **Bideford**.

- Creating a location never activates it.
- The `locations.is_active` database default is `false`.
- A database check constraint prevents any non-Bideford location from being active.
- A unique partial index permits at most one active location.
- Only a platform administrator can activate/deactivate a location through `admin_set_location_active`.
- Every activation change requires a 5–500 character reason and is written to the audit log.
- Deactivation is blocked while a league is published or a season is public, registration-open or active.
- Barnstaple, Torrington and other future areas may be created, but remain inactive until the first-release restriction is explicitly changed following product-owner approval.

No location rows are seeded or activated by this migration. The owner/admin must create Bideford and deliberately activate it through the confirmed admin workflow.
