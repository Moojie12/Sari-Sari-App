# Implementasyon ng De-Kilo at Shortage Adjustment

Dahil ang sari-sari store ay may mga produktong binibenta ng de-kilo (bigas, prutas, atbp.), kailangang suportahan ng system ang decimal quantities (hal. 0.5kg) at ang pag-report ng "kulang" sa inventory.

## Proposed Changes

### [Models]

#### [MODIFY] [employee_batch_model.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/users/employee_db/inventory/employee_batch_model.dart)
- Gagawing `double` ang `quantity`.

#### [MODIFY] [employee_product_model.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/users/employee_db/inventory/employee_product_model.dart)
- Gagawing `double` ang `quantity`, `sellableQuantity`, at `lowStockThreshold`.
- Magdadagdag ng `final bool isWeightBased`.
- I-aadjust ang `ArchivedStockItem` na `quantity` sa `double`.

#### [MODIFY] [employee_pos_controller.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/users/employee_db/pos/employee_pos_controller.dart)
- Gagawing `double` ang `quantity` sa `EmployeePosCartItem`.
- I-uupdate ang `itemCount` calculation para maging `double` (o `num`).

### [Controllers]

#### [MODIFY] [employee_inventory_controller.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/users/employee_db/employee_inventory_controller.dart)
- I-uupdate ang lahat ng methods (`receiveStock`, `archiveStock`, `deductFromBatch`, `adjustStock`) para gumamit ng `double` sa halip na `int`.
- Magdadagdag ng helper logic para sa "Shortage" adjustment.

#### [MODIFY] [employee_dummy_products.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/users/employee_db/inventory/employee_dummy_products.dart)
- I-uupdate ang dummy data para magsama ng `isWeightBased: true` sa mga items tulad ng Bigas at Mangga.

### [UI Components]

#### [MODIFY] [employee_add_product_page.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/users/employee_db/inventory/employee_add_product_page.dart)
- Magdadagdag ng toggle para sa "De-Kilo" sa manual entry sheet.
- Papayagan ang decimal input sa quantity text field.

#### [MODIFY] [employee_edit_product_page.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/users/employee_db/inventory/employee_edit_product_page.dart)
- Magdadagdag ng "De-Kilo" option at i-uupdate ang validation para sa decimal prices at quantities.

#### [MODIFY] [employee_inventory_page.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/users/employee_db/inventory/employee_inventory_page.dart)
- I-uupdate ang display ng quantity (hal. `1.50 kg` vs `10 pcs`).

#### [NEW] [employee_shortage_dialog.dart](file:///C:/Users/User/StudioProjects/Sari_Sari/lib/users/employee_db/inventory/employee_shortage_dialog.dart)
- Isang bagong dialog kung saan pwedeng i-input ang "magkano kulang" para sa isang produkto/batch.

## Verification Plan

### Manual Verification
- Mag-add ng bagong produktong "De-Kilo" (hal. Bigas).
- Mag-input ng decimal quantity (hal. 2.5).
- Sa POS, subukang ibenta ang 0.75kg ng bigas at tignan kung tama ang computation.
- Sa Inventory, gamitin ang "Shortage" feature para bawasan ang stock at i-verify kung nabawasan nga ito sa total.
