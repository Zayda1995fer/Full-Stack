'use strict';

const { PrismaClient } = require('@prisma/client');

/** Shared Prisma client for the whole process (one connection pool). */
const prisma = new PrismaClient();

module.exports = { prisma };
