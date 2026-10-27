'use strict';

/** Responds with a safe 404 for unknown routes. */
function notFoundHandler(_req, res) {
  res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Route not found.' } });
}

/**
 * Sends a consistent safe error response.
 *
 * @param {Error} error - Error forwarded by an earlier middleware.
 * @param {import('express').Request} req - Express request.
 * @param {import('express').Response} res - Express response.
 * @param {import('express').NextFunction} _next - Express continuation.
 * @returns {void}
 */
function errorHandler(error, req, res, _next) {
  req.log?.error({ err: error }, 'Request failed');

  if (res.headersSent) return;

  // Malformed JSON bodies from express.json() carry status 400 and type 'entity.parse.failed'.
  const status = Number.isInteger(error.status) ? error.status : 500;
  const safeStatus = status >= 400 && status < 500 ? status : 500;
  const isBodyParserError = typeof error.type === 'string';

  res.status(safeStatus).json({
    error: {
      code: safeStatus === 500 ? 'INTERNAL_ERROR' : (error.code || 'REQUEST_ERROR'),
      message: safeStatus === 500
        ? 'An unexpected error occurred.'
        : (isBodyParserError ? 'The request body is invalid.' : error.message),
    },
  });
}

module.exports = { errorHandler, notFoundHandler };
