import 'package:oradosales/constants/orado_icon_icons.dart';
import 'package:oradosales/presentation/auth/provider/user_provider.dart';
import 'package:oradosales/presentation/auth/view/login.dart';
import 'package:oradosales/presentation/home/home/provider/available_provider.dart';
import 'package:oradosales/presentation/home/home/provider/drawer_controller.dart';
import 'package:oradosales/presentation/mileston/controller/milestone_controller.dart';
import 'package:oradosales/presentation/socket_io/socket_controller.dart';
import 'package:oradosales/widgets/custom_button.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:svg_flutter/svg.dart';

import '../constants/utilities.dart';
import '../presentation/incentive/controller/incentive_controller.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer4<
      DrawerProvider,
      AgentAvailableController,
      AuthController,
      SocketController
    >(
      builder: (
        context,
        drawerProvider,
        agentController,
        authController,
        socketController,
        _,
      ) {
        final selectedIndex = drawerProvider.selectedIndex;
        // final agent = authController.currentAgent;
        return Drawer(
          width: MediaQuery.sizeOf(context).width / 1.2,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
            child: Column(
              children: [


                const SizedBox(height: 16),

                buildDrawerButton(
                  selected: selectedIndex == 0,
                  onTap: () {
                    drawerProvider.updateIndex(0);
                    Scaffold.of(context).closeDrawer();
                  },
                  icon: Icon(
                    Icons.home_outlined,
                    color:
                        selectedIndex == 0 ? AppColors.baseColor : Colors.grey,
                  ),
                  label: 'Home',
                ),
                buildDrawerButton(
                  selected: selectedIndex == 1,
                  onTap: () {
                    drawerProvider.updateIndex(1);
                    Scaffold.of(context).closeDrawer();
                  },
                  icon: Icon(
                    Icons.shopping_bag_outlined,
                    color:
                        selectedIndex == 1 ? AppColors.baseColor : Colors.grey,
                  ),
                  label: 'Orders',
                ),
                buildDrawerButton(
                  selected: selectedIndex == 2,
                  onTap: () {
                    drawerProvider.updateIndex(2);
                    Scaffold.of(context).closeDrawer();
                  },
                  icon: Icon(
                    Icons.warning_amber_rounded,
                    color:
                        selectedIndex == 2 ? AppColors.baseColor : Colors.grey,
                  ),
                  label: 'Letters',
                ),
                buildDrawerButton(
                  selected: selectedIndex == 3,
                  onTap: () {
                    drawerProvider.updateIndex(3);
                    Scaffold.of(context).closeDrawer();
                  },
                  icon: Icon(
                    Icons.edit_document,
                    color:
                        selectedIndex == 3 ? AppColors.baseColor : Colors.grey,
                  ),
                  label: 'Leave Application',
                ),
                buildDrawerButton(
                  selected: selectedIndex == 4,
                  onTap: () {
                    drawerProvider.updateIndex(4);
                    Scaffold.of(context).closeDrawer();
                  },
                  icon: Icon(
                    Icons.person_3_outlined,
                    color:
                        selectedIndex == 4 ? AppColors.baseColor : Colors.grey,
                  ),
                  label: 'Profile',
                ),

                buildDrawerButton(
                  selected: selectedIndex == 5,
                  onTap: () {
                    drawerProvider.updateIndex(5);
                    Scaffold.of(context).closeDrawer();
                  },
                  icon: Icon(
                    Icons.money,
                    color:
                        selectedIndex == 5 ? AppColors.baseColor : Colors.grey,
                  ),
                  label: 'Earnings',
                ),

                buildDrawerButton(
                  selected: selectedIndex == 6,
                  onTap: () {
                    Provider.of<IncentiveController>(context,listen: false).loadIncentive("daily");
                    drawerProvider.updateIndex(6);
                    Scaffold.of(context).closeDrawer();
                  },
                  icon: Icon(
                    Icons.emoji_events_outlined,
                    color:
                        selectedIndex == 6 ? AppColors.baseColor : Colors.grey,
                  ),
                  label: 'Incentive',
                ),
                buildDrawerButton(
                  selected: selectedIndex == 7,
                  onTap: () {
                    Provider.of<MilestoneController>(context,listen: false).loadMileStone();

                    drawerProvider.updateIndex(7);
                    Scaffold.of(context).closeDrawer();
                  },
                  icon: Icon(
                    Icons.rocket_launch_outlined,
                    color:
                        selectedIndex == 7 ? AppColors.baseColor : Colors.grey,
                  ),
                  label: 'MileStone',
                ),
                buildDrawerButton(
                  onTap: () {

                    Scaffold.of(context).closeDrawer();
                  },
                  icon: SvgPicture.asset(
                    height: 25,
                    color: Colors.grey.shade500,
                    'asstes/oradoLogo.png',
                  ),
                  label: 'Orado',
                ),
                const Spacer(),
                buildDrawerButton(
                  onTap: () => showLogoutDialog(context),
                  icon: const Icon(OradoIcon.logout, color: Colors.grey),
                  label: 'Logout',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildDrawerButton({
    bool selected = false,
    required Widget icon,
    void Function()? onTap,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 23),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: icon,
        selectedColor: AppColors.baseColor,
        selected: selected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.baseColor : Colors.transparent,
          ),
        ),
        selectedTileColor: AppColors.yellow,
        titleAlignment: ListTileTitleAlignment.center,
        title: Text(
          label,
          style: AppStyles.getSemiBoldTextStyle(
            color: selected ? AppColors.baseColor : Colors.grey.shade500,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  void showLogoutDialog(BuildContext context) => showDialog(
    context: context,
    builder:
        (c) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Oh no! you’re leaving... Are you sure?',
                  textAlign: TextAlign.center,
                  style: AppStyles.getSemiBoldTextStyle(fontSize: 20),
                ),
                const SizedBox(height: 20),
                CustomButton().showColouredButton(
                  label: 'Naah, just kidding',
                  onPressed: () {
                    Navigator.of(context).pop(); // Dismiss dialog
                  },
                ),
                const SizedBox(height: 10),
                CustomButton().showOutlinedButton(
                  label: 'Yes, log me out',
                  onPressed: () async {
                    // Logout logic
                    final authController = Provider.of<AuthController>(
                      context,
                      listen: false,
                    );
                    await authController.logout();

                    final agentController =
                        Provider.of<AgentAvailableController>(
                          context,
                          listen: false,
                        );
                    agentController.isAvailable = false;

                    Navigator.of(context).pop(); // Dismiss dialog

                    // Navigate to LoginScreen and remove all previous routes
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
  );
}
