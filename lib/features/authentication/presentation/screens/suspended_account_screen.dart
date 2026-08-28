import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuspendedAccountScreen extends StatelessWidget {
  const SuspendedAccountScreen({super.key, this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block_rounded, color: Color(0xFFE31B23), size: 64),
                const SizedBox(height: 24),
                const Text('Account suspended', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                const Text('You cannot use TRYP while your account is suspended.', textAlign: TextAlign.center),
                if (reason != null && reason!.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(14)),
                    child: Text('Reason: ${reason!.trim()}'),
                  ),
                ],
                const SizedBox(height: 18),
                const Text('Please contact support if you believe this was a mistake.', textAlign: TextAlign.center),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
