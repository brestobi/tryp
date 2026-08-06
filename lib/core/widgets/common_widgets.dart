import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/routes.dart';
import 'package:tryp/app/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Primary Button  — solid black pill  (Bolt-style)
// ─────────────────────────────────────────────────────────────────────────────

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool enabled;
  final double? width;
  final double height;
  final IconData? icon;

  /// Override button background color (defaults to TRYPColors.secondary = black)
  final Color? backgroundColor;

  /// Override text / icon color (defaults to white)
  final Color? foregroundColor;

  const PrimaryButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.width,
    this.height = 56,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? TRYPColors.secondary;
    final fg = foregroundColor ?? TRYPColors.white;

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: enabled && !isLoading ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: TRYPColors.greyLight,
          disabledForegroundColor: TRYPColors.grey,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: TRYPTypography.buttonText.copyWith(color: fg),
        ),
        child: isLoading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TRYPTypography.buttonText.copyWith(color: fg),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Accent Button — kept as a compatibility wrapper for existing call sites.
// ─────────────────────────────────────────────────────────────────────────────

class AccentButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool enabled;
  final double? width;
  final double height;
  final IconData? icon;

  const AccentButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.width,
    this.height = 56,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      enabled: enabled,
      width: width,
      height: height,
      icon: icon,
      backgroundColor: TRYPColors.primary,
      foregroundColor: TRYPColors.white,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Secondary / Ghost Button  — outline, no fill
// ─────────────────────────────────────────────────────────────────────────────

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool enabled;
  final double? width;
  final double height;

  const SecondaryButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.width,
    this.height = 56,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: enabled && !isLoading ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: TRYPColors.primary,
          side: const BorderSide(color: TRYPColors.primary, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: TRYPTypography.buttonText.copyWith(
            color: TRYPColors.primary,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    TRYPColors.secondary,
                  ),
                ),
              )
            : Text(
                label,
                style: TRYPTypography.buttonText.copyWith(
                  color: TRYPColors.primary,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Text Field  — Bolt-style: flat fill, no floating label, clean
// ─────────────────────────────────────────────────────────────────────────────

class CustomTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final IconData? prefixIcon;
  final Widget? prefixWidget;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final int maxLines;
  final int minLines;
  final int? maxLength;
  final bool autofocus;
  final bool readOnly;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  const CustomTextField({
    Key? key,
    this.label,
    this.hint,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.prefixWidget,
    this.suffixIcon,
    this.onSuffixTap,
    this.maxLines = 1,
    this.minLines = 1,
    this.maxLength,
    this.autofocus = false,
    this.readOnly = false,
    this.onTap,
    this.focusNode,
  }) : super(key: key);

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    Widget? suffixWidget;
    if (widget.obscureText) {
      suffixWidget = GestureDetector(
        onTap: () => setState(() => _obscureText = !_obscureText),
        child: Icon(
          _obscureText
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: TRYPColors.grey,
          size: 20,
        ),
      );
    } else if (widget.suffixIcon != null) {
      suffixWidget = GestureDetector(
        onTap: widget.onSuffixTap,
        child: Icon(widget.suffixIcon, color: TRYPColors.grey, size: 20),
      );
    }

    Widget? prefixWidget;
    if (widget.prefixWidget != null) {
      prefixWidget = widget.prefixWidget;
    } else if (widget.prefixIcon != null) {
      prefixWidget = Icon(widget.prefixIcon, color: TRYPColors.grey, size: 20);
    }

    final field = TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _obscureText,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      maxLines: _obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      autofocus: widget.autofocus,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      focusNode: widget.focusNode,
      style: TRYPTypography.bodyLarge,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: prefixWidget != null
            ? Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: prefixWidget,
              )
            : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffixWidget != null
            ? Padding(
                padding: const EdgeInsets.only(right: 14),
                child: suffixWidget,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        counterText: '',
      ),
    );

    if (widget.label == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label!,
          style: TRYPTypography.labelMedium.copyWith(
            color: TRYPColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading Indicator
// ─────────────────────────────────────────────────────────────────────────────

class LoadingIndicator extends StatelessWidget {
  final String? message;
  final Color color;

  const LoadingIndicator({
    Key? key,
    this.message,
    this.color = TRYPColors.secondary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeWidth: 2.5,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State Widget
// ─────────────────────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: TRYPColors.inputFill,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: TRYPColors.grey),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TRYPTypography.headingSmall,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TRYPTypography.bodyMedium.copyWith(
                  color: TRYPColors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 28),
              PrimaryButton(label: 'Retry', onPressed: onRetry!, width: 140),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error Display Widget
// ─────────────────────────────────────────────────────────────────────────────

class ErrorDisplay extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool fullScreen;

  const ErrorDisplay({
    Key? key,
    required this.message,
    this.onRetry,
    this.fullScreen = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: TRYPColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: TRYPColors.error,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Something went wrong',
            style: TRYPTypography.headingSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 28),
            PrimaryButton(label: 'Try Again', onPressed: onRetry!, width: 160),
          ],
        ],
      ),
    );

    if (fullScreen) return Scaffold(body: Center(child: content));
    return Center(child: content);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bolt-style Divider with label
// ─────────────────────────────────────────────────────────────────────────────

class LabeledDivider extends StatelessWidget {
  final String label;

  const LabeledDivider({Key? key, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: TRYPColors.divider, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(label, style: TRYPTypography.bodySmall),
        ),
        const Expanded(child: Divider(color: TRYPColors.divider, thickness: 1)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flat bottom navigation bar — full width, no floating container or radius.
// ─────────────────────────────────────────────────────────────────────────────

class TRYPBottomNavBar extends StatelessWidget {
  final int currentIndex;
  const TRYPBottomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: TRYPColors.white,
        border: Border(top: BorderSide(color: TRYPColors.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _TRYPNavItem(
                icon: Icons.directions_car_rounded,
                label: 'Rides',
                selected: currentIndex == 0,
                onTap: () => context.go(Routes.passengerHome),
              ),
              _TRYPNavItem(
                icon: Icons.receipt_long_rounded,
                label: 'Activity',
                selected: currentIndex == 1,
                onTap: () => context.go(Routes.passengerActivity),
              ),
              _TRYPNavItem(
                icon: Icons.notifications_none_rounded,
                label: 'Inbox',
                selected: currentIndex == 2,
                onTap: () => context.go(Routes.notifications),
              ),
              _TRYPNavItem(
                icon: Icons.person_rounded,
                label: 'Account',
                selected: currentIndex == 3,
                onTap: () => context.go(Routes.passengerProfile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TRYPNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TRYPNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? TRYPColors.primary : TRYPColors.grey;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          splashColor: TRYPColors.inputFill,
          highlightColor: TRYPColors.inputFill,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: selected ? TRYPColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TRYPTypography.labelSmall.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
