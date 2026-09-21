import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/widgets/interactive/glass_icon_button.dart';
import 'package:mazzica/constants/app_color.dart';

class CustomButtons extends StatelessWidget {
  const CustomButtons({
    super.key,
    required this.iconSize,
    required this.buttonIcon,
    required this.function,
    required this.buttonSize,
  });

  final double iconSize;
  final IconData buttonIcon;
  final void Function()? function;
  final double buttonSize;

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: Icon(buttonIcon, color: AppColors.lime, size: iconSize),
      shape: GlassIconButtonShape.circle,
      size: buttonSize,
      onPressed: function,
    );
  }
}
