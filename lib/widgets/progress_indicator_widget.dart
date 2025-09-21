import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../utils/constants.dart';

class ProgressIndicatorWidget extends StatelessWidget {
  final double? value;
  final String? message;
  final String? subMessage;
  final Color? color;
  final bool showPercentage;
  final double size;

  const ProgressIndicatorWidget({
    super.key,
    this.value,
    this.message,
    this.subMessage,
    this.color,
    this.showPercentage = true,
    this.size = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? AppColors.primaryColor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (value != null)
          _buildLinearProgress(progressColor)
        else
          _buildIndeterminateProgress(progressColor),

        if (message != null) ...[
          const SizedBox(height: AppDimensions.paddingMedium),
          Text(
            message!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        if (subMessage != null) ...[
          const SizedBox(height: AppDimensions.paddingSmall),
          Text(
            subMessage!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        if (value != null && showPercentage) ...[
          const SizedBox(height: AppDimensions.paddingSmall),
          Text(
            '${(value! * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: progressColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLinearProgress(Color color) {
    return Column(
      children: [
        SizedBox(
          width: 200,
          height: 6,
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: AppColors.dividerColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildIndeterminateProgress(Color color) {
    return SpinKitWave(
      color: color,
      size: size,
    );
  }
}

class CircularProgressWidget extends StatelessWidget {
  final double? value;
  final String? message;
  final Color? color;
  final double size;
  final double strokeWidth;

  const CircularProgressWidget({
    super.key,
    this.value,
    this.message,
    this.color,
    this.size = 80.0,
    this.strokeWidth = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = color ?? AppColors.primaryColor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: strokeWidth,
                backgroundColor: AppColors.dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            if (value != null)
              Text(
                '${(value! * 100).toInt()}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
          ],
        ),
        if (message != null) ...[
          const SizedBox(height: AppDimensions.paddingMedium),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepLabels;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? completedColor;

  const StepProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabels,
    this.activeColor,
    this.inactiveColor,
    this.completedColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeCol = activeColor ?? AppColors.primaryColor;
    final inactiveCol = inactiveColor ?? AppColors.dividerColor;
    final completedCol = completedColor ?? AppColors.successColor;

    return Column(
      children: [
        Row(
          children: List.generate(totalSteps, (index) {
            final isActive = index == currentStep;
            final isCompleted = index < currentStep;
            final isLast = index == totalSteps - 1;

            return Expanded(
              child: Row(
                children: [
                  _buildStepCircle(
                    index + 1,
                    isActive,
                    isCompleted,
                    activeCol,
                    inactiveCol,
                    completedCol,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isCompleted ? completedCol : inactiveCol,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: AppDimensions.paddingSmall),
        Row(
          children: List.generate(totalSteps, (index) {
            final isActive = index == currentStep;
            final isCompleted = index < currentStep;

            return Expanded(
              child: Text(
                stepLabels.length > index ? stepLabels[index] : 'Step ${index + 1}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isActive
                      ? activeCol
                      : isCompleted
                      ? completedCol
                      : AppColors.textSecondary,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStepCircle(
      int stepNumber,
      bool isActive,
      bool isCompleted,
      Color activeColor,
      Color inactiveColor,
      Color completedColor,
      ) {
    Color backgroundColor;
    Color textColor;
    Widget content;

    if (isCompleted) {
      backgroundColor = completedColor;
      textColor = Colors.white;
      content = const Icon(
        Icons.check,
        color: Colors.white,
        size: 16,
      );
    } else if (isActive) {
      backgroundColor = activeColor;
      textColor = Colors.white;
      content = Text(
        stepNumber.toString(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    } else {
      backgroundColor = inactiveColor;
      textColor = AppColors.textSecondary;
      content = Text(
        stepNumber.toString(),
        style: TextStyle(
          color: textColor,
          fontSize: 14,
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? activeColor : inactiveColor,
          width: 2,
        ),
      ),
      child: Center(child: content),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Color? backgroundColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: backgroundColor ?? Colors.black.withOpacity(0.5),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor,
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SpinKitFadingCircle(
                      color: AppColors.primaryColor,
                      size: 50.0,
                    ),
                    if (message != null) ...[
                      const SizedBox(height: AppDimensions.paddingMedium),
                      Text(
                        message!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AnimatedProgressBar extends StatefulWidget {
  final double value;
  final Duration animationDuration;
  final Color? color;
  final Color? backgroundColor;
  final double height;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.animationDuration = const Duration(milliseconds: 500),
    this.color,
    this.backgroundColor,
    this.height = 6.0,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? AppColors.dividerColor,
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _animation.value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: widget.color ?? AppColors.primaryColor,
                borderRadius: BorderRadius.circular(widget.height / 2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class ProgressCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double? progress;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const ProgressCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.progress,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppColors.primaryColor;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: cardColor,
                    size: AppDimensions.iconSizeLarge,
                  ),
                  const SizedBox(width: AppDimensions.paddingMedium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (progress != null)
                    Text(
                      '${(progress! * 100).toInt()}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cardColor,
                      ),
                    ),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: AppDimensions.paddingMedium),
                AnimatedProgressBar(
                  value: progress!,
                  color: cardColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}