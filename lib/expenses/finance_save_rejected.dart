/// An explicit guarantee from a save adapter that it rejected the operation
/// before attempting persistence. Never wrap an arbitrary SDK/timeout error in
/// this type: a generic failure may follow a committed write.
class FinanceSaveRejected extends StateError {
  FinanceSaveRejected(String message) : super(message);
}
