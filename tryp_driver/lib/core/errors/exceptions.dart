/// Base exception for TRYP app
abstract class TRYPException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;

  TRYPException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() => 'TRYPException: $message (code: $code)';
}

/// Authentication related exceptions
class AuthException extends TRYPException {
  AuthException({
    required String message,
    String? code,
    dynamic originalException,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
  );
}

/// Network related exceptions
class NetworkException extends TRYPException {
  NetworkException({
    required String message,
    String? code,
    dynamic originalException,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
  );
}

/// Validation exceptions
class ValidationException extends TRYPException {
  ValidationException({
    required String message,
    String? code,
    dynamic originalException,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
  );
}

/// Server/API exceptions
class ServerException extends TRYPException {
  ServerException({
    required String message,
    String? code,
    dynamic originalException,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
  );
}

/// Location exceptions
class LocationException extends TRYPException {
  LocationException({
    required String message,
    String? code,
    dynamic originalException,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
  );
}

/// Cache exceptions
class CacheException extends TRYPException {
  CacheException({
    required String message,
    String? code,
    dynamic originalException,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
  );
}

/// Generic exception
class GenericException extends TRYPException {
  GenericException({
    required String message,
    String? code,
    dynamic originalException,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
  );
}
