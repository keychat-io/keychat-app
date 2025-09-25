import 'package:app/models/models.dart';
import 'package:app/utils.dart'; // Added import for isEmail function
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class LightningAddressEditDialog extends StatefulWidget {
  const LightningAddressEditDialog({
    required this.identity,
    super.key,
  });
  final Identity identity;

  @override
  State<LightningAddressEditDialog> createState() =>
      _LightningAddressEditDialogState();
}

class _LightningAddressEditDialogState
    extends State<LightningAddressEditDialog> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.identity.lightning ?? '');
    _validateInput(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _validateInput(String value) {
    // Empty value is valid (to clear the lightning address)
    if (value.isEmpty) {
      setState(() => _errorText = null);
      return true;
    }

    // Check if it's either an email or starts with LNURL
    if (isEmail(value) || value.toUpperCase().startsWith('LNURL')) {
      setState(() => _errorText = null);
      return true;
    } else {
      setState(() => _errorText = 'Enter a valid lightning address');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('Lightning Address'),
      content: Column(
        children: [
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'lnurl or user@domain',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              errorText: _errorText,
            ),
            minLines: 1,
            maxLines: 4,
            autocorrect: false,
            onChanged: _validateInput,
          ),
        ],
      ),
      actions: [
        CupertinoActionSheetAction(
          onPressed: Get.back,
          child: const Text('Cancel'),
        ),
        CupertinoActionSheetAction(
          onPressed: () async {
            if (_errorText != null) return;

            final value = _controller.text;

            if (value.isNotEmpty && !_validateInput(value)) {
              return; // Don't proceed if validation fails
            }

            final newValue = value.isEmpty ? null : value;
            final success =
                await widget.identity.updateLightningAddress(newValue);

            if (success) {
              EasyLoading.showSuccess('Lightning address updated');
              Get.back(result: newValue);
            } else {
              EasyLoading.showError('Failed to update lightning address');
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
