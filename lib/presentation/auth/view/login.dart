import 'package:oradosales/presentation/auth/provider/user_provider.dart';
import 'package:oradosales/presentation/auth/view/reg.dart';
import 'package:oradosales/widgets/custom_button.dart';
import 'package:oradosales/widgets/custom_container.dart';
import 'package:oradosales/widgets/text_formfield.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../constants/colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  static String route = 'login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    nameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);

    return Scaffold(
      body: Form(
        key: formKey,
        child: Stack(
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height / 1.7,
              width: MediaQuery.sizeOf(context).width,
              child: Image.asset('asstes/coverPic.png', fit: BoxFit.cover),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipPath(
                clipper: CustomContainer(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 50,
                    horizontal: 24,
                  ),
                  height: MediaQuery.sizeOf(context).height / 2.19,
                  color: Colors.white,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BuildTextFormField(
                          inputAction: TextInputAction.next,
                          keyboardType: TextInputType.name,
                          validator: (String? text) {
                            if (text!.isEmpty) {
                              return 'Enter a valid name';
                            }
                            return null;
                          },
                          controller: nameController,
                          fillColor: AppColors.greycolor,
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          hint: 'User Name / Mobile Number',
                        ),
                        const SizedBox(height: 20),
                        BuildTextFormField(
                          inputAction: TextInputAction.next,
                          keyboardType: TextInputType.name,
                          obscureText: true,
                          validator: (String? text) {
                            if (text!.isEmpty) {
                              return 'Enter a valid Password';
                            }
                            return null;
                          },
                          controller: passwordController,
                          fillColor: AppColors.greycolor,
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          hint: 'Password',
                        ),
                        const SizedBox(height: 20),
                        authController.isLoading
                            ? const CircularProgressIndicator()
                            : CustomButton().showColouredButton(
                              label: 'Login',
                              backGroundColor: AppColors.baseColor,
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) {
                                  return;
                                }
                                await authController.login(
                                  context,
                                  nameController.text,
                                  passwordController.text,
                                );
                              },
                            ),
                        const SizedBox(height: 16),
                        if (authController.message.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              authController.message,
                              style: TextStyle(
                                color:
                                    authController.message
                                            .toLowerCase()
                                            .contains('success')
                                        ? Colors.green
                                        : Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegistrationScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "Don't have an account? Register",
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
