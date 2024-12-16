import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_chatter_mobile/Core/Services/Auth/auth_service.dart';
import 'package:web_chatter_mobile/Core/Utils/UI/custom_snackbar.dart';
import 'package:web_chatter_mobile/Screens/Auth/login_screen.dart';
import 'package:web_chatter_mobile/Screens/Avatar/avatar_selection.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  SignUpScreenState createState() => SignUpScreenState();
}

class SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _nameFieldAnimation;
  bool _isPasswordVisible = false;
  final _scrollController = ScrollController();
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _nameFieldAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
    _animationController.forward();
    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus) {
        _scrollToFocusedField(_nameFocusNode);
      }
    });

    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus) {
        _scrollToFocusedField(_emailFocusNode);
      }
    });

    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        _scrollToFocusedField(_passwordFocusNode);
      }
    });
  }

  void _scrollToFocusedField(FocusNode focusNode) {
    if (focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 96),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F1F),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Image.asset('assets/logo.png'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontFamily: "Consola",
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign up to start chatting with your friends',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: "Consola",
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _nameFieldAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.2),
                        end: Offset.zero,
                      ).animate(_nameFieldAnimation),
                      child: _buildTextField(
                        controller: _nameController,
                        icon: Icons.person_outline,
                        label: 'Full Name',
                        focusNode: _nameFocusNode,
                        textInputAction: TextInputAction.next,
                        onEditingComplete: () => _emailFocusNode.requestFocus(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    icon: Icons.email_outlined,
                    label: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                    focusNode: _emailFocusNode,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () => _passwordFocusNode.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordController,
                    icon: Icons.lock_outline,
                    label: 'Password',
                    isPassword: true,
                    focusNode: _passwordFocusNode,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: _handleSignUp,
                  ),
                  const SizedBox(height: 24),
                  _buildSignUpButton(),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      _emailController.clear();
                      _passwordController.clear();
                      _nameController.clear();
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const LoginScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            const begin = Offset(1.0, 0.0);
                            const end = Offset.zero;
                            const curve = Curves.easeInOutCubic;
                            var tween = Tween(begin: begin, end: end)
                                .chain(CurveTween(curve: curve));
                            var offsetAnimation = animation.drive(tween);
                            return SlideTransition(
                              position: offsetAnimation,
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 400),
                        ),
                      );
                    },
                    child: RichText(
                      text: const TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(
                          fontFamily: 'Consola',
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    bool isPassword = false,
    TextInputType? keyboardType,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    void Function()? onEditingComplete,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        cursorColor: Colors.white,
        cursorHeight: 24,
        controller: controller,
        obscureText: isPassword ? !_isPasswordVisible : false,
        focusNode: focusNode,
        textInputAction: textInputAction,
        onEditingComplete: onEditingComplete,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 16,
          fontFamily: "Consola",
          color: Colors.white,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(20),
          border: InputBorder.none,
          hintText: label,
          hintStyle: const TextStyle(
            color: Colors.white70,
            fontFamily: "Consola",
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white70,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? () {} : _handleSignUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFF121212),
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  'C O N T I N U E',
                  style: TextStyle(
                    fontFamily: 'Consola',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF121212),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty) {
      CustomSnackbar.show(
        context,
        'Please fill in all fields',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      await authService.signUpWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
        _nameController.text,
      );

      if (!mounted) return;

      CustomSnackbar.show(context, 'Account created successfully!');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AvatarSelectionScreen(
            userEmail: _emailController.text,
            onAvatarSelected: (seed) {},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.show(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
