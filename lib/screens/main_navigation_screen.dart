import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/regular_task_bloc.dart';
import '../bloc/regular_task_event.dart';
import '../main.dart';
import 'home_screen.dart';
import 'regular_tasks_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  static const _screens = <Widget>[
    HomeScreen(),
    RegularTasksScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // Reload regular tasks when switching to the Daily Tasks tab
          if (index == 1) {
            context.read<RegularTaskBloc>().add(LoadRegularTasks());
          }
          setState(() => _currentIndex = index);
        },
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: '75 Hard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt),
            label: 'Daily Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
