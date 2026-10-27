'use strict';

const express = require('express');
const rateLimit = require('express-rate-limit');
const { env } = require('../config');
const { requireAuth } = require('../middleware/auth.middleware');
const { validate } = require('../middleware/validate.middleware');
const { registerSchema, loginSchema, refreshSchema } = require('../schemas/auth.schema');
const controller = require('../controllers/auth.controller');
const { asyncRoute } = require('../utils/async-route');

const router = express.Router();

/** Builds an in-memory rate limiter (15-minute window). Disabled only in automated tests. */
const limiter = (max) => rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: max,
  skip: () => env.NODE_ENV === 'test',
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: { error: { code: 'RATE_LIMITED', message: 'Too many requests. Try again later.' } },
});

router.post('/register', limiter(10), validate(registerSchema, 'body'), asyncRoute(controller.register));
router.post('/login', limiter(10), validate(loginSchema, 'body'), asyncRoute(controller.login));
router.post('/refresh', limiter(30), validate(refreshSchema, 'body'), asyncRoute(controller.refresh));
router.post('/logout', limiter(30), validate(refreshSchema, 'body'), asyncRoute(controller.logout));
router.post('/logout-all', requireAuth, asyncRoute(controller.logoutAll));

module.exports = router;
