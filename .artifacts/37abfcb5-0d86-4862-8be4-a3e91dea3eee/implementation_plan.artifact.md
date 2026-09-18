# Reorganize Admin Website Files and Directories

Consolidate all admin-related functionality into a dedicated `lib/admin/` directory to improve project structure and maintainability. This includes moving auth, dashboard, models, and controllers, and refactoring the large dashboard file.

## Proposed Changes

### [Admin Feature Consolidation]

#### [NEW] Directory `lib/admin/`
#### [NEW] Directory `lib/admin/auth/`
#### [NEW] Directory `lib/admin/dashboard/`
#### [NEW] Directory `lib/admin/dashboard/sections/`
#### [NEW] Directory `lib/admin/controllers/`
#### [NEW] Directory `lib/admin/models/`

#### [MODIFY] [admin_login_page.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/authentication/admin_login/admin_login_page.dart) -> [admin_login_page.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/admin/auth/admin_login_page.dart)
Move and update imports.

#### [MODIFY] [admin_controller.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/users/admin/admin_controller.dart) -> [admin_controller.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/admin/controllers/admin_controller.dart)
Move and update imports.

#### [MODIFY] [admin_models.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/users/admin/admin_models.dart) -> [admin_models.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/admin/models/admin_models.dart)
Move and update imports.

#### [MODIFY] [admin_dashboard.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/users/admin/admin_dashboard.dart) -> [admin_dashboard.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/admin/dashboard/admin_dashboard.dart)
Move and refactor by extracting sections (Overview, People, Products, etc.) into separate files in `lib/admin/dashboard/sections/`.

#### [NEW] [overview_section.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/admin/dashboard/sections/overview_section.dart)
Extracted overview logic.

#### [NEW] [people_section.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/admin/dashboard/sections/people_section.dart)
Extracted users/people logic.

#### [NEW] [products_section.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/admin/dashboard/sections/products_section.dart)
Extracted products logic.

#### [NEW] [categories_section.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/admin/dashboard/sections/categories_section.dart)
Extracted categories logic.

#### [NEW] [sales_section.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/admin/dashboard/sections/sales_section.dart)
Extracted sales/receipts logic.

#### [NEW] [archive_section.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/admin/dashboard/sections/archive_section.dart)
Extracted archive logic.

#### [NEW] [activity_section.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/admin/dashboard/sections/activity_section.dart)
Extracted activity logs logic.

#### [NEW] [settings_section.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/admin/dashboard/sections/settings_section.dart)
Extracted settings logic.

### [Project-wide Updates]

#### [MODIFY] [splash_page.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/core/splash/splash_page.dart)
Update import for `AdminLoginPage`.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no import errors or broken references.

### Manual Verification
- Verify the admin login and dashboard load correctly in a Flutter Web build (or by checking the UI flow in the IDE if applicable).
