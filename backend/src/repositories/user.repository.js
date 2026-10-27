'use strict';

const { prisma } = require('./prisma');

/** Creates a user with an already-hashed password. */
function createUser(data) {
  return prisma.user.create({ data });
}

/** Finds a user by normalized email. */
function findByEmail(email) {
  return prisma.user.findUnique({ where: { email } });
}

module.exports = { createUser, findByEmail };
