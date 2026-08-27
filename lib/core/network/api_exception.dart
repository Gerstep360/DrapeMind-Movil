/// Base class for API and Network exceptions in DrapeMind Mobile.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() =>
      statusCode != null ? 'ApiException ($statusCode): $message' : 'ApiException: $message';
}

/// Thrown when 401 Unauthorized occurs (e.g. token expired or invalid credentials).
class AuthException extends ApiException {
  AuthException(super.message, {super.statusCode = 401, super.details});
}

/// Thrown when 403 Forbidden occurs.
class ForbiddenException extends ApiException {
  ForbiddenException(super.message, {super.statusCode = 403, super.details});
}

/// Thrown when 404 Not Found occurs.
class NotFoundException extends ApiException {
  NotFoundException(super.message, {super.statusCode = 404, super.details});
}

/// Thrown when 422 Unprocessable Entity or validation error occurs.
class ValidationException extends ApiException {
  ValidationException(super.message, {super.statusCode = 422, super.details});
}

/// Thrown when network connection is unreachable or timed out.
class NetworkException extends ApiException {
  NetworkException(super.message, {super.details});
}

/// Thrown on 500+ Internal Server Errors.
class ServerException extends ApiException {
  ServerException(super.message, {super.statusCode = 500, super.details});
}
