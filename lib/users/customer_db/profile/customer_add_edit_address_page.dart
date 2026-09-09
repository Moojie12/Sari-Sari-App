import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'customer_address_model.dart';
import 'customer_address_controller.dart';

class CustomerAddEditAddressPage extends StatefulWidget {
  const CustomerAddEditAddressPage({super.key, this.address});
  final CustomerAddress? address;

  @override
  State<CustomerAddEditAddressPage> createState() => _CustomerAddEditAddressPageState();
}

class _CustomerAddEditAddressPageState extends State<CustomerAddEditAddressPage> {
  late final TextEditingController _typeController;
  late final TextEditingController _addressController;
  bool _isDefault = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _typeController = TextEditingController(text: widget.address?.type ?? '');
    _addressController = TextEditingController(text: widget.address?.address ?? '');
    _isDefault = widget.address?.isDefault ?? false;
  }

  @override
  void dispose() {
    _typeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final type = _typeController.text.trim();
    final addressText = _addressController.text.trim();

    if (widget.address == null) {
      final newAddress = CustomerAddress(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        address: addressText,
        isDefault: _isDefault,
      );
      CustomerAddressController.instance.addAddress(newAddress);
    } else {
      final updated = widget.address!.copyWith(
        type: type,
        address: addressText,
        isDefault: _isDefault,
      );
      CustomerAddressController.instance.updateAddress(updated);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.address != null;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Address' : 'Add New Address',
          style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Address Type', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _typeController,
                decoration: InputDecoration(
                  hintText: 'e.g. Home, Office, School',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderColor)),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Please enter address type' : null,
              ),
              const SizedBox(height: 20),
              const Text('Full Address', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkText)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'House No., Street, Barangay, City, Province',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderColor)),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Please enter full address' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Checkbox(
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v ?? false),
                    activeColor: AppColors.primaryOrange,
                  ),
                  const Text('Set as default address', style: TextStyle(color: AppColors.secondaryText)),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isEditing ? 'SAVE CHANGES' : 'ADD ADDRESS',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
