'use strict';

const request = require('supertest');
const { app } = require('../src/app');
const { prisma } = require('../src/repositories/prisma');

afterAll(() => prisma.$disconnect());

describe('health endpoint', () => {
  test('returns a healthy status', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('ok');
  });
});
