import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/wallet_transaction.dart';
import '../../../../shared/services/wallet_service.dart';

final _walletServiceProvider =
    Provider<WalletService>((ref) => WalletService());

/// Wallet screen — big balance cards + a transactions list.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  Map<String, int>? _balance;
  List<WalletTransaction> _transactions = const [];
  bool _loading = true;
  bool _loadingTx = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _loadTransactions();
  }

  Future<void> _loadBalance() async {
    setState(() => _loading = true);
    try {
      final b = await ref.read(_walletServiceProvider).balance();
      if (!mounted) return;
      setState(() {
        _balance = b;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _loadingTx = true);
    try {
      final list = await ref.read(_walletServiceProvider).transactions();
      if (!mounted) return;
      setState(() {
        _transactions = list;
        _loadingTx = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingTx = false);
    }
  }

  Future<void> _reloadAll() async {
    await Future.wait([_loadBalance(), _loadTransactions()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadAll,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: _reloadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _BalanceCards(
              loading: _loading,
              coins: _balance?['coins'] ?? 0,
              gems: _balance?['gems'] ?? 0,
              error: _error,
            ),
            const SizedBox(height: 22),
            const _SectionHeader(label: 'Transactions'),
            const SizedBox(height: 10),
            _TransactionsList(
              loading: _loadingTx,
              transactions: _transactions,
              onRetry: _loadTransactions,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _BalanceCards extends StatelessWidget {
  final bool loading;
  final int coins;
  final int gems;
  final String? error;

  const _BalanceCards({
    required this.loading,
    required this.coins,
    required this.gems,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BalanceCard(
            label: 'Coins',
            value: coins,
            icon: Icons.monetization_on_rounded,
            gradient: const [Color(0xFFFFC107), Color(0xFFFF6F00)],
            loading: loading,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BalanceCard(
            label: 'Gems',
            value: gems,
            icon: Icons.diamond,
            gradient: const [Color(0xFF00BCD4), Color(0xFF1E88E5)],
            loading: loading,
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final List<Color> gradient;
  final bool loading;

  const _BalanceCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.20),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.65),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          loading
              ? Container(
                  height: 22,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                )
              : Text(
                  NumberFormat.decimalPattern().format(value),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.black.withOpacity(0.65),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsList extends StatelessWidget {
  final bool loading;
  final List<WalletTransaction> transactions;
  final VoidCallback onRetry;

  const _TransactionsList({
    required this.loading,
    required this.transactions,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return _buildSkeleton();
    if (transactions.isEmpty) {
      return _EmptyState(onRetry: onRetry);
    }
    return Column(
      children: transactions
          .map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TransactionTile(tx: t),
              ))
          .toList(),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      children: List.generate(
        6,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction tx;
  const _TransactionTile({required this.tx});

  bool get _isCredit => tx.type == 'credit';
  bool get _isGem => tx.currency == 'gem';
  Color get _color => _isCredit ? AppTheme.success : AppTheme.danger;

  String get _reasonLabel {
    final r = tx.reason;
    if (r.isEmpty) return 'Transaction';
    return r
        .split('_')
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM, HH:mm');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isGem ? Icons.diamond : Icons.monetization_on,
              color: _color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _reasonLabel,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  df.format(tx.createdAt.toLocal()),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_isCredit ? '+' : '-'}${tx.amount}',
                style: TextStyle(
                  color: _color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Bal: ${tx.balanceAfter}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 44, color: AppTheme.textSecondary),
          const SizedBox(height: 12),
          const Text(
            'No transactions yet',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'When you win coins, claim rewards, or buy gems they will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
