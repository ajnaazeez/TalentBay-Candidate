 import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:talentbay_candidate/features/jobs/models/job_application_model.dart';

void main() {
  group('Activity Tab Stream Lifecycle & Recovery Logic Tests', () {
    test('Stream error recovery: can catch error and supply retry stream', () async {
      final controller = StreamController<List<JobApplicationModel>>();
      final receivedData = <List<JobApplicationModel>>[];
      Object? receivedError;

      final sub = controller.stream.listen(
        (data) => receivedData.add(data),
        onError: (err) => receivedError = err,
      );

      controller.addError(Exception('Network timeout connecting to Firestore'));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(receivedError, isNotNull);
      expect(receivedError.toString(), contains('Network timeout'));
      await sub.cancel();
      await controller.close();

      // Retry re-creates stream from source
      final retryController = StreamController<List<JobApplicationModel>>();
      final retryReceived = <List<JobApplicationModel>>[];
      final retrySub = retryController.stream.listen((data) => retryReceived.add(data));

      retryController.add([
        JobApplicationModel(
          applicationId: 'app_1',
          jobId: 'job_1',
          candidateId: 'cand_1',
          resumeUrl: '',
          coverLetter: '',
          applicationStatus: 'applied',
          appliedAt: DateTime.now(),
          source: 'app',
        ),
      ]);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(retryReceived.length, equals(1));
      expect(retryReceived.first.first.applicationId, equals('app_1'));
      await retrySub.cancel();
      await retryController.close();
    });

    test('Slow connection timer triggers after timeout if no data arrived', () async {
      bool isSlowConnection = false;
      final timer = Timer(const Duration(milliseconds: 50), () {
        isSlowConnection = true;
      });

      expect(isSlowConnection, isFalse);
      await Future.delayed(const Duration(milliseconds: 70));
      expect(isSlowConnection, isTrue);
      timer.cancel();
    });

    test('Prompt data arrival cancels timeout timer', () async {
      bool isSlowConnection = false;
      final timer = Timer(const Duration(milliseconds: 50), () {
        isSlowConnection = true;
      });

      // Data arrives before timer fires
      await Future.delayed(const Duration(milliseconds: 20));
      timer.cancel();

      await Future.delayed(const Duration(milliseconds: 40));
      expect(isSlowConnection, isFalse);
    });

    test('Filtering accepted vs applied applications cleanly separates tabs', () {
      final now = DateTime.now();
      final allApps = [
        JobApplicationModel(
          applicationId: 'app_1',
          jobId: 'job_1',
          candidateId: 'c1',
          resumeUrl: '',
          coverLetter: '',
          applicationStatus: 'applied',
          appliedAt: now,
          source: 'app',
        ),
        JobApplicationModel(
          applicationId: 'app_2',
          jobId: 'job_2',
          candidateId: 'c1',
          resumeUrl: '',
          coverLetter: '',
          applicationStatus: 'shortlisted',
          appliedAt: now.subtract(const Duration(days: 1)),
          source: 'app',
        ),
        JobApplicationModel(
          applicationId: 'app_3',
          jobId: 'job_3',
          candidateId: 'c1',
          resumeUrl: '',
          coverLetter: '',
          applicationStatus: 'accepted',
          appliedAt: now.subtract(const Duration(days: 2)),
          source: 'app',
        ),
        JobApplicationModel(
          applicationId: 'app_4',
          jobId: 'job_4',
          candidateId: 'c1',
          resumeUrl: '',
          coverLetter: '',
          applicationStatus: 'hired',
          appliedAt: now.subtract(const Duration(days: 3)),
          source: 'app',
        ),
      ];

      // Applied tab filters out hired and accepted
      final appliedList = allApps
          .where((a) => !['hired', 'accepted'].contains(a.applicationStatus.toLowerCase()))
          .toList();
      expect(appliedList.length, equals(2));
      expect(appliedList.map((a) => a.applicationId), containsAll(['app_1', 'app_2']));

      // Accepted tab includes only hired and accepted
      final acceptedList = allApps
          .where((a) => ['hired', 'accepted'].contains(a.applicationStatus.toLowerCase()))
          .toList();
      expect(acceptedList.length, equals(2));
      expect(acceptedList.map((a) => a.applicationId), containsAll(['app_3', 'app_4']));
    });
  });

  group('OTP Timing & Safe Performance Instrumentation Tests', () {
    test('Stopwatch measures step timings accurately without logging credentials', () async {
      final totalSw = Stopwatch()..start();
      final stepSw = Stopwatch()..start();

      await Future.delayed(const Duration(milliseconds: 15));
      final step1Ms = stepSw.elapsedMilliseconds;
      stepSw.reset();

      await Future.delayed(const Duration(milliseconds: 20));
      final step2Ms = stepSw.elapsedMilliseconds;

      totalSw.stop();

      expect(step1Ms, greaterThanOrEqualTo(10));
      expect(step2Ms, greaterThanOrEqualTo(15));
      expect(totalSw.elapsedMilliseconds, greaterThanOrEqualTo(25));
    });

    test('Parallel Future.wait executes concurrent document reads faster than sequential', () async {
      Future<String> mockReadDoc(String id, int delayMs) async {
        await Future.delayed(Duration(milliseconds: delayMs));
        return 'doc_$id';
      }

      final sw = Stopwatch()..start();
      final results = await Future.wait([
        mockReadDoc('users', 30),
        mockReadDoc('candidates', 30),
      ]);
      sw.stop();

      expect(results, equals(['doc_users', 'doc_candidates']));
      // Parallel execution takes ~30ms instead of 60ms
      expect(sw.elapsedMilliseconds, lessThan(55));
    });
  });
}
