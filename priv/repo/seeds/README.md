# Database Seeds

This directory contains database seeding scripts for the LinkedIn AI platform.

## Admin Users

To create admin users, run:

```bash
mix run priv/repo/seeds/admin_users.exs
```

This will create a default admin user with the following credentials:
- Email: `admin@linkedinai.com`
- Password: `AdminPassword123!`

**Important**: Change the default admin password after first login in production!

## Usage

The seeding script is idempotent - it can be run multiple times safely. It will:
- Create new admin users if they don't exist
- Promote existing users to admin if they're not already admins
- Skip users that are already admins

## Security Notes

1. Always change default passwords in production
2. Use strong, unique passwords for admin accounts
3. Consider using environment variables for admin credentials in production
4. Regularly audit admin user access

## Development

For development, you can modify the `admin_users.exs` script to add more admin users or change the default credentials.