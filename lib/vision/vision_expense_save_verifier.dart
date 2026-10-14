/// Pure, read-only verification of an OCR/manual expense save result.
///
/// This component NEVER reads Firestore, never stores amounts, and never
/// retries a write. The caller must provide trustworthy *server-confirmed*
/// evidence for the exact document ID and team/session being inspected.
///
/// A local cache snapshot, an offline result, and an in-flight write are
/// never sufficient to report a missing document or amount mismatch.
enum VisionExpenseSaveStatus {
  invalidExpectedAmount,
  awaitingServerEvidence,
  inconsistentServerEvidence,
  verified,
  documentMissing,
  amountMismatch,
}

class VisionExpenseSaveCheck {
  const VisionExpenseSaveCheck(this.status);

  final VisionExpenseSaveStatus status;

  bool get isVerified => status == VisionExpenseSaveStatus.verified;

  /// Only unequivocal mismatches backed by authoritative server evidence
  /// produce a candidate telemetry identifier. Nothing logs automatically.
  String? get diagnosticCode => switch (status) {
        VisionExpenseSaveStatus.documentMissing => 'saved_document_missing',
        VisionExpenseSaveStatus.amountMismatch => 'saved_amount_mismatch',
        _ => null,
      };
}

class VisionExpenseSaveVerifier {
  VisionExpenseSaveVerifier._();

  /// Compare exact integer bani (minor units), never floating point amounts.
  ///
  /// [serverConfirmed] means the caller has verified a fresh authoritative
  /// server read for the exact intended document (not a cached snapshot or
  /// one with pending writes). Callers must also enforce UID/team ownership.
  /// If that evidence is unavailable, the result is ALWAYS pending, even
  /// when a local cache happens to contain an amount.
  ///
  /// [documentExists] is meaningful only if [serverConfirmed] is true.
  static VisionExpenseSaveCheck evaluate({
    required int expectedBani,
    required bool serverConfirmed,
    required bool documentExists,
    required int? savedBani,
  }) {
    if (expectedBani <= 0) {
      return const VisionExpenseSaveCheck(
        VisionExpenseSaveStatus.invalidExpectedAmount,
      );
    }
    if (!serverConfirmed) {
      return const VisionExpenseSaveCheck(
        VisionExpenseSaveStatus.awaitingServerEvidence,
      );
    }
    // Contradictory/incomplete payloads are not evidence of a mismatch.
    // Do not emit a false error code when data was only partially parsed.
    if ((!documentExists && savedBani != null) ||
        (documentExists && savedBani == null)) {
      return const VisionExpenseSaveCheck(
        VisionExpenseSaveStatus.inconsistentServerEvidence,
      );
    }
    if (!documentExists) {
      return const VisionExpenseSaveCheck(
        VisionExpenseSaveStatus.documentMissing,
      );
    }
    if (savedBani == expectedBani) {
      return const VisionExpenseSaveCheck(
        VisionExpenseSaveStatus.verified,
      );
    }
    return const VisionExpenseSaveCheck(
      VisionExpenseSaveStatus.amountMismatch,
    );
  }
}
