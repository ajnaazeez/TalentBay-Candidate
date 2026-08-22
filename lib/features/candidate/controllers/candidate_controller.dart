import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/models/candidate_model.dart';
import '../repositories/candidate_repository.dart';

final candidateControllerProvider =
    StreamNotifierProvider.autoDispose<CandidateController, CandidateModel?>(
      () {
        return CandidateController();
      },
    );

class CandidateController extends StreamNotifier<CandidateModel?> {
  late CandidateRepository _repository;

  @override
  Stream<CandidateModel?> build() {
    _repository = ref.watch(candidateRepositoryProvider);
    final authState = ref.watch(authStateChangesProvider);
    final user = authState.value;

    if (user != null) {
      return _repository.getCandidateStream(user.uid).map((candidate) {
        if (candidate != null &&
            candidate.isPremium &&
            candidate.subscriptionExpiryDate != null) {
          if (candidate.subscriptionExpiryDate!.isBefore(DateTime.now())) {
            // Asynchronously update Firestore so future reads are correct
            Future.microtask(() {
              _repository.updateCandidate(
                candidate.copyWith(
                  isPremium: false,
                  subscriptionStatus: 'expired',
                ),
              );
            });
            // Immediately yield the un-premium state
            return candidate.copyWith(
              isPremium: false,
              subscriptionStatus: 'expired',
            );
          }
        }
        return candidate;
      });
    }
    return Stream.value(null);
  }

  Future<void> updateProfile(CandidateModel candidate) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateCandidate(candidate);
      return candidate;
    });
  }
}
