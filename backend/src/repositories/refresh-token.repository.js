'use strict';

const { prisma } = require('./prisma');

/** Creates a refresh-token record using the supplied Prisma client or transaction. */
function createToken(data, db = prisma) {
  return db.refreshToken.create({ data });
}

/** Finds a refresh-token record by its stored token hash. */
function findByHash(tokenHash, db = prisma) {
  return db.refreshToken.findUnique({ where: { tokenHash } });
}

/** Revokes one token record if it has not already been revoked. Returns the update count. */
function revokeToken(id, replacedById = null, db = prisma) {
  return db.refreshToken.updateMany({
    where: { id, revokedAt: null },
    data: { revokedAt: new Date(), replacedById },
  });
}

/** Revokes every token in a token family. */
function revokeFamily(familyId, db = prisma) {
  return db.refreshToken.updateMany({
    where: { familyId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

/** Revokes every active refresh token belonging to a user. */
function revokeAllForUser(userId, db = prisma) {
  return db.refreshToken.updateMany({
    where: { userId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

module.exports = { createToken, findByHash, revokeToken, revokeFamily, revokeAllForUser };
