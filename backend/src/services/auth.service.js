'use strict';

const bcrypt = require('bcrypt');
const crypto = require('node:crypto');
const { prisma } = require('../repositories/prisma');
const userRepository = require('../repositories/user.repository');
const tokenRepository = require('../repositories/refresh-token.repository');
const { createAccessToken, createRefreshToken, hashToken } = require('../utils/tokens');

const BCRYPT_COST = 12;
const REFRESH_TTL_MS = 7 * 24 * 60 * 60 * 1000;
// Valid bcrypt hash of a random value: lets login spend the same time
// whether or not the email exists (reduces account enumeration by timing).
const DUMMY_PASSWORD_HASH = '$2b$12$fh62DAMR/reN1Bb.Z159gukaNG5rP9gcLqnEahcKcvfpIq4huS4sa';

/** Creates a safe authentication error with an HTTP status and code. */
function authError(message = 'Authentication required.') {
  const error = new Error(message);
  error.status = 401;
  error.code = 'UNAUTHENTICATED';
  return error;
}

/** Registers a user with a one-way password hash. */
async function register({ email, password }) {
  const passwordHash = await bcrypt.hash(password, BCRYPT_COST);
  try {
    const user = await userRepository.createUser({ email, passwordHash });
    return issueTokens(user.id, crypto.randomUUID());
  } catch (error) {
    if (error.code === 'P2002') {
      const conflict = new Error('An account with this email already exists.');
      conflict.status = 409;
      conflict.code = 'CONFLICT';
      throw conflict;
    }
    throw error;
  }
}

/** Authenticates credentials with a generic failure response. */
async function login({ email, password }) {
  const user = await userRepository.findByEmail(email);
  const passwordHash = user?.passwordHash || DUMMY_PASSWORD_HASH;
  const matches = await bcrypt.compare(password, passwordHash);
  if (!user || !matches) throw authError('Invalid email or password.');
  return issueTokens(user.id, crypto.randomUUID());
}

/** Issues an access/refresh pair and persists only the refresh-token hash. */
async function issueTokens(userId, familyId, db = prisma) {
  const refreshToken = createRefreshToken();
  const record = await tokenRepository.createToken({
    userId,
    tokenHash: hashToken(refreshToken),
    familyId,
    expiresAt: new Date(Date.now() + REFRESH_TTL_MS),
  }, db);
  return {
    tokens: { accessToken: createAccessToken(userId), refreshToken, expiresIn: 600 },
    recordId: record.id,
  };
}

/** Public helper: returns only the token pair sent to clients. */
async function issueTokenPair(userId, familyId, db = prisma) {
  return (await issueTokens(userId, familyId, db)).tokens;
}

/** Rotates a refresh token transactionally and detects reuse of revoked tokens. */
async function refresh(refreshToken) {
  const outcome = await prisma.$transaction(async (tx) => {
    const record = await tokenRepository.findByHash(hashToken(refreshToken), tx);
    if (!record || record.expiresAt <= new Date()) return { error: true };
    if (record.revokedAt) {
      // Reuse of an already-rotated token: revoke the whole family.
      await tokenRepository.revokeFamily(record.familyId, tx);
      return { error: true, reuse: true };
    }
    const revoked = await tokenRepository.revokeToken(record.id, null, tx);
    if (revoked.count === 0) {
      // A concurrent request rotated it first: treat as reuse.
      await tokenRepository.revokeFamily(record.familyId, tx);
      return { error: true, reuse: true };
    }
    const issued = await issueTokens(record.userId, record.familyId, tx);
    await tx.refreshToken.update({
      where: { id: record.id },
      data: { replacedById: issued.recordId },
    });
    return { tokens: issued.tokens };
  });

  // Family revocation happens inside the transaction, which commits before we throw.
  if (outcome.error) throw authError('Refresh token is invalid or expired.');
  return outcome.tokens;
}

/** Revokes the entire refresh-token family associated with this token. */
async function logout(refreshToken) {
  const record = await tokenRepository.findByHash(hashToken(refreshToken));
  if (record) await tokenRepository.revokeFamily(record.familyId);
}

/** Revokes all active refresh tokens for the authenticated user. */
async function logoutAll(userId) {
  await tokenRepository.revokeAllForUser(userId);
}

module.exports = {
  register: async (input) => (await register(input)).tokens,
  login: async (input) => (await login(input)).tokens,
  issueTokenPair,
  refresh,
  logout,
  logoutAll,
};
