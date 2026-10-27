'use strict';

/**
 * Wraps an async route handler and forwards failures to Express error handling.
 * (Express 5 already does this, but keeping it explicit makes the flow clear.)
 *
 * @param {Function} handler - Async Express route handler.
 * @returns {import('express').RequestHandler} Wrapped handler.
 */
const asyncRoute = (handler) => (req, res, next) =>
  Promise.resolve(handler(req, res, next)).catch(next);

module.exports = { asyncRoute };
