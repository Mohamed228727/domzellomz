import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:egypttest/global/passengers_model.dart';
import 'package:egypttest/global/payment_model.dart';
import 'package:egypttest/global/chat_model.dart';
import 'package:egypttest/pages/bus_routes_page.dart';
import 'package:egypttest/pages/HomeScreen.dart';
import 'package:egypttest/pages/chat_ui.dart';

class Wallet extends StatefulWidget {
  const Wallet({super.key});

  @override
  State<Wallet> createState() => _WalletState();
}

class _WalletState extends State<Wallet> {
  PassengerModel? passenger;
  List<TransactionModel> transactions = [];
  bool isLoading = true;
  bool isRefreshing = false;
  bool isBalanceVisible = true; // For balance toggle
  int selectedIndex = 3; // Wallet is selected
  final Color selectedColor = Color(0xFF38B6FF);
  final Color unselectedColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    loadWalletData();
  }

  Future<void> loadWalletData() async {
    setState(() {
      isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get passenger data
        passenger = await PassengerModel.getPassenger(user.uid);
        
        if (passenger != null) {
          // Try to get transaction history with better error handling
          try {
            transactions = await TransactionModel.getPassengerTransactions(user.uid, limit: 20);
          } catch (e) {
            print('Error loading transactions (likely missing index): $e');
            // If index error, show empty transactions but don't fail completely
            if (e.toString().contains('requires an index')) {
              transactions = [];
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaction history unavailable. Please create the required Firestore index.'),
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            } else {
              // Re-throw other errors
              throw e;
            }
          }
        }
      }
    } catch (e) {
      print('Error loading wallet data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading wallet: ${e.toString()}')),
        );
      }
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> refreshWallet() async {
    setState(() {
      isRefreshing = true;
    });

    if (passenger != null) {
      await passenger!.refreshBalance();
      await loadWalletData();
    }

    setState(() {
      isRefreshing = false;
    });
  }

  void toggleBalanceVisibility() {
    print('🔍 Toggle balance visibility called - Current: $isBalanceVisible');
    setState(() {
      isBalanceVisible = !isBalanceVisible;
    });
    print('🔍 New balance visibility: $isBalanceVisible');
  }

  void showTopUpDialog() {
    final TextEditingController amountController = TextEditingController();
    String selectedMethod = 'testing'; // Default to testing for demo

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Top Up Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (EGP)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedMethod,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment),
              ),
              items: const [
                DropdownMenuItem(value: 'card', child: Text('Credit/Debit Card')),
                DropdownMenuItem(value: 'fawry', child: Text('Fawry')),
                DropdownMenuItem(value: 'vodafone_cash', child: Text('Vodafone Cash')),
                DropdownMenuItem(value: 'orange_cash', child: Text('Orange Cash')),
                DropdownMenuItem(value: 'testing', child: Text('Testing (Demo)')),
              ],
              onChanged: (value) {
                selectedMethod = value!;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              double? amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0 && passenger != null) {
                print('🔥 Starting top-up process for amount: $amount');
                
                // Store the navigator before closing any dialogs
                final navigator = Navigator.of(context, rootNavigator: true);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                // Close the top-up dialog first
                Navigator.pop(context);
                
                // Show loading dialog and store its context
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (loadingContext) => const AlertDialog(
                    content: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 20),
                        Text('Processing payment...'),
                      ],
                    ),
                  ),
                );

                // Use a delayed approach to allow the UI to settle
                await Future.delayed(const Duration(milliseconds: 100));

                try {
                  print('🔥 About to call addBalance method');
                  
                  // Add balance
                  bool success = await passenger!.addBalance(amount, selectedMethod)
                      .timeout(const Duration(seconds: 10));
                  
                  print('🔥 addBalance completed, success: $success');
                  
                  // Close loading dialog using stored navigator
                  try {
                    navigator.pop();
                    print('🔥 Loading dialog closed');
                  } catch (e) {
                    print('🔥 Error closing dialog: $e');
                  }

                  // Use post frame callback to ensure UI is ready
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      if (success) {
                        print('🔥 Showing success message');
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('Successfully added ${amount.toStringAsFixed(2)} EGP'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        print('🔥 About to refresh wallet data');
                        loadWalletData(); // Refresh wallet data (don't await here)
                        print('🔥 Wallet data refresh started');
                      } else {
                        print('🔥 addBalance returned false');
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Failed to add balance'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  });

                } catch (e) {
                  print('🔥 Error occurred: $e');
                  
                  // Close loading dialog
                  try {
                    navigator.pop();
                    print('🔥 Loading dialog closed due to error');
                  } catch (navError) {
                    print('🔥 Error closing dialog due to error: $navError');
                  }
                  
                  // Use post frame callback for error message too
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  });
                }
                
                print('🔥 Top-up process completed');
              }
            },
            child: const Text('Add Money'),
          ),
        ],
      ),
    );
  }

  // UPDATED: Navigate to transfer page instead of showing "coming soon"
  void showTransferPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TransferMoneyPage(),
      ),
    );
  }

  void handleNavigation(int index) {
    if (index == selectedIndex) return; // Already on this page

    setState(() {
      selectedIndex = index;
    });

    if (index == 0) {
      // Navigate to departures
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BusRoutesPage()),
      );
    } else if (index == 1) {
      // UPDATED: Navigate to chat instead of groups
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChatUI()),
      );
    } else if (index == 2) {
      // Navigate to home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
    // Add more navigation cases as needed
  }

  Widget _buildIconButton(IconData icon, int index) {
    return IconButton(
      icon: Icon(icon, color: selectedIndex == index ? selectedColor : unselectedColor),
      onPressed: () => handleNavigation(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        backgroundColor: const Color(0xFF141A57),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button since we have nav bar
        actions: [
          IconButton(
            icon: isRefreshing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            onPressed: isRefreshing ? null : refreshWallet,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : passenger == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No wallet data found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please try logging in again',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: refreshWallet,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Wallet Balance Card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF141A57), Color(0xFF2A3F7A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.account_balance_wallet, 
                                            color: Colors.white, size: 28),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Wallet Balance',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const Spacer(),
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(20),
                                            onTap: toggleBalanceVisibility,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              child: Icon(
                                                isBalanceVisible ? Icons.visibility : Icons.visibility_off,
                                                color: Colors.white70,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      transitionBuilder: (Widget child, Animation<double> animation) {
                                        return FadeTransition(opacity: animation, child: child);
                                      },
                                      child: Text(
                                        isBalanceVisible
                                            ? passenger!.balanceWithCurrency
                                            : '••••• EGP',
                                        key: ValueKey<bool>(isBalanceVisible),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: isBalanceVisible ? 0 : 4,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Text(
                                          passenger!.fname != null && passenger!.lname != null
                                              ? '${passenger!.fname} ${passenger!.lname}'
                                              : passenger!.name ?? 'Passenger',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                        const Text(
                                          'EGY Transit',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Action Buttons - UPDATED TRANSFER BUTTON
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: showTopUpDialog,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Top Up'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF141A57),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: showTransferPage, // UPDATED: Navigate to transfer page
                                      icon: const Icon(Icons.send),
                                      label: const Text('Transfer'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF141A57),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              // Transaction History Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Recent Transactions',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Full history coming soon!')),
                                      );
                                    },
                                    child: const Text('View All'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Transaction List
                              transactions.isEmpty
                                  ? Container(
                                      padding: const EdgeInsets.all(32),
                                      child: const Column(
                                        children: [
                                          Icon(Icons.receipt_long, 
                                              size: 64, color: Colors.grey),
                                          SizedBox(height: 16),
                                          Text(
                                            'No transactions yet',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Start by topping up your wallet',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: transactions.length,
                                      itemBuilder: (context, index) {
                                        final transaction = transactions[index];
                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: ListTile(
                                            contentPadding: const EdgeInsets.all(16),
                                            leading: CircleAvatar(
                                              backgroundColor: transaction.isCredit
                                                  ? Colors.green.withOpacity(0.2)
                                                  : Colors.red.withOpacity(0.2),
                                              child: Icon(
                                                transaction.isCredit
                                                    ? Icons.add
                                                    : Icons.remove,
                                                color: transaction.isCredit
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            ),
                                            title: Text(
                                              transaction.typeDisplayName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(transaction.description),
                                                const SizedBox(height: 4),
                                                Text(
                                                  transaction.formattedDate,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            trailing: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${transaction.isCredit ? '+' : '-'}${transaction.amountWithCurrency}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: transaction.isCredit
                                                        ? Colors.green
                                                        : Colors.red,
                                                  ),
                                                ),
                                                Text(
                                                  'Balance: ${transaction.balanceAfter.toStringAsFixed(2)} EGP',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bottom Navigation Bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 8)
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildIconButton(Icons.departure_board, 0),
                          _buildIconButton(Icons.groups, 1), 
                          _buildIconButton(Icons.home, 2),
                          _buildIconButton(Icons.credit_card, 3),
                          _buildIconButton(Icons.more_horiz, 4),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

// hello dommzzzz