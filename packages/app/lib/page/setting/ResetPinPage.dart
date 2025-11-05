import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keychat/service/secure_storage.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class ResetPinPage extends StatefulWidget {
  const ResetPinPage({super.key});

  @override
  _ResetPinPageState createState() => _ResetPinPageState();
}

enum PinStep { enterOld, enterNew, confirmNew }

class _ResetPinPageState extends State<ResetPinPage> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool _hasExistingPin = false;
  PinStep _currentStep = PinStep.enterNew;
  String _newPin = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingPin();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _checkExistingPin() async {
    // await SecureStorage.instance.deletePinCode(); // TODO
    final hasPin = await SecureStorage.instance.hasPinCode();
    setState(() {
      _hasExistingPin = hasPin;
      _currentStep = hasPin ? PinStep.enterOld : PinStep.enterNew;
    });
  }

  String get _currentPin => _controllers.map((c) => c.text).join();

  String get _title {
    if (!_hasExistingPin) return 'Create a new PIN';
    switch (_currentStep) {
      case PinStep.enterOld:
        return 'Enter Current PIN';
      case PinStep.enterNew:
        return 'Enter New PIN';
      case PinStep.confirmNew:
        return 'Confirm New PIN';
    }
  }

  String get _subtitle {
    if (!_hasExistingPin) return 'Create a 4-digit PIN to secure your account';
    switch (_currentStep) {
      case PinStep.enterOld:
        return 'Enter your current PIN to continue';
      case PinStep.enterNew:
        return 'Enter your new 4-digit PIN';
      case PinStep.confirmNew:
        return 'Confirm your new PIN';
    }
  }

  void _clearInputs() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _handlePinComplete() async {
    if (_currentPin.length != 4) return;

    setState(() {
      _isLoading = true;
    });

    try {
      switch (_currentStep) {
        case PinStep.enterOld:
          final isValid = await SecureStorage.instance.verifyPinCode(
            _currentPin,
          );
          if (isValid) {
            setState(() {
              _currentStep = PinStep.enterNew;
            });
            _clearInputs();
          } else {
            EasyLoading.showError('Incorrect PIN. Please try again.');
            _clearInputs();
          }

        case PinStep.enterNew:
          _newPin = _currentPin;
          if (_hasExistingPin) {
            setState(() {
              _currentStep = PinStep.confirmNew;
            });
            _clearInputs();
          } else {
            // For new PIN creation, save directly
            await SecureStorage.instance.savePinCode(_newPin);
            _showSuccessAndGoBack();
          }

        case PinStep.confirmNew:
          if (_currentPin == _newPin) {
            await SecureStorage.instance.savePinCode(_newPin);
            _showSuccessAndGoBack();
          } else {
            EasyLoading.showError('PINs do not match. Please try again.');
            setState(() {
              _currentStep = PinStep.enterNew;
            });
            _clearInputs();
          }
      }
    } catch (e) {
      EasyLoading.showError('An error occurred. Please try again.');
      _clearInputs();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessAndGoBack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _hasExistingPin
              ? 'PIN updated successfully'
              : 'PIN created successfully',
        ),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  void _onPinChanged(int index, String value) {
    if (value.isNotEmpty && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _subtitle,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_currentStep == PinStep.confirmNew)
              Text(
                'Lost or forgotten PINs cannot be recovered!',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.amber),
                textAlign: TextAlign.center,
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) {
                return SizedBox(
                  width: 60,
                  height: 60,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) => _onPinChanged(index, value),
                    onTap: () {
                      _controllers[index]
                          .selection = TextSelection.fromPosition(
                        TextPosition(offset: _controllers[index].text.length),
                      );
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              TextButton(
                onPressed: _clearInputs,
                child: const Text('Clear'),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _currentPin.length == 4 && !_isLoading
                  ? _handlePinComplete
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}
