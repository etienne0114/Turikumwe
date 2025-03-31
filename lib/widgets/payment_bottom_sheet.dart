// lib/widgets/payment_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:turikumwe/constants/app_colors.dart';
import 'package:turikumwe/models/event.dart';
import 'package:turikumwe/utils/dialog_utils.dart';
import 'package:turikumwe/widgets/custom_button.dart';

class PaymentBottomSheet extends StatefulWidget {
  final Event event;
  final VoidCallback onPaymentComplete;

  const PaymentBottomSheet({
    Key? key,
    required this.event,
    required this.onPaymentComplete,
  }) : super(key: key);

  @override
  State<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _selectedPaymentMethod = '';

  @override
  void initState() {
    super.initState();
    _selectedPaymentMethod = widget.event.paymentMethod ?? 'MTN Mobile Money';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));

      // In a real app, you would integrate with payment APIs here
      // For now, just consider the payment successful

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        DialogUtils.showSuccessSnackBar(
          context,
          message: 'Payment successful! You are now registered for the event.',
        );
        
        widget.onPaymentComplete();
      }
    } catch (e) {
      debugPrint('Error processing payment: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        DialogUtils.showErrorSnackBar(
          context,
          message: 'Payment failed. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safely access event.price with null check
    final price = widget.event.price ?? 0;
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                
                const Divider(),
                
                // Event details
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    widget.event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(widget.event.date),
                  ),
                  trailing: Text(
                    '${price.toStringAsFixed(0)} RWF',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Payment method selector
                const Text(
                  'Select Payment Method',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Radio buttons for payment methods
                _buildPaymentMethodSelector(
                  'MTN Mobile Money', 
                  'Pay with MTN Mobile Money', 
                  Icons.phone_android,
                ),
                _buildPaymentMethodSelector(
                  'Airtel Money', 
                  'Pay with Airtel Money', 
                  Icons.phone_android,
                ),
                _buildPaymentMethodSelector(
                  'Credit Card', 
                  'Pay with Credit/Debit Card', 
                  Icons.credit_card,
                ),
                _buildPaymentMethodSelector(
                  'Bank Transfer', 
                  'Pay via Bank Transfer', 
                  Icons.account_balance,
                ),
                
                const SizedBox(height: 16),
                
                // Phone number field (for mobile money)
                if (_selectedPaymentMethod == 'MTN Mobile Money' || 
                    _selectedPaymentMethod == 'Airtel Money')
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '07XXXXXXXX',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.phone),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.contacts),
                        onPressed: () {
                          // In a real app, you would open the contacts picker
                        },
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (value.length < 10) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                
                // Card details (for credit card)
                if (_selectedPaymentMethod == 'Credit Card')
                  Column(
                    children: [
                      // Card number field
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Card Number',
                          hintText: 'XXXX XXXX XXXX XXXX',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.credit_card),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your card number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Expiry date and CVV
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Expiry Date',
                                hintText: 'MM/YY',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'CVV',
                                hintText: 'XXX',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                
                // Bank account details (for bank transfer)
                if (_selectedPaymentMethod == 'Bank Transfer')
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bank Account Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildBankDetail('Bank Name', 'Bank of Kigali'),
                        _buildBankDetail('Account Name', 'Turikumwe Events Ltd'),
                        _buildBankDetail('Account Number', '0000-1111-2222-3333'),
                        _buildBankDetail('Reference', 'Event-${widget.event.id}'),
                        const SizedBox(height: 8),
                        const Text(
                          'Please upload your payment receipt to complete registration',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            // In a real app, you would implement file upload
                          },
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload Receipt'),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Payment button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _processPayment,
                    icon: const Icon(Icons.payment),
                    label: Text('Pay ${price.toStringAsFixed(0)} RWF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector(String value, String label, IconData icon) {
    return RadioListTile<String>(
      title: Text(label),
      secondary: Icon(icon),
      value: value,
      groupValue: _selectedPaymentMethod,
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
      onChanged: (newValue) {
        if (newValue != null) {
          setState(() {
            _selectedPaymentMethod = newValue;
          });
        }
      },
    );
  }
  
  Widget _buildBankDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}