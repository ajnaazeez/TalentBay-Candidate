import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/controllers/auth_controller.dart';
import '../../../candidate/controllers/candidate_controller.dart';

class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidateState = ref.watch(candidateControllerProvider);

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              candidateState.value?.firstName != null
                  ? '${candidateState.value!.firstName} ${candidateState.value!.lastName}'
                  : 'User',
            ),
            accountEmail: Text(candidateState.value?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: candidateState.value?.photoUrl != null
                  ? NetworkImage(candidateState.value!.photoUrl!)
                  : null,
              child: candidateState.value?.photoUrl == null
                  ? Text(
                      (candidateState.value?.firstName?.isNotEmpty == true)
                          ? candidateState.value!.firstName![0].toUpperCase()
                          : 'U',
                      style: const TextStyle(fontSize: 24.0),
                    )
                  : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
              context.pop(); // Close drawer
              context.push('/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              context.pop(); // Close drawer
              context.push('/settings');
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              context.pop();
              ref.read(authControllerProvider.notifier).signOut();
              context.go('/login');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
